# Phase 1: Werkend kern-script - Research

**Researched:** 2026-03-31
**Domain:** Bash DDNS-client voor Azure DNS (bash + curl + jq)
**Confidence:** HIGH

## Summary

Phase 1 is een greenfield bash script dat als DDNS-client voor Azure DNS werkt. Het script volgt een strikt lineaire pipeline: configuratie valideren, OAuth2 token ophalen, publiek IP detecteren, huidig DNS record vergelijken, en bij wijziging het A-record updaten via de Azure DNS REST API. Alle technische keuzes (bash, curl, jq, API-versie 2018-05-01) zijn eerder besloten en geverifieerd.

Het project heeft uitgebreide eerdere research (`.planning/research/`) die de Azure REST API endpoints, OAuth2 flow, IP-detectieservices, en pitfalls grondig heeft onderzocht en geverifieerd tegen officieel Microsoft documentatie. Deze phase research consolideert die bevindingen en voegt de CONTEXT.md beslissingen toe als constraints voor de planner.

**Primary recommendation:** Bouw het script als een enkel bestand `ns4j` in de repo-root met functies per component (log, validate_config, get_access_token, get_public_ip, get_dns_record, update_dns, main). Volg de bouwvolgorde: fundament eerst (log + config), dan auth, dan lees-operaties, dan schrijf-operatie.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Gestructureerd formaat: `[TIMESTAMP] LEVEL: bericht` (bijv. `[2026-03-31 08:00:01] INFO: IP unchanged (1.2.3.4)`)
- **D-02:** Routing: INFO/SKIP berichten naar stdout, ERROR berichten naar stderr. Cron mailt alleen bij stderr-output/non-zero exit.
- **D-03:** Alle ontbrekende variabelen tegelijk tonen, dan exit 1. Loop over de 7 verplichte vars, toon `ERROR: $var is niet ingesteld` per ontbrekende variabele.
- **D-04:** GET het huidige A-record. HTTP 200 = vergelijk IP, skip PUT als ongewijzigd. HTTP 404 = record bestaat nog niet, IP is per definitie anders, doe PUT. Andere HTTP status = abort met exit code 4.
- **D-05:** Bestandsnaam `ns4j` (zonder extensie) in de repo-root.
- **D-06:** Shebang `#!/bin/bash` (absoluut pad, gegarandeerd op Raspberry Pi OS, geen PATH-afhankelijkheid in cron).

