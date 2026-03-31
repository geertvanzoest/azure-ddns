# Project Research Summary

**Project:** ns4j -- Azure DNS Dynamic Updater
**Domain:** Dynamic DNS client (bash script voor Azure DNS REST API)
**Researched:** 2026-03-30
**Confidence:** HIGH

## Executive Summary

ns4j is een single-purpose bash script dat als dynamic DNS client fungeert voor Azure DNS. Het probleem is simpel: een Raspberry Pi op een thuisnetwerk krijgt periodiek een nieuw publiek IP-adres van de ISP, en dat IP moet bijgehouden worden in een Azure DNS A-record. Bestaande DDNS-tools (ddclient, inadyn) zijn volwassen maar generiek -- ze ondersteunen 30+ providers en hebben complexe configuratiemodellen. Voor ns4j geldt het tegenovergestelde: precies één provider (Azure DNS REST API), precies één record, minimale dependencies. De juiste aanpak is een klein bash script met curl en jq, aangestuurd via cron.

De technische aanpak is volledig uitgekristalliseerd: bash + curl + jq op Raspberry Pi OS, Azure OAuth2 client credentials flow voor authenticatie, de Azure DNS REST API 2018-05-01 voor record management, en icanhazip.com (Cloudflare-backed) als primaire IP-detectieservice. Het script volgt een lineair pipeline-model: valideer configuratie, haal token op, detecteer IP, haal huidig DNS-record op via GET, vergelijk, en doe alleen een PUT als het IP daadwerkelijk gewijzigd is. Dit GET-then-PUT patroon is architectureel superieur aan lokale IP-caching, omdat Azure DNS altijd de authoritative bron is.

Het grootste risico is niet technisch maar operationeel: de Azure Service Principal client secret verloopt na maximaal 2 jaar, en zonder proactieve monitoring stopt het script dan stilzwijgend. De andere kritieke risico's zijn typische bash-valkuilen: geen `set -euo pipefail`, ontbrekende IP-validatie die garbage naar Azure stuurt, en PATH-problemen in de cron-omgeving. Al deze risico's zijn goed gedocumenteerd en eenvoudig te mitigeren met standaard bash best practices en goede foutafhandeling vanaf dag 1.

## Key Findings

### Recommended Stack

Het script vereist geen speciale runtime of installatie buiten `jq` (via `apt install jq`). Bash (>=4.x) en curl (>=7.68) zijn standaard beschikbaar op Raspberry Pi OS. De Azure REST API gebruikt API versie `2018-05-01` -- dit is de huidige stabiele GA versie; preview versies vallen terug naar deze versie en bieden geen meerwaarde. De OAuth2 client credentials flow via Microsoft Entra ID is de enige correcte authenticatiemethode voor een headless script -- er worden geen refresh tokens uitgegeven, dus elk cron-run vraagt een nieuw token aan (simpeler en veiliger dan token caching).

**Core technologies:**

- bash + curl: script runtime en HTTP client -- standaard op Pi OS, volstaat volledig voor 2 API calls per run
- jq 1.6+: JSON parsing -- enige externe dependency, robuust alternatief voor fragiele string-manipulatie op JSON
- Azure DNS REST API 2018-05-01: record management -- stabiele GA versie, geverifieerd via officieel Microsoft Learn
- Azure OAuth2 client credentials: authenticatie -- `https://management.azure.com/.default` scope, vers token elke run
- icanhazip.com (primair) + checkip.amazonaws.com (fallback): IP-detectie -- beide cloud-giant-backed (Cloudflare / AWS), plain text output
- cron: scheduling -- standaard Linux, simpelste oplossing, geen daemon overhead

### Expected Features

De feature-analyse is gebaseerd op vergelijking met ddclient en inadyn, gefilterd op de cron-based single-run context van ns4j.

**Must have (table stakes):**

- Publiek IP ophalen via externe service -- kernfunctie, zonder IP geen update
- IP-validatie met regex -- voorkomt dat een HTML-foutpagina als A-record wordt opgeslagen
- Azure OAuth2 token ophalen -- authenticatie is vereist voor de REST API
- Azure DNS A-record updaten via PUT -- dit IS de kernfunctie van het script
- Vergelijking met huidig DNS-record (GET-then-PUT) -- voorkomt onnodige API calls
- Configuratie via environment variables -- enig correct model voor cron-gebaseerde scripts
- Validatie van verplichte env vars bij startup -- fail-fast, voorkomt cryptische fouten halverwege
- Exit codes (0/69/78 conform sysexits.h) -- cron en monitoring verwachten gestandaardiseerde codes
- Basis logging naar stdout/stderr met timestamp -- zonder dit is debugging onmogelijk
- HTTP response code controle na elke API call -- weten of de update werkelijk slaagde

