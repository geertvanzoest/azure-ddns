# Architecture Patterns

**Domain:** Bash DDNS-client voor Azure DNS
**Researched:** 2026-03-30
**Confidence:** HIGH (gebaseerd op officieel geverifieerde Azure REST API documentatie)

## Recommended Architecture

Het script volgt een lineair pipeline-model: valideer configuratie, verkrijg token, detecteer IP, vergelijk met huidig DNS-record, update indien nodig. Geen parallelle uitvoering, geen achtergrondprocessen -- puur sequentieel en deterministisch.

```
 +------------------+
 | Environment Vars |
 +--------+---------+
          |
          v
 +------------------+
 | validate_config  |  --> exit 78 bij ontbrekende vars
 +--------+---------+
          |
          v
 +------------------+
 | get_access_token |  --> OAuth2 client credentials POST
 +--------+---------+
          |
          v
 +------------------+
 | get_public_ip    |  --> externe IP-detectie service
 +--------+---------+
          |
          v
 +------------------+
 | get_dns_record   |  --> Azure DNS REST API GET
 +--------+---------+
          |
          v
 +------------------+
 | compare IP's     |  --> gelijk? exit 0 (no-op)
 +--------+---------+
          |  (ongelijk)
          v
 +------------------+
 | update_dns       |  --> Azure DNS REST API PUT
 +--------+---------+
          |
          v
 +------------------+
 | exit 0 (succes)  |
 +------------------+
```

### Component Boundaries

| Component | Verantwoordelijkheid | Input | Output |
|-----------|---------------------|-------|--------|
| `validate_config` | Controleert of alle vereiste env vars gezet zijn | Environment | exit 78 of doorgaan |
| `get_access_token` | Haalt OAuth2 Bearer token op bij Entra ID | AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET | ACCESS_TOKEN string |
| `get_public_ip` | Detecteert huidig publiek IPv4-adres | (geen) | CURRENT_IP string |
| `get_dns_record` | Leest huidig A-record uit Azure DNS | ACCESS_TOKEN, DNS config vars | DNS_IP string |
| `update_dns` | Schrijft nieuw IP naar Azure DNS A-record | ACCESS_TOKEN, CURRENT_IP, DNS config vars | HTTP status code |
| `log` | Gestandaardiseerde log output | level + message | stderr (errors) of stdout (info) |
| `main` | Orchestratie van alle stappen | Environment | exit code |

### Data Flow

```
Environment Variables
    |
    +-- AZURE_TENANT_ID ----+
    +-- AZURE_CLIENT_ID ----+--> get_access_token --> ACCESS_TOKEN
    +-- AZURE_CLIENT_SECRET +                            |
    |                                                    |
    +-- AZURE_SUBSCRIPTION_ID --+                        |
    +-- AZURE_RESOURCE_GROUP ---+--> get_dns_record ---> DNS_IP
    +-- DNS_ZONE_NAME ---------+        |                  |
    +-- DNS_RECORD_NAME -------+        |                  |
    +-- DNS_TTL (optioneel) ---+        |         compare(CURRENT_IP, DNS_IP)
    |                                   |                  |
    +-- IP_SERVICE_URL (optioneel) --> get_public_ip --> CURRENT_IP
                                        |
                                        +--> update_dns (als IP gewijzigd)
                                                |
                                            exit code
```

## Patterns to Follow

### Pattern 1: Fail-Fast Environment Validation

**Wat:** Valideer alle vereiste environment variables aan het begin, voor enige API-call.
**Wanneer:** Altijd, als eerste stap in main.
**Waarom:** Voorkomt dat het script halverwege faalt (bijv. na een succesvolle token-request maar zonder DNS_ZONE_NAME). Geeft de gebruiker in een keer alle ontbrekende variabelen.