### Claude's Discretion
- Script interne structuur (functies vs lineair) -- Claude bepaalt de beste organisatie
- Exacte timestamp formaat (ISO 8601 of korter) -- Claude kiest passend formaat
- Variabele naamgeving binnen het script -- Claude volgt bash conventies

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IP-01 | Script haalt het huidige publieke IPv4-adres op via een externe service (icanhazip.com) | Pattern 7 (IP-detectie): curl naar `https://icanhazip.com`, output is plain-text IPv4 + newline. `--max-time 10` als timeout. |
| IP-03 | Script vergelijkt het huidige IP met het bestaande DNS record en skipt update als ongewijzigd | Pattern 3 (GET-then-PUT): haal huidig A-record op via Azure DNS REST API GET, vergelijk met gedetecteerd IP. D-04 specificeert ook HTTP 404 handling. |
| AUTH-01 | Script verkrijgt een OAuth2 access token via Service Principal client credentials flow | Pattern 2 (OAuth2 Client Credentials): POST naar `login.microsoftonline.com/{tenant}/oauth2/v2.0/token` met client_id, client_secret, scope, grant_type. |
| AUTH-02 | Script controleert HTTP response codes van alle Azure API calls | Pattern 5 (HTTP Status + Body Extractie): `--write-out "\n%{http_code}"` pattern voor elke curl call. |
| DNS-01 | Script haalt het huidige A-record op uit Azure DNS via REST API (GET) | Pattern 3: GET endpoint geverifieerd, response structuur: `properties.ARecords[0].ipv4Address`. HTTP 404 = record bestaat niet (D-04). |
| DNS-02 | Script update het A-record in Azure DNS via REST API (PUT) wanneer het IP gewijzigd is | Pattern 4 (Update DNS via PUT): PUT met JSON payload `{properties: {TTL: $ttl, ARecords: [{ipv4Address: $ip}]}}`. Succes = HTTP 200 of 201. |
| CFG-01 | Alle configuratie via environment variables | 7 verplichte vars: AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, DNS_ZONE_NAME, DNS_RECORD_NAME. Optioneel: DNS_TTL (default 300). |
| CFG-02 | Script valideert alle verplichte env vars bij startup met beschrijvende foutmelding per ontbrekende variabele | Pattern 1 (Fail-Fast): loop over required_vars array, verzamel alle ontbrekende, toon per stuk, exit 1 (D-03). |
| OPS-01 | Script gebruikt correcte exit codes (0=ok, 1=config-fout, 2=IP-fout, 3=auth-fout, 4=DNS-fout) | Exit code mapping uit REQUIREMENTS.md. NB: verschilt van sysexits.h codes in eerdere research -- REQUIREMENTS.md is leidend. |
| OPS-02 | Script logt naar stdout (info/succes) en stderr (fouten) | Pattern 6 (Logging) + D-01/D-02: gestructureerd formaat met timestamp, ERROR naar stderr, rest naar stdout. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Runtime**: bash + curl (standaard op elke Pi), jq voor JSON parsing
- **Platform**: Raspberry Pi (ARM, beperkt geheugen/CPU)
- **Dependencies**: Zero buiten bash, curl, en jq
- **Auth**: Azure Service Principal (client credentials flow)
- **Shebang**: `#!/bin/bash` (D-06, absoluut pad)
- **Bestandsnaam**: `ns4j` zonder extensie in repo-root (D-05)
- **API versie**: `2018-05-01` voor Azure DNS (gepind, niet configureerbaar)
- **IP service primair**: `https://icanhazip.com` (Cloudflare-backed)
- **Geen**: Azure CLI, Docker, systemd, token caching, preview API versies

## Standard Stack

### Core
| Technology | Version | Doel | Waarom Standard |
|------------|---------|------|-----------------|
| bash | >= 4.x | Script interpreter | Standaard op Raspberry Pi OS; nodig voor arrays, `${!var}` indirect expansion, `[[ ]]` tests |
| curl | >= 7.68 | HTTP client | Standaard op Pi OS; HTTPS, custom headers, POST bodies, `--write-out`, `--data-urlencode` |
| jq | >= 1.6 | JSON parsing | Robuuste JSON parsing; `// empty` fallback, `--arg`/`--argjson` voor veilige JSON-constructie |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| jq | grep/sed/awk op JSON | Fragiel; breekt bij onverwachte formatting, geen escaping |
| jq | python3 -c | Extra dependency; jq is 500KB, Python runtime is 50MB+ |
| curl | wget | wget mist `--write-out`, `--data-urlencode`, header control |

## Architecture Patterns

### Recommended Script Structure
```
ns4j                    # Enkel bestand in repo-root, executable (chmod +x)
```

Intern georganiseerd als functies:
```
#!/bin/bash
set -euo pipefail
trap 'log "ERROR" "Onverwachte fout op regel ${LINENO}"' ERR

# --- Constanten ---
readonly API_VERSION="2018-05-01"
readonly AZURE_SCOPE="https://management.azure.com/.default"
readonly IP_SERVICE="https://icanhazip.com"

# --- Functies ---
log()                   # Gestructureerde logging (D-01, D-02)
validate_config()       # Env var validatie (CFG-01, CFG-02, D-03)
get_access_token()      # OAuth2 client credentials (AUTH-01)
get_public_ip()         # IP detectie (IP-01)
get_dns_record()        # Azure DNS GET (DNS-01)
update_dns()            # Azure DNS PUT (DNS-02)
main()                  # Orchestratie

main "$@"
```

