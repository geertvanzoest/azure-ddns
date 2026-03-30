# Technology Stack

**Project:** ns4j -- Azure DNS Dynamic Updater
**Researched:** 2026-03-30

## Recommended Stack

### Runtime & Shell

| Technology | Version | Doel | Waarom |
|------------|---------|------|--------|
| bash | >= 4.x | Script interpreter | Standaard op Raspberry Pi OS; POSIX-compatible, heeft arrays en string manipulation nodig |
| curl | >= 7.68 | HTTP client | Standaard op Pi OS; ondersteunt HTTPS, custom headers, POST bodies -- alles wat nodig is voor OAuth2 + REST API |
| jq | >= 1.6 | JSON parsing | Niet standaard geinstalleerd maar beschikbaar via `apt install jq`; noodzakelijk voor betrouwbare JSON parsing van OAuth2 tokens en API responses |

**Confidence:** HIGH -- bash en curl zitten standaard op Raspberry Pi OS. jq moet geinstalleerd worden maar is beschikbaar in de Debian/Raspbian repos.

### Azure DNS REST API

| Endpoint | API Version | Doel | Waarom |
|----------|-------------|------|--------|
| `PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}/A/{record}` | `2018-05-01` | A-record aanmaken/updaten | Dit is de **huidige stabiele API versie** voor Azure DNS. Er bestaat geen nieuwere GA release -- 2023-07-01-preview valt terug naar 2018-05-01. Bewezen stabiel sinds mei 2018. |
| `GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}/A/{record}` | `2018-05-01` | Huidig A-record ophalen | Nodig om te checken of IP daadwerkelijk gewijzigd is, voordat een onnodige PUT wordt gedaan |

**Base URL:** `https://management.azure.com`

**Volledige PUT URL:**
```
https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/dnsZones/{zoneName}/A/{relativeRecordSetName}?api-version=2018-05-01
```

**Request body voor A-record update:**
```json
{
  "properties": {
    "TTL": 300,
    "ARecords": [
      {
        "ipv4Address": "1.2.3.4"
      }
    ]
  }
}
```

**Response:** 200 OK (update) of 201 Created (nieuw). Body bevat het volledige RecordSet object inclusief `properties.ARecords[0].ipv4Address`.

**Rate limits (per zone):**
| Operatie | Limiet |
|----------|--------|
| Create/PUT | 40/min |
| GET | 1000/min |
| List | 60/min |

Bij een cron job die elke 5 minuten draait is throttling geen enkel risico (maximaal 2 calls per run: 1 GET + 1 PUT).

**Confidence:** HIGH -- geverifieerd met officieel Microsoft Learn documentatie, inclusief API versie fallback-gedrag.

### Azure OAuth2 (Service Principal Authentication)

| Component | Waarde | Doel |
|-----------|--------|------|
| Token endpoint | `https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token` | OAuth2 token ophalen |
| Grant type | `client_credentials` | Service-to-service auth zonder gebruikersinteractie |
| Scope | `https://management.azure.com/.default` | Toegang tot Azure Resource Management API |
| Content-Type | `application/x-www-form-urlencoded` | Vereist formaat voor token request |

**Volledige curl commando voor token:**
```bash
curl -s -X POST \
  "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${AZURE_CLIENT_ID}&client_secret=${AZURE_CLIENT_SECRET}&scope=https%3A%2F%2Fmanagement.azure.com%2F.default&grant_type=client_credentials"
```

**Response:**
```json
{
  "token_type": "Bearer",
  "expires_in": 3599,
  "access_token": "eyJ0eXAiOiJKV1..."
}
```

**Token geldigheid:** 3599 seconden (~1 uur). Geen refresh token bij client_credentials flow -- gewoon een nieuw token ophalen per run. Bij een cron interval van 5 minuten is dit efficienter dan token caching.