**Should have (robuustheid):**

- Fallback IP-service (checkip.amazonaws.com) -- verhoogt beschikbaarheid bij service-uitval
- Lock file met flock -- voorkomt race conditions bij korte cron-intervallen of trage netwerken
- TTL-configuratie via `DNS_TTL` env var (default 300s) -- DDNS-specifieke behoefte, configureerbaar
- Force update flag (`--force`) -- debugging tool: cache negeren, altijd updaten
- Verbose modus (`VERBOSE=1`) -- troubleshooting zonder code te lezen
- jq dependency check bij startup -- duidelijke foutmelding als niet geinstalleerd

**Defer (v2+):**

- Token caching naar bestand -- optimalisatie, pas zinvol bij <5 min cron-interval; voegt complexiteit toe
- Retry logica -- cron herhaalt toch; 1 retry is luxe, niet kritisch
- Dry-run modus (`--dry-run`) -- handig maar niet noodzakelijk voor eerste release
- Versie-informatie (`--version`) -- triviaal toe te voegen wanneer nodig

**Bewust buiten scope (anti-features):**
Daemon-modus, meerdere records/zones tegelijk, IPv6/AAAA records, config-bestand parsing, Docker, push-notificaties, plugin-systeem voor providers.

### Architecture Approach

Het script volgt een strikt lineair pipeline-model zonder parallelle uitvoering of achtergrondprocessen. De volgorde is deterministisch: validate_config -> get_access_token -> get_public_ip -> get_dns_record -> vergelijk -> (optioneel) update_dns -> exit. Elke functie heeft een enkele verantwoordelijkheid en communiceert via return codes en stdout. De authoritative bron voor IP-vergelijking is altijd Azure DNS zelf via een GET-request -- nooit een lokaal cache-bestand dat kan desynchroniseren.

**Major components:**

1. `validate_config` -- fail-fast check van alle vereiste env vars, exit 78 (EX_CONFIG) bij ontbrekende vars
2. `get_access_token` -- OAuth2 client credentials POST naar Entra ID, retourneert Bearer token string
3. `get_public_ip` -- curl naar icanhazip.com met fallback, IPv4-regex validatie, retourneert clean IP string
4. `get_dns_record` -- Azure DNS REST API GET, retourneert huidig A-record IP via jq parsing
5. `update_dns` -- Azure DNS REST API PUT met jq-geconstrueerde JSON payload, accepteert 200 of 201
6. `log` -- gestandaardiseerde timestamp+level logging, errors naar stderr, info naar stdout
7. `main` -- lineaire orkestratie met expliciete error handling per stap, exit 69 (EX_UNAVAILABLE) bij API-fouten

**Scriptstructuur:** `set -euo pipefail` + `trap ERR` als vangnet, constanten voor `API_VERSION` en `AZURE_SCOPE`, functies in dependency-volgorde, `main "$@"` als enige entry point.

### Critical Pitfalls

1. **IP-validatie vergeten** -- de IP-service kan HTML of garbage retourneren bij downtime; altijd regex-valideren direct na ophalen; een ongeldig adres in Azure DNS maakt alle afhankelijke services onbereikbaar tot handmatige correctie
2. **`set -euo pipefail` ontbreekt** -- bash continueert standaard bij fouten; lege tokens en lege IP's worden doorgegeven, Azure retourneert 401/400, script meldt stilzwijgend "succes"; `set -euo pipefail` + `trap ERR` is de eerste regel van het script
3. **Cron PATH en environment** -- cron draait met minimale `PATH=/usr/bin:/bin` zonder shell-profile; alle env vars (AZURE_TENANT_ID etc.) en tools (`jq`, `curl`) moeten expliciet beschikbaar zijn; test altijd met `env -i HOME=$HOME /bin/bash script.sh`
4. **Service Principal secret verloopt ongemerkt** -- standaard vervalt het secret na 6-24 maanden; Entra ID retourneert dan `AADSTS7000215`; script stopt stilzwijgend met updaten; documenteer de verloopdatum en plan een expliciete reminder
5. **Te brede RBAC scope** -- `DNS Zone Contributor` op resource group geeft schrijfrechten op ALLE zones; scope altijd op de specifieke DNS zone of gebruik een custom role met alleen A-record read/write; bij credential-lek is de blast radius anders enorm