### Pattern 1: Log Functie (D-01, D-02, OPS-02)
**What:** Gestandaardiseerde log output met timestamp en level-based routing.
**When to use:** Elke plek in het script waar output nodig is.
```bash
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ "$level" == "ERROR" ]]; then
        echo "[${timestamp}] ${level}: ${message}" >&2
    else
        echo "[${timestamp}] ${level}: ${message}"
    fi
}
```
**Source:** CONTEXT.md D-01 (formaat), D-02 (routing)

### Pattern 2: Fail-Fast Config Validatie (CFG-02, D-03)
**What:** Alle verplichte env vars tegelijk controleren, per ontbrekende var een foutmelding, dan exit 1.
**When to use:** Eerste stap in main(), voor elke API call.
```bash
validate_config() {
    local missing=0
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
            log "ERROR" "${var} is niet ingesteld"
            missing=1
        fi
    done

    if [[ "$missing" -eq 1 ]]; then
        exit 1
    fi
}
```
**Source:** CONTEXT.md D-03, REQUIREMENTS.md CFG-01/CFG-02

### Pattern 3: HTTP Status + Body Extractie (AUTH-02)
**What:** Eenvoudig curl pattern om zowel response body als HTTP status code te vangen.
**When to use:** Elke curl call naar een API.
```bash
response=$(curl --silent --show-error --max-time 10 \
    --write-out "\n%{http_code}" \
    ...)
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
```
**Source:** Research ARCHITECTURE.md Pattern 5, geverifieerd

### Pattern 4: OAuth2 Token Request (AUTH-01)
**What:** POST naar Entra ID token endpoint met client credentials.
**When to use:** Elke run, vers token per keer (geen caching).
```bash
get_access_token() {
    local token_url="https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token"

    # curl met --data-urlencode voor correcte encoding van speciale tekens
    response=$(curl --silent --show-error --max-time 10 \
        --write-out "\n%{http_code}" \
        --request POST \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "client_id=${AZURE_CLIENT_ID}" \
        --data-urlencode "client_secret=${AZURE_CLIENT_SECRET}" \
        --data-urlencode "scope=https://management.azure.com/.default" \
        --data-urlencode "grant_type=client_credentials" \
        "$token_url")

    # Parse http_code en body
    # Valideer http_code == 200
    # Extract access_token met jq -r '.access_token // empty'
    # Valideer dat token niet leeg is
}
```
**Source:** Microsoft OAuth2 Client Credentials Flow docs (geverifieerd 2026-03-31)

### Pattern 5: DNS GET met 404 Handling (DNS-01, D-04)
**What:** GET huidig A-record. HTTP 200 = vergelijk, HTTP 404 = record bestaat niet (doe PUT), anders = abort exit 4.
**When to use:** Voor de IP-vergelijking.
```bash
get_dns_record() {
    local access_token="$1"
    local dns_url="https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}/providers/Microsoft.Network/dnsZones/${DNS_ZONE_NAME}/A/${DNS_RECORD_NAME}?api-version=2018-05-01"

    # curl GET met Authorization: Bearer header
    # HTTP 200: parse .properties.ARecords[0].ipv4Address
    # HTTP 404: echo "" (leeg = record bestaat niet, forceer update)
    # Andere status: log error, exit 4
}
```
**Source:** Azure DNS REST API docs (geverifieerd 2026-03-31), CONTEXT.md D-04

### Pattern 6: DNS PUT met JSON via jq (DNS-02)
**What:** PUT request met jq-geconstrueerde JSON payload.
**When to use:** Wanneer IP gewijzigd is (of record niet bestaat).
```bash
update_dns() {
    local access_token="$1"
    local new_ip="$2"
    local ttl="${DNS_TTL:-300}"

    local payload
    payload=$(jq -n \
        --arg ip "$new_ip" \
        --argjson ttl "$ttl" \
        '{properties: {TTL: $ttl, ARecords: [{ipv4Address: $ip}]}}')

    # curl PUT met Content-Type: application/json
    # Succes: HTTP 200 (updated) of 201 (created)
}
```
**Source:** Azure DNS Record Sets Create-Or-Update docs (geverifieerd 2026-03-31)