**Vereiste Azure RBAC rol:** `DNS Zone Contributor` (role ID: `befefa01-2a29-4197-83a8-272ff33ce314`). Geeft `Microsoft.Network/dnsZones/*` rechten. Scope op de specifieke DNS zone resource, niet op subscription-niveau.

**Confidence:** HIGH -- geverifieerd met officieel Microsoft Entra ID documentatie (client credentials flow) en Azure RBAC docs.

### Publiek IP Detectie

| Service | URL | Eigenaar | Betrouwbaarheid | Aanbeveling |
|---------|-----|----------|-----------------|-------------|
| **icanhazip.com** | `https://icanhazip.com` | Cloudflare | Zeer hoog -- Anycast netwerk, Cloudflare backbone | **Primair** -- eigendom van Cloudflare, dus dezelfde infra als 1.1.1.1 DNS |
| **checkip.amazonaws.com** | `https://checkip.amazonaws.com` | Amazon AWS | Zeer hoog -- AWS global infra | **Fallback 1** -- AWS-backed, geen rate limits gedocumenteerd |
| api.ipify.org | `https://api.ipify.org` | Derden (via Cloudflare) | Matig -- HEAD request gaf HTTP 520 tijdens test | **Niet gebruiken** -- instabiel, 520 errors waargenomen op 2026-03-30 |
| ifconfig.me | `https://ifconfig.me` | Derden (via Google) | Matig -- HEAD request gaf HTTP 405 | **Niet gebruiken** -- 405 op HEAD, langzamer dan alternatieven |
| ipinfo.io/ip | `https://ipinfo.io/ip` | ipinfo.io | Hoog maar rate-limited | **Niet gebruiken** -- commerciele API met rate limits voor gratis tier |

**Getest op 2026-03-30:** Alle 5 services gaven correct hetzelfde IPv4-adres terug via `curl -s -4`. Maar response headers en stabiliteit varieerden sterk.

**Aanbeveling:** Gebruik icanhazip.com als primaire service en checkip.amazonaws.com als fallback. Beide zijn eigendom van cloud-giganten (Cloudflare resp. AWS), draaien op Anycast/global infra, en retourneren een plain-text IPv4-adres met een newline. Geen JSON parsing nodig.

**Fallback patroon:**
```bash
ip=$(curl -s -4 --max-time 5 https://icanhazip.com) \
  || ip=$(curl -s -4 --max-time 5 https://checkip.amazonaws.com)
ip=$(echo "$ip" | tr -d '[:space:]')  # strip trailing newline/whitespace
```

**Confidence:** HIGH -- services live getest, eigendom geverifieerd. icanhazip.com is eigendom van Cloudflare (overgenomen van Major Hayden). checkip.amazonaws.com is AWS-native.

### Cron (Scheduling)

| Technology | Doel | Waarom |
|------------|------|--------|
| cron / crontab | Script periodiek uitvoeren | Standaard op elke Linux distro; simpelst mogelijke scheduler; gebruiker configureert zelf het interval |

**Aanbevolen crontab entry:**
```cron
*/5 * * * * /usr/local/bin/ns4j.sh 2>&1 | logger -t ns4j
```

Elke 5 minuten is een goede balans tussen actualiteit en API-belasting. De `logger -t ns4j` pipe stuurt output naar syslog zodat het terug te vinden is via `journalctl -t ns4j`.

**Confidence:** HIGH -- standaard Linux tooling, geen research nodig.

## Benodigde Environment Variables

| Variable | Doel | Voorbeeld |
|----------|------|-----------|
| `AZURE_TENANT_ID` | Microsoft Entra tenant GUID | `aaaabbbb-0000-cccc-1111-dddd2222eeee` |
| `AZURE_CLIENT_ID` | Service Principal application ID | `11112222-bbbb-3333-cccc-4444dddd5555` |
| `AZURE_CLIENT_SECRET` | Service Principal secret | `A1bC2dE3fH4iJ5kL6mN7oP8qR9sT0u` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription GUID | `00000000-0000-0000-0000-000000000000` |
| `AZURE_RESOURCE_GROUP` | Resource group van de DNS zone | `rg-dns` |
| `DNS_ZONE_NAME` | DNS zone naam (zonder trailing dot) | `example.com` |
| `DNS_RECORD_NAME` | Relatieve recordnaam | `home` (resulteert in `home.example.com`) |
| `DNS_TTL` | TTL in seconden (optioneel, default 300) | `300` |