## Implications for Roadmap

Op basis van de gecombineerde research suggereert de dependency-keten een tweeledige aanpak: eerst een werkend kern-script met alle table stakes, dan hardening en operationele robuustheid.

### Phase 1: Werkend kern-script

**Rationale:** Alle table stakes hebben een strikte dependency-volgorde die samenvalt met de architectuurcomponenten. De bouwvolgorde is gedicteerd door de pipeline: eerst fundament (log, validate), dan auth, dan lees-operaties, dan schrijf-operatie. Dit is ook de testbare volgorde -- elke stap is afzonderlijk verifieerbaar voor de volgende wordt gebouwd.

**Delivers:** Een volledig functioneel bash script dat elke cron-run het publieke IP detecteert, vergelijkt met het Azure DNS A-record, en bijwerkt als het IP daadwerkelijk gewijzigd is.

**Addresses:** Alle 10 table stakes features uit FEATURES.md, inclusief RBAC-documentatie (zone-scoped) en jq dependency check.

**Avoids:** Pitfall 2 (IP-validatie), 4 (cron PATH), 5 (set -euo pipefail), 9 (GET-then-PUT patroon), 10 (jq voor JSON constructie i.p.v. string concatenatie), 12 (jq dependency check), 13 (API versie pinnen als constante), 14 (juiste OAuth2 scope).

Bouwvolgorde binnen fase:

1. `log()` + `validate_config()` -- fundament, direct testbaar zonder externe services
2. `get_access_token()` -- Azure auth, testbaar met echte credentials in isolatie
3. `get_public_ip()` -- IP-detectie met regex-validatie, testbaar zonder Azure toegang
4. `get_dns_record()` -- Azure DNS GET, testbaar zonder schrijfrechten op het record
5. `update_dns()` + `main()` -- schrijf-operatie en orkestratie, integratietest

### Phase 2: Hardening en operationele robuustheid

**Rationale:** De "should have" features verhogen betrouwbaarheid maar zijn niet vereist voor basisfunctionaliteit. Ze bouwen onafhankelijk bovenop het werkende kern-script. Lock file en fallback IP-service zijn het meest waardevol in productie; force flag en verbose modus zijn debugging tools.

**Delivers:** Een productieklaar script met lock file, fallback IP-service, TTL-configuratie, `--force` flag, `VERBOSE=1` modus, en duidelijke logging van AADSTS-foutcodes zodat secret-verloop direct zichtbaar is.

**Implements:** `flock`-gebaseerde lock file, fallback naar checkip.amazonaws.com, `DNS_TTL` env var met default 300, `--force` / `VERBOSE` flags via `getopts`.

**Avoids:** Pitfall 3 (secret verloop -- logging van AADSTS-codes), 6 (TTL als env var), 7 (RBAC scope documentatie), 8 (eenvoudige retry), 11 (fallback IP-service).

### Phase Ordering Rationale

- Phase 1 moet volledig af zijn voor Phase 2 -- je kunt geen lock file of fallback toevoegen aan een script dat nog niet werkt
- De GET-then-PUT architectuur (geen lokale IP-cache) is een Phase 1 beslissing die de architectuur permanent bepaalt; het vereenvoudigt Phase 2 omdat er geen cache-invalidatie of synchronisatie-logica nodig is
- RBAC-setup (Pitfall 7) is geen code maar documentatie; het hoort in Phase 1 omdat een werkend script met te brede rechten een beveiligingsrisico is vanaf dag 1
- Token caching is bewust uitgesteld naar v2+; het voegt file locking, expiry checking, en permissiebeheer toe -- precies de complexiteit die Pitfall 1 (verlopen tokens) vergroot
- De twee fasen zijn kleine, afgebakende deliverables; het script is ~80-120 regels totaal, dus dit is geen zware structurering maar eerder "core first, polish second"

### Research Flags

Phases met standaard gedocumenteerde patronen (geen aanvullend onderzoek nodig):

- **Phase 1:** Alle API-eindpunten, OAuth2 flow, request/response structuren, en bash-patronen zijn volledig uitgewerkt in STACK.md en ARCHITECTURE.md. Code-voorbeelden zijn direct bruikbaar. Geen research-phase nodig.
- **Phase 2:** Lock files (flock), optionele flags (getopts), en verbosity patterns zijn standaard bash. checkip.amazonaws.com is live getest. Geen research-phase nodig.