### Anti-Patterns to Avoid
- **Lokaal cache-bestand voor IP-vergelijking:** Desynct met werkelijke DNS-staat. Gebruik altijd Azure DNS GET als authoritative bron.
- **Token caching naar bestand:** Onnodige complexiteit bij cron-interval van 5+ minuten. Vers token per run.
- **JSON-constructie via string concatenatie:** Gebruik jq `--arg`/`--argjson` voor correcte escaping.
- **`set -e` zonder `trap`:** Script stopt stil zonder foutmelding. Gebruik `trap` voor ERR signaal.
- **Ongevalideerde jq output:** Gebruik `jq -r '.access_token // empty'` en check op lege string.
- **Credentials in het script:** Altijd via environment variables.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Regex/sed/awk op JSON | jq | JSON structuur kan varieren, whitespace verschilt, nesting is onvoorspelbaar |
| JSON constructie | String concatenatie (`"{"prop":"$val"}"`) | `jq -n --arg` | Correcte escaping van speciale tekens, geen injection risico |
| URL encoding | Handmatige `%`-encoding | `curl --data-urlencode` | curl doet dit automatisch en correct |
| HTTP status extraction | Twee curl calls (HEAD + GET) | `--write-out "\n%{http_code}"` | Een curl call, body + status in een keer |
| IPv4 validatie | Complexe regex met octet range checks | Simpele format check `^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$` | Voldoende voor dit use case; de bron (icanhazip) geeft altijd valide IPs |

## Common Pitfalls

### Pitfall 1: Cron-omgeving mist PATH en env vars
**What goes wrong:** Script werkt handmatig maar faalt in cron. Cron heeft minimale PATH (`/usr/bin:/bin`), geen geladen profile, geen env vars.
**Why it happens:** Cron erft niet de gebruikersomgeving.
**How to avoid:** D-06 lost PATH-deel op: `#!/bin/bash` (absoluut pad). Env vars moeten in crontab of /etc/environment. Script moet `command -v jq` checken als preconditie. Documenteer dit in README.
**Warning signs:** "command not found" errors in cron mail.

### Pitfall 2: IP-service retourneert garbage
**What goes wrong:** HTML-foutpagina, lege response, of proxy-IP wordt als A-record doorgestuurd.
**Why it happens:** Service is tijdelijk down, rate-limited, of er is een captive portal.
**How to avoid:** Valideer response als IPv4 format. Check curl exit code EN HTTP status. Gebruik `--max-time 10`.
**Warning signs:** DNS record bevat onverwacht IP.

### Pitfall 3: OAuth2 scope verkeerd
**What goes wrong:** Token wordt opgehaald maar werkt niet voor Azure DNS.
**Why it happens:** Scope is `https://graph.microsoft.com/.default` i.p.v. `https://management.azure.com/.default`.
**How to avoid:** Hardcode scope als readonly constante.
**Warning signs:** HTTP 401 op DNS API calls ondanks geldig token.

### Pitfall 4: Bash quoting-fouten
**What goes wrong:** Variabelen met spaties of speciale tekens veroorzaken word splitting of glob expansion.
**Why it happens:** Unquoted `$VAR` in bash.
**How to avoid:** Quote ALTIJD variabelen: `"$VAR"`. Gebruik `set -u` voor ongedefinieerde vars. Draai shellcheck op het script.
**Warning signs:** "400 Bad Request" van Azure API.

### Pitfall 5: jq retourneert "null" bij ontbrekend veld
**What goes wrong:** `jq -r '.access_token'` retourneert de string "null" als het veld niet bestaat. Dit wordt als Bearer token doorgestuurd.
**Why it happens:** jq zonder `// empty` fallback.
**How to avoid:** Gebruik `jq -r '.access_token // empty'` en check op lege string.
**Warning signs:** Cryptische auth-fouten op volgende API calls.