## Alternatives Considered

| Categorie | Aanbevolen | Alternatief | Waarom niet |
|-----------|------------|-------------|-------------|
| Runtime | bash + curl | Python | Overkill -- extra runtime dependency op Pi, bash + curl volstaat voor 2 API calls |
| Runtime | bash + curl | Node.js | Zware runtime (100+ MB), niet standaard op Pi |
| Azure access | REST API + curl | Azure CLI (`az`) | 500+ MB install, Python dependency, overkill voor 2 API calls |
| Azure access | REST API + curl | Azure SDK | Vereist runtime (Python/Node), geen meerwaarde voor simpele REST calls |
| JSON parsing | jq | bash string manipulation | Fragiel -- regex op JSON breekt bij onverwachte formatting; jq is 500KB en robuust |
| JSON parsing | jq | python3 -c | Extra dependency die niet nodig is als jq beschikbaar is |
| IP detectie | icanhazip.com | ifconfig.me | Langzamer, HTTP 405 op HEAD, niet Cloudflare-backed |
| IP detectie | icanhazip.com | api.ipify.org | HTTP 520 errors waargenomen, instabiel |
| Scheduling | cron | systemd timer | Complexer config, geen meerwaarde voor een simpel script |
| Scheduling | cron | daemon/loop | Resource-verspilling op Pi, complexere error handling |
| Auth | Client secret | Certificate | Complexer setup (openssl nodig voor JWT assertion), geen meerwaarde voor een Pi script |

## Installatie

```bash
# Enige dependency die niet standaard aanwezig is
sudo apt install -y jq

# Script installeren
sudo install -m 755 ns4j.sh /usr/local/bin/ns4j.sh

# Cron job instellen (als root of gebruiker)
(crontab -l 2>/dev/null; echo '*/5 * * * * /usr/local/bin/ns4j.sh 2>&1 | logger -t ns4j') | crontab -

# Environment variables instellen in crontab of /etc/environment
# NIET in het script zelf (secrets horen niet in code)
```

## Wat NIET te gebruiken

| Technologie | Waarom niet |
|-------------|-------------|
| Azure CLI (`az`) | 500+ MB, Python dependency, start traag op Pi ARM -- voor 2 API calls absurd |
| Azure SDK (Python/Node) | Vereist runtime, honderden MB aan dependencies |
| Docker | Container overhead op Pi voor een 50-regel bash script is onzin |
| systemd service (daemon) | Script hoeft niet continu te draaien, cron is simpeler |
| Token caching naar file | Bij 5-min interval is een vers token per run simpeler dan file-locking en expiry checks |
| Preview API versies | 2023-07-01-preview valt terug naar 2018-05-01; geen meerwaarde, wel risico op breaking changes |

## Bronnen

| Bron | URL | Confidence |
|------|-----|------------|
| Azure DNS REST API - Record Sets Create/Update | https://learn.microsoft.com/en-us/rest/api/dns/record-sets/create-or-update?view=rest-dns-2018-05-01 | HIGH |
| Azure DNS REST API - Record Sets Get | https://learn.microsoft.com/en-us/rest/api/dns/record-sets/get?view=rest-dns-2018-05-01 | HIGH |
| Microsoft Entra OAuth2 Client Credentials Flow | https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow | HIGH |
| Azure DNS Service Limits | https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-dns-limits | HIGH |
| Azure RBAC - DNS Zone Contributor | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/networking#dns-zone-contributor | HIGH |
| IP services | Live getest op 2026-03-30 (icanhazip, checkip.amazonaws, ipify, ifconfig.me, ipinfo.io) | HIGH |