```bash
validate_config() {
    local missing=()
    local required_vars=(
        AZURE_TENANT_ID
        AZURE_CLIENT_ID
        AZURE_CLIENT_SECRET
        AZURE_SUBSCRIPTION_ID
        AZURE_RESOURCE_GROUP
        DNS_ZONE_NAME
        DNS_RECORD_NAME
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "ERROR" "Ontbrekende environment variables: ${missing[*]}"
        exit 78  # EX_CONFIG (sysexits.h)
    fi
}
```

### Pattern 2: Azure OAuth2 Client Credentials via curl

**Wat:** Verkrijg een Bearer access token via de Microsoft identity platform v2.0 token endpoint.
**Wanneer:** Elke keer dat het script draait (tokens zijn kortlevend, ~3600s, en het script draait 1x per cron-interval).
**Bron:** Microsoft Entra ID documentatie (geverifieerd via learn.microsoft.com)

```bash
get_access_token() {
    local token_url="https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token"
    local response
    local http_code

    response=$(curl --silent --show-error \
        --max-time 10 \
        --write-out "\n%{http_code}" \
        --request POST \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "client_id=${AZURE_CLIENT_ID}" \
        --data-urlencode "client_secret=${AZURE_CLIENT_SECRET}" \
        --data-urlencode "scope=https://management.azure.com/.default" \
        --data-urlencode "grant_type=client_credentials" \
        "$token_url")

    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ne 200 ]]; then
        log "ERROR" "Token request mislukt (HTTP ${http_code})"
        return 1
    fi

    echo "$body" | jq -r '.access_token'
}
```

**Kritieke details (geverifieerd):**
- Endpoint: `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token`
- Scope voor Azure Management: `https://management.azure.com/.default`
- Grant type: `client_credentials`
- Response bevat `access_token` en `expires_in` (typisch 3599 seconden)
- Gebruik `--data-urlencode` om speciale tekens in client_secret correct te coderen

### Pattern 3: Vergelijk met Huidig DNS Record (niet een cache-bestand)

**Wat:** Haal het huidige A-record op via de Azure DNS REST API en vergelijk met het gedetecteerde IP.
**Wanneer:** Elke run -- dit is betrouwbaarder dan een lokaal cache-bestand.
**Waarom tegen cache-bestand:**
- Een cache-bestand kan desyncen (handmatige DNS-wijziging, andere update-tool, bestand gewist)
- Het DNS GET-verzoek kost 1 API-call en is snel (~100-200ms)
- De authoritative bron is altijd Azure DNS zelf, niet een lokaal bestand

```bash
get_dns_record() {
    local access_token="$1"
    local dns_url="https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/dnsZones/${DNS_ZONE_NAME}/A/${DNS_RECORD_NAME}?api-version=2018-05-01"

    local response
    response=$(curl --silent --show-error \
        --max-time 10 \
        --write-out "\n%{http_code}" \
        --header "Authorization: Bearer ${access_token}" \
        "$dns_url")

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ne 200 ]]; then
        log "ERROR" "DNS record ophalen mislukt (HTTP ${http_code})"
        return 1
    fi

    echo "$body" | jq -r '.properties.ARecords[0].ipv4Address'
}
```

**Azure DNS REST API details (geverifieerd):**
- GET endpoint: `https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}/A/{record}?api-version=2018-05-01`
- Response structuur: `{ "properties": { "ARecords": [{"ipv4Address": "x.x.x.x"}] } }`
- API-versie: `2018-05-01` (stabiel, wordt breed gebruikt)

### Pattern 4: Update DNS Record via PUT

**Wat:** Gebruik PUT (create-or-update) om het A-record bij te werken.
**Waarom PUT en niet PATCH:** De Azure DNS API biedt geen PATCH -- het is altijd PUT met de volledige record set.