### Pitfall 6: Exit codes niet consistent met REQUIREMENTS.md
**What goes wrong:** Planner/implementer gebruikt sysexits.h codes (78, 69) uit eerdere research i.p.v. de requirements.
**Why it happens:** Research ARCHITECTURE.md documenteerde sysexits.h, maar REQUIREMENTS.md specificeert 0-4.
**How to avoid:** Gebruik UITSLUITEND de exit codes uit OPS-01: 0=ok, 1=config-fout, 2=IP-fout, 3=auth-fout, 4=DNS-fout. D-03 specificeert ook exit 1 voor config.
**Warning signs:** Tests/monitoring verwachten verkeerde exit codes.

### Pitfall 7: Env var namen inconsistent
**What goes wrong:** Script gebruikt `AZURE_DNS_ZONE` (REQUIREMENTS.md) maar documentatie/CLAUDE.md gebruikt `DNS_ZONE_NAME`.
**Why it happens:** REQUIREMENTS.md en CLAUDE.md gebruiken verschillende namen.
**How to avoid:** Gebruik de namen uit CLAUDE.md (authoritative project doc): `DNS_ZONE_NAME`, `DNS_RECORD_NAME`. CLAUDE.md is de single source of truth na de project research fase.
**Warning signs:** Gebruiker stelt verkeerde env vars in.

## Code Examples

### Volledige curl voor OAuth2 Token Request
```bash
# Source: Microsoft Entra OAuth2 Client Credentials Flow (geverifieerd 2026-03-31)
response=$(curl --silent --show-error \
    --max-time 10 \
    --write-out "\n%{http_code}" \
    --request POST \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=${AZURE_CLIENT_ID}" \
    --data-urlencode "client_secret=${AZURE_CLIENT_SECRET}" \
    --data-urlencode "scope=https://management.azure.com/.default" \
    --data-urlencode "grant_type=client_credentials" \
    "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token")
```

### Azure DNS GET Response Structuur
```json
// Source: Azure DNS REST API docs (geverifieerd 2026-03-31)
// GET .../dnsZones/{zone}/A/{record}?api-version=2018-05-01
{
  "id": "/subscriptions/.../A/record1",
  "name": "record1",
  "type": "Microsoft.Network/dnsZones/A",
  "properties": {
    "TTL": 300,
    "ARecords": [
      { "ipv4Address": "1.2.3.4" }
    ]
  }
}
```

### Azure DNS PUT Request Body
```json
// Source: Azure DNS REST API docs (geverifieerd 2026-03-31)
// PUT .../dnsZones/{zone}/A/{record}?api-version=2018-05-01
{
  "properties": {
    "TTL": 300,
    "ARecords": [
      { "ipv4Address": "5.6.7.8" }
    ]
  }
}
```
PUT retourneert HTTP 200 (record bestond al, bijgewerkt) of HTTP 201 (nieuw record aangemaakt).

