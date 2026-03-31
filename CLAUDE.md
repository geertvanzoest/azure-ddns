<!-- GSD:project-start source:PROJECT.md -->
## Project

**ns4j — Azure DNS Dynamic Updater**

Een lightweight bash script dat als DDNS-client werkt voor Azure DNS. Het detecteert het publieke IP-adres van het netwerk via een externe service en update een A-record in Azure DNS via curl. Ontworpen om als cron job op een Raspberry Pi te draaien met zero dependencies buiten standaard systeemtools.

**Core Value:** Het Azure DNS A-record is altijd actueel met het huidige publieke IP-adres van het thuisnetwerk.

### Constraints

- **Runtime**: bash + curl (standaard op elke Pi)
- **Platform**: Raspberry Pi (ARM, beperkt geheugen/CPU)
- **Dependencies**: Zero — alleen bash, curl, en jq (voor JSON parsing)
- **Auth**: Azure Service Principal (client ID, client secret, tenant ID)
- **Netwerk**: Moet uitgaand HTTPS kunnen bereiken (IP-service + Azure REST API)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Runtime & Shell
| Technology | Version | Doel | Waarom |
|------------|---------|------|--------|
| bash | >= 4.x | Script interpreter | Standaard op Raspberry Pi OS; POSIX-compatible, heeft arrays en string manipulation nodig |
| curl | >= 7.68 | HTTP client | Standaard op Pi OS; ondersteunt HTTPS, custom headers, POST bodies -- alles wat nodig is voor OAuth2 + REST API |
| jq | >= 1.6 | JSON parsing | Niet standaard geinstalleerd maar beschikbaar via `apt install jq`; noodzakelijk voor betrouwbare JSON parsing van OAuth2 tokens en API responses |
### Azure DNS REST API
| Endpoint | API Version | Doel | Waarom |
|----------|-------------|------|--------|
| `PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}/A/{record}` | `2018-05-01` | A-record aanmaken/updaten | Dit is de **huidige stabiele API versie** voor Azure DNS. Er bestaat geen nieuwere GA release -- 2023-07-01-preview valt terug naar 2018-05-01. Bewezen stabiel sinds mei 2018. |
| `GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}/A/{record}` | `2018-05-01` | Huidig A-record ophalen | Nodig om te checken of IP daadwerkelijk gewijzigd is, voordat een onnodige PUT wordt gedaan |
| Operatie | Limiet |
|----------|--------|
| Create/PUT | 40/min |
| GET | 1000/min |
| List | 60/min |
### Azure OAuth2 (Service Principal Authentication)
| Component | Waarde | Doel |
|-----------|--------|------|
| Token endpoint | `https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token` | OAuth2 token ophalen |
| Grant type | `client_credentials` | Service-to-service auth zonder gebruikersinteractie |
| Scope | `https://management.azure.com/.default` | Toegang tot Azure Resource Management API |
| Content-Type | `application/x-www-form-urlencoded` | Vereist formaat voor token request |
### Publiek IP Detectie
| Service | URL | Eigenaar | Betrouwbaarheid | Aanbeveling |
|---------|-----|----------|-----------------|-------------|
| **icanhazip.com** | `https://icanhazip.com` | Cloudflare | Zeer hoog -- Anycast netwerk, Cloudflare backbone | **Primair** -- eigendom van Cloudflare, dus dezelfde infra als 1.1.1.1 DNS |
| **checkip.amazonaws.com** | `https://checkip.amazonaws.com` | Amazon AWS | Zeer hoog -- AWS global infra | **Fallback 1** -- AWS-backed, geen rate limits gedocumenteerd |
| api.ipify.org | `https://api.ipify.org` | Derden (via Cloudflare) | Matig -- HEAD request gaf HTTP 520 tijdens test | **Niet gebruiken** -- instabiel, 520 errors waargenomen op 2026-03-30 |
| ifconfig.me | `https://ifconfig.me` | Derden (via Google) | Matig -- HEAD request gaf HTTP 405 | **Niet gebruiken** -- 405 op HEAD, langzamer dan alternatieven |
| ipinfo.io/ip | `https://ipinfo.io/ip` | ipinfo.io | Hoog maar rate-limited | **Niet gebruiken** -- commerciele API met rate limits voor gratis tier |
### Cron (Scheduling)
| Technology | Doel | Waarom |
|------------|------|--------|
| cron / crontab | Script periodiek uitvoeren | Standaard op elke Linux distro; simpelst mogelijke scheduler; gebruiker configureert zelf het interval |
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
# Enige dependency die niet standaard aanwezig is
# Script installeren
# Cron job instellen (als root of gebruiker)
# Environment variables instellen in crontab of /etc/environment
# NIET in het script zelf (secrets horen niet in code)
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