```bash
update_dns() {
    local access_token="$1"
    local new_ip="$2"
    local ttl="${DNS_TTL:-300}"
    local dns_url="https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/dnsZones/${DNS_ZONE_NAME}/A/${DNS_RECORD_NAME}?api-version=2018-05-01"

    local payload
    payload=$(jq -n \
        --arg ip "$new_ip" \
        --argjson ttl "$ttl" \
        '{properties: {TTL: $ttl, ARecords: [{ipv4Address: $ip}]}}')

    local response
    response=$(curl --silent --show-error \
        --max-time 10 \
        --write-out "\n%{http_code}" \
        --request PUT \
        --header "Authorization: Bearer ${access_token}" \
        --header "Content-Type: application/json" \
        --data "$payload" \
        "$dns_url")

    local http_code
    http_code=$(echo "$response" | tail -n1)

    if [[ "$http_code" -ne 200 && "$http_code" -ne 201 ]]; then
        local body
        body=$(echo "$response" | sed '$d')
        log "ERROR" "DNS update mislukt (HTTP ${http_code}): $body"
        return 1
    fi

    return 0
}
```

**Geverifieerde details:**
- PUT retourneert 200 (updated) of 201 (created) bij succes
- Payload structuur: `{"properties": {"TTL": 3600, "ARecords": [{"ipv4Address": "x.x.x.x"}]}}`
- `Content-Type: application/json` is vereist

### Pattern 5: HTTP Status + Body Extractie Pattern

**Wat:** Gebruik `--write-out "\n%{http_code}"` om zowel de response body als HTTP status code te vangen in een enkele curl-call.
**Waarom:** Bash heeft geen native HTTP-client. Dit pattern vermijdt twee curl-calls (een voor status, een voor body) en is de standaard bash/curl idioom.

```bash
# Patroon: vang body + status in een call
response=$(curl --silent --show-error --write-out "\n%{http_code}" ...)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
```

### Pattern 6: Gestandaardiseerde Logging

**Wat:** Eenvoudige log-functie met timestamp en level, geschikt voor cron/systemd/journald.
**Waarom:** Cron stuurt stdout/stderr naar mail. Systemd/journald pikt syslog-achtige prefixen op. Een simpel formaat werkt in beide scenario's.

```bash
readonly SCRIPT_NAME="ns4j"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ "$level" == "ERROR" ]]; then
        echo "${timestamp} [${SCRIPT_NAME}] ${level}: ${message}" >&2
    else
        echo "${timestamp} [${SCRIPT_NAME}] ${level}: ${message}"
    fi
}
```

### Pattern 7: IP-Detectie met Fallback

**Wat:** Gebruik een primaire IP-detectieservice met optioneel fallback naar alternatieven.
**Waarom:** Externe services kunnen tijdelijk down zijn. Een fallback verhoogt de betrouwbaarheid.

```bash
get_public_ip() {
    local ip_service="${IP_SERVICE_URL:-https://api.ipify.org}"
    local ip

    ip=$(curl --silent --show-error --max-time 5 "$ip_service")

    # Valideer dat het een geldig IPv4-adres is
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "ERROR" "Ongeldig IP-adres ontvangen: '${ip}'"
        return 1
    fi

    echo "$ip"
}
```

**Overwegingen:**
- `https://api.ipify.org` retourneert plain-text IPv4 (geen JSON parsing nodig)
- `https://ifconfig.me` is een alternatief (ook plain-text)
- Altijd het resultaat valideren met een regex -- een down service kan HTML retourneren
- `--max-time 5` voorkomt dat het script blijft hangen op een onbereikbare service

## Anti-Patterns to Avoid

### Anti-Pattern 1: Lokaal Cache-Bestand voor IP-vergelijking

**Wat:** Het huidige IP opslaan in een bestand (bijv. `/tmp/ns4j-last-ip.txt`) en daar tegen vergelijken.
**Waarom slecht:** Het cache-bestand kan desyncen met de werkelijke DNS-staat:
- Handmatige DNS-wijziging via Azure Portal
- Bestand gewist (bijv. na reboot, /tmp cleanup)
- Ander proces update hetzelfde record
- Bestandspermissie-problemen op de Pi

**In plaats daarvan:** Altijd het huidige DNS-record ophalen via de Azure REST API. Dit is de authoritative bron en kost slechts 1 extra API-call per run.

### Anti-Pattern 2: Token Caching in een Bestand