### Exit Code Mapping (OPS-01)
```bash
# REQUIREMENTS.md is leidend -- NIET sysexits.h
readonly EXIT_OK=0            # Succes (IP bijgewerkt of ongewijzigd)
readonly EXIT_CONFIG=1        # Configuratiefout (ontbrekende env vars)
readonly EXIT_IP=2            # IP-detectie mislukt
readonly EXIT_AUTH=3          # Azure authenticatie mislukt
readonly EXIT_DNS=4           # DNS operatie mislukt
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Azure DNS API preview versies | API versie 2018-05-01 (stabiel) | Mei 2018 | Geen nieuwere GA release; 2023-07-01-preview valt terug op 2018-05-01 |
| OAuth2 v1.0 endpoint | OAuth2 v2.0 endpoint (`/v2.0/token`) | ~2019 | v2.0 is huidige standaard, v1.0 nog ondersteund maar niet aanbevolen |

**Deprecated/outdated:**
- Azure DNS API preview versies (2023-07-01-preview): geen meerwaarde, risico op breaking changes
- OAuth2 v1.0 token endpoint: vervangen door v2.0, scope-based i.p.v. resource-based

## Open Questions

1. **Env var naamgeving: DNS_ZONE_NAME vs AZURE_DNS_ZONE**
   - What we know: CLAUDE.md (project doc) gebruikt `DNS_ZONE_NAME` en `DNS_RECORD_NAME`. REQUIREMENTS.md CFG-01 gebruikt `AZURE_DNS_ZONE` en `AZURE_DNS_RECORD`.
   - What's unclear: Welke set is de bedoeling van de gebruiker?
   - Recommendation: Gebruik de CLAUDE.md namen (`DNS_ZONE_NAME`, `DNS_RECORD_NAME`) -- dit is het authoritative project document dat door de gebruiker is goedgekeurd na de project research fase. De REQUIREMENTS.md kan een draft-inconsistentie bevatten.

2. **DNS_TTL env var naam**
   - What we know: CLAUDE.md gebruikt `DNS_TTL`. REQUIREMENTS.md DNS-03 noemt `AZURE_DNS_TTL`. DNS-03 is NIET in scope voor Phase 1 (dat is Phase 2), maar `DNS_TTL` wordt impliciet gebruikt als default in de PUT payload.
   - Recommendation: Gebruik `DNS_TTL` (CLAUDE.md) met default 300. Dit is optioneel en niet gekoppeld aan een Phase 1 requirement, maar de PUT payload heeft een TTL nodig.

## Environment Availability

> Step 2.6: De target runtime is een Raspberry Pi, niet de dev machine. Het script heeft geen build-time dependencies.

| Dependency | Required By | Available (dev) | Version (dev) | Fallback |
|------------|------------|-----------------|---------------|----------|
| bash | Script interpreter | Ja | 5.3.9 | -- |
| curl | HTTP calls | Ja | 8.7.1 | -- |
| jq | JSON parsing | Ja | 1.8.1 | -- |

**Target (Raspberry Pi OS):**
- bash: standaard geinstalleerd (>= 4.x)
- curl: standaard geinstalleerd (>= 7.68)
- jq: NIET standaard geinstalleerd -- `sudo apt-get install -y jq` nodig. Script moet `command -v jq` checken.

**Missing dependencies with no fallback:** Geen (jq is installeerbaar via apt)

**Missing dependencies with fallback:** Geen

## Sources

### Primary (HIGH confidence)
- Azure DNS REST API - Record Sets Create Or Update: https://learn.microsoft.com/en-us/rest/api/dns/record-sets/create-or-update?view=rest-dns-2018-05-01 (gescraped via Firecrawl 2026-03-31)
- Azure DNS REST API - Record Sets Get: https://learn.microsoft.com/en-us/rest/api/dns/record-sets/get?view=rest-dns-2018-05-01 (gescraped via Firecrawl 2026-03-31)
- Microsoft Entra OAuth2 Client Credentials Flow: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow (gescraped via Firecrawl 2026-03-31)
- Project research documents: `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md`, `.planning/research/STACK.md` (geverifieerd 2026-03-30)
- CLAUDE.md project instructions (goedgekeurd door gebruiker)

### Secondary (MEDIUM confidence)
- IP-detectieservices (icanhazip.com, checkip.amazonaws.com): live getest 2026-03-30, response format bevestigd

### Tertiary (LOW confidence)
- Geen

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- bash/curl/jq zijn locked decisions, versies geverifieerd
- Architecture: HIGH -- pipeline pattern is triviaal en gedocumenteerd in eerdere research, API endpoints geverifieerd tegen officieel Microsoft docs
- Pitfalls: HIGH -- alle pitfalls gedocumenteerd in `.planning/research/PITFALLS.md` met officieel bronnen

**Research date:** 2026-03-31
**Valid until:** Onbeperkt -- Azure DNS API 2018-05-01 is stabiel sinds 2018, bash/curl/jq zijn mature tools