Geen enkele fase heeft aanvullend onderzoek nodig -- de research is volledig gebaseerd op officieel geverifieerde Microsoft-documentatie en directe service-tests.

## Confidence Assessment

| Area | Confidence | Notes |
| --- | --- | --- |
| Stack | HIGH | Alle API-eindpunten en versies geverifieerd via officieel Microsoft Learn; IP-services live getest op 2026-03-30; icanhazip.com eigendom bevestigd (Cloudflare) |
| Features | HIGH | Gebaseerd op vergelijking met ddclient en inadyn ecosysteem plus Azure DNS API; anti-features bewust en gemotiveerd gedocumenteerd |
| Architecture | HIGH | Alle API-eindpunten geverifieerd; code-patronen gebaseerd op officieel geverifieerde request/response structuren; sysexits.h is BSD/POSIX standaard |
| Pitfalls | HIGH | Alle kritieke pitfalls gebaseerd op officieel gedocumenteerd Azure-gedrag (OAuth2 flow, ARM throttling, RBAC); cron PATH-pitfall is universeel bekende Linux best practice |

**Overall confidence:** HIGH

### Gaps to Address

- **Service Principal aanmaak-procedure:** De research beschrijft welke RBAC-rol en scope correct zijn, maar de stap-voor-stap procedure voor aanmaak via Azure Portal of `az` CLI is niet uitgeschreven. Dit hoort in de README/setup-documentatie -- geen blokkade voor implementatie.
- **Rate limits IP-services:** icanhazip.com en checkip.amazonaws.com hebben geen gepubliceerde rate limits. Bij het aanbevolen 5-minuten cron-interval is dit geen praktisch probleem; bij <1 minuut interval is validatie gewenst maar dat scenario wordt afgeraden.
- **Azure DNS kosten:** Niet onderzocht. Bij een enkel A-record met 5-minuten interval zijn de kosten verwaarloosbaar (Azure DNS begint bij ~$0.50/maand per zone plus $0.40 per miljoen queries).

## Sources

### Primary (HIGH confidence)

- <https://learn.microsoft.com/en-us/rest/api/dns/record-sets/create-or-update?view=rest-dns-2018-05-01> -- Azure DNS PUT endpoint, request/response structuur
- <https://learn.microsoft.com/en-us/rest/api/dns/record-sets/get?view=rest-dns-2018-05-01> -- Azure DNS GET endpoint
- <https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow> -- OAuth2 client credentials flow, bevestiging geen refresh tokens
- <https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/networking#dns-zone-contributor> -- DNS Zone Contributor RBAC rol (role ID bevestigd)
- <https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-dns-limits> -- Azure DNS rate limits (40 writes/min per zone)
- <https://learn.microsoft.com/en-us/azure/dns/dns-protect-zones-recordsets> -- Zone- en record-set level RBAC, least-privilege aanpak
- <https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/request-limits-and-throttling> -- ARM throttling (token bucket, 200 writes/min)
- <https://learn.microsoft.com/en-us/azure/dns/dns-faq> -- DNS propagatie en TTL caching gedrag
- <https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal> -- Service Principal credential management, verloopdatums
- Live tests IP-detectieservices op 2026-03-30 -- icanhazip.com (Cloudflare), checkip.amazonaws.com (AWS), api.ipify.org (instabiel), ifconfig.me (HTTP 405), ipinfo.io (rate-limited)

### Secondary (MEDIUM confidence)

- <https://deepwiki.com/ddclient/ddclient/2.4-caching-system> -- ddclient caching systeem (broncode-analyse, niet officiele docs)
- <https://deepwiki.com/ddclient/ddclient/2.3-dns-update-process> -- ddclient DNS update proces
- <https://deepwiki.com/ddclient/ddclient/2.2-ip-detection-methods> -- ddclient IP-detectiemethodes
- <https://deepwiki.com/troglobit/inadyn/2.2-configuration> -- inadyn configuratie
- <https://deepwiki.com/troglobit/inadyn/3.5-error-handling> -- inadyn error handling en recoverable/fatal error onderscheid

### Tertiary (documentatie-referentie)

- <https://ddclient.net/general.html> -- ddclient officiele configuratie-opties (referentiepunt voor feature vergelijking)
- sysexits.h exit codes (EX_OK=0, EX_UNAVAILABLE=69, EX_CONFIG=78) -- BSD/POSIX conventie

---

*Research completed: 2026-03-30*
*Ready for roadmap: yes*