**Wat:** Het OAuth2 access token opslaan in een bestand om API-calls te besparen.
**Waarom slecht:**
- Het script draait via cron (bijv. elke 5 minuten). Een token is ~3600s geldig. De overhead van een extra token-request is verwaarloosbaar.
- Een token-bestand introduceert complexiteit: expiry-checking, file locking, permissie-management.
- Een token op disk is een veiligheidsrisico als file permissions fout staan.

**In plaats daarvan:** Vraag elk run een nieuw token aan. Simpeler, veiliger, geen caching-logica.

### Anti-Pattern 3: set -e Zonder Trap

**Wat:** `set -e` gebruiken om bij elke fout te stoppen, maar geen `trap` instellen voor cleanup of logging.
**Waarom slecht:** Het script stopt stil, zonder duidelijke foutmelding. De cron-gebruiker ziet niks.

**In plaats daarvan:** Gebruik expliciete error handling per functie (check return codes) en reserveer `set -e` alleen als vangnet met een bijbehorende `trap`:

```bash
set -euo pipefail

trap 'log "ERROR" "Script afgebroken op regel ${LINENO}"' ERR
```

### Anti-Pattern 4: Credentials in het Script

**Wat:** Hardcoded Azure credentials in het scriptbestand.
**Waarom slecht:** Veiligheidsrisico, niet draagbaar, kan per ongeluk in version control terechtkomen.
**In plaats daarvan:** Altijd via environment variables. Cron kan deze leveren via een wrapper of env-file.

### Anti-Pattern 5: Ongevalideerde jq Output

**Wat:** `jq -r '.access_token'` gebruiken zonder te checken of het resultaat `null` of leeg is.
**Waarom slecht:** Als de API een onverwacht JSON-formaat retourneert, geeft jq `null` terug. Dit wordt dan als token doorgestuurd naar volgende API-calls, die cryptisch falen.

**In plaats daarvan:** Altijd jq output valideren:

```bash
local token
token=$(echo "$body" | jq -r '.access_token // empty')
if [[ -z "$token" ]]; then
    log "ERROR" "Geen access_token in response"
    return 1
fi
```

## Exit Codes

Het script gebruikt sysexits.h-conventie voor duidelijke signalering naar cron/monitoring:

| Exit Code | Constante | Betekenis |
|-----------|-----------|-----------|
| 0 | EX_OK | Succes (IP bijgewerkt of geen wijziging nodig) |
| 1 | (algemeen) | Onverwachte fout |
| 69 | EX_UNAVAILABLE | Externe service niet bereikbaar (IP-service of Azure API) |
| 78 | EX_CONFIG | Configuratiefout (ontbrekende env vars) |

**Waarom deze codes:**
- `0` voor zowel "geen wijziging" als "succesvol bijgewerkt" -- beide zijn correcte uitkomsten
- `78` voor configuratiefouten zodat monitoring kan onderscheiden "kapotte setup" van "tijdelijke API-fout"
- `69` voor onbereikbare services zodat monitoring weet dat een retry zinvol kan zijn

## Script Structuur (bestandsindeling)

```bash
#!/usr/bin/env bash
# ns4j - Azure DNS Dynamic Updater
# ...header/licentie...

set -euo pipefail

# --- Constanten ---
readonly SCRIPT_NAME="ns4j"
readonly API_VERSION="2018-05-01"
readonly AZURE_SCOPE="https://management.azure.com/.default"

# --- Logging ---
log() { ... }

# --- Configuratie ---
validate_config() { ... }

# --- Azure Auth ---
get_access_token() { ... }

# --- IP Detectie ---
get_public_ip() { ... }

# --- DNS Operaties ---
get_dns_record() { ... }
update_dns() { ... }

# --- Main ---
main() {
    validate_config

    local access_token
    access_token=$(get_access_token) || exit 69

    local current_ip
    current_ip=$(get_public_ip) || exit 69

    local dns_ip
    dns_ip=$(get_dns_record "$access_token") || exit 69

    if [[ "$current_ip" == "$dns_ip" ]]; then
        log "INFO" "IP ongewijzigd (${current_ip}), geen update nodig"
        exit 0
    fi

    log "INFO" "IP gewijzigd: ${dns_ip} -> ${current_ip}, update DNS..."

    update_dns "$access_token" "$current_ip" || exit 69

    log "INFO" "DNS record bijgewerkt naar ${current_ip}"
    exit 0
}

main "$@"
```

## API Endpoints Samenvatting (geverifieerd)

| Operatie | Methode | URL |
|----------|---------|-----|
| OAuth2 Token | POST | `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token` |
| DNS Record GET | GET | `https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}/A/{record}?api-version=2018-05-01` |
| DNS Record PUT | PUT | `https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}/A/{record}?api-version=2018-05-01` |

## Environment Variables

| Variabele | Vereist | Standaard | Beschrijving |
|-----------|---------|-----------|--------------|
| AZURE_TENANT_ID | Ja | -- | Azure AD tenant ID |
| AZURE_CLIENT_ID | Ja | -- | Service Principal client ID |
| AZURE_CLIENT_SECRET | Ja | -- | Service Principal client secret |
| AZURE_SUBSCRIPTION_ID | Ja | -- | Azure subscription ID |
| AZURE_RESOURCE_GROUP | Ja | -- | Resource group met de DNS zone |
| DNS_ZONE_NAME | Ja | -- | DNS zone naam (bijv. `example.com`) |
| DNS_RECORD_NAME | Ja | -- | A-record naam (bijv. `home` voor `home.example.com`) |
| DNS_TTL | Nee | 300 | TTL in seconden voor het A-record |
| IP_SERVICE_URL | Nee | `https://api.ipify.org` | URL van de IP-detectieservice |

## Suggesties voor Build-volgorde

De componenten hebben een duidelijke afhankelijkheidsketen:

```
1. log()              <-- geen dependencies, basis voor alles
2. validate_config()  <-- gebruikt log(), geen externe calls
3. get_access_token() <-- gebruikt log(), curl, jq
4. get_public_ip()    <-- gebruikt log(), curl (geen jq nodig)
5. get_dns_record()   <-- gebruikt log(), curl, jq, heeft token nodig
6. update_dns()       <-- gebruikt log(), curl, jq, heeft token + IP nodig
7. main()             <-- orchestreert alles
```

**Aanbevolen bouwvolgorde:**
1. **Eerst:** `log()` en `validate_config()` -- het fundament, direct testbaar zonder externe services
2. **Dan:** `get_access_token()` -- de kritieke Azure auth, apart testbaar met echte credentials
3. **Dan:** `get_public_ip()` en `get_dns_record()` -- de twee "lees"-operaties, onafhankelijk van elkaar
4. **Laatste:** `update_dns()` en `main()` -- de "schrijf"-operatie en de orkestratie

Dit volgt het principe: eerst lezen, dan schrijven. Elke stap is afzonderlijk testbaar voordat de volgende gebouwd wordt.

## Scalability Considerations

Niet van toepassing -- dit is een single-record, single-run script. Er is geen scaling scenario. Mocht het ooit nodig zijn om meerdere records te updaten, dan is de juiste aanpak meerdere cron entries met verschillende env vars, niet een complexer script.

## Sources

- Azure DNS Record Sets - Create Or Update: https://learn.microsoft.com/en-us/rest/api/dns/record-sets/create-or-update?view=rest-dns-2018-05-01 (gescraped en geverifieerd 2026-03-30)
- Azure DNS Record Sets - Get: https://learn.microsoft.com/en-us/rest/api/dns/record-sets/get?view=rest-dns-2018-05-01 (gescraped en geverifieerd 2026-03-30)
- Microsoft identity platform OAuth 2.0 client credentials flow: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow (gescraped en geverifieerd 2026-03-30)
- sysexits.h exit codes: BSD/POSIX conventie, breed geaccepteerd in Unix scripting
