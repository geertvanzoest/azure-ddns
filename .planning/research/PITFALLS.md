# Domain Pitfalls

**Domain:** Azure DNS dynamic updater (bash/curl op Raspberry Pi)
**Onderzocht:** 2026-03-30
**Bronnen:** Microsoft Learn (Azure DNS REST API, OAuth2 client credentials flow, ARM throttling, DNS zone protection, Azure subscription limits), directe tests IP-detectieservices

## Kritieke Pitfalls

Fouten die leiden tot een niet-werkend script, beveiligingsrisico's, of silent failures.

### Pitfall 1: OAuth2 token niet opnieuw ophalen -- hardcoded of gecached token verloopt

**Wat gaat mis:** Het Azure OAuth2 access token (`expires_in: 3599`, dus ~1 uur) wordt eenmalig opgehaald en hergebruikt, of het script faalt omdat het een verlopen token stuurt naar de Azure REST API. Bij de client credentials flow worden GEEN refresh tokens uitgegeven -- je moet een geheel nieuw access token aanvragen.

**Waarom het gebeurt:** Ontwikkelaars cachen het token in een bestand om API-calls te besparen, maar controleren niet of het verlopen is. Of het script wordt omgebouwd van single-run naar daemon zonder token-refresh logica.

**Gevolgen:** Azure retourneert `401 Unauthorized`. Het DNS-record wordt niet bijgewerkt. Als er geen error handling is, loopt het script gewoon door alsof alles goed is (silent failure).

**Preventie:**
- Voor een cron single-run script: haal ALTIJD een vers token op bij elke run. Een token-aanvraag kost ~200ms en het Entra ID token-endpoint heeft ruime limieten. Er is geen reden om te cachen bij een cron-interval van 5+ minuten.
- Controleer altijd de HTTP status code van de token-response (200 = OK, alles anders = fout).
- Parse `access_token` uit de JSON-response en valideer dat het niet leeg is.

**Detectie:** Het script logt geen succesvolle DNS-updates meer. `curl` naar Azure retourneert HTTP 401.

**Fase:** Fase 1 (core implementatie) -- direct goed inbouwen.

**Confidence:** HIGH -- gebaseerd op officieel Microsoft OAuth2 client credentials flow documentatie: "refresh tokens will never be granted with this flow".

---

### Pitfall 2: IP-detectieservice retourneert garbage en script stuurt het door naar Azure

**Wat gaat mis:** De externe IP-service (ifconfig.me, ipify.org, icanhazip.com) retourneert een foutpagina (HTML), een lege response, een captcha, of het IP van een tussenliggende proxy. Het script valideert de output niet en stuurt dit als A-record waarde naar Azure DNS.

**Waarom het gebeurt:**
- De service is tijdelijk down en retourneert een HTML-foutpagina (bijv. Cloudflare 503).
- De service rate-limit je en retourneert `429 Too Many Requests` met een HTML body.
- Een captive portal of transparante proxy onderschept het request.
- De service verandert zijn response-formaat (bijv. van plain text naar JSON).

**Gevolgen:** Het DNS A-record wordt bijgewerkt naar een ongeldig IP-adres. Alle services die afhankelijk zijn van dit DNS-record worden onbereikbaar. In het ergste geval wordt het gecorrigeerde IP pas na TTL-verloop weer geldig.

**Preventie:**
- Valideer de response als een geldig IPv4-adres met een regex: `^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$`
- Controleer de HTTP status code (alleen 200 accepteren).
- Zet een `--max-time` timeout op de curl-call (bijv. 10 seconden).
- Vergelijk het gedetecteerde IP met het huidige DNS-record: als ze gelijk zijn, skip de update.
- Overweeg een fallback naar een tweede IP-service als de eerste faalt.

**Detectie:** Het A-record bevat plotseling een vreemd IP of is onbereikbaar. De log toont onverwachte waarden.

**Fase:** Fase 1 (core implementatie) -- IP-validatie is fundamenteel.

**Confidence:** HIGH -- directe tests bevestigen dat services plain-text IPv4 retourneren bij succes, maar geen garantie bieden bij fouten.

---

### Pitfall 3: Service Principal secret verloopt ongemerkt

**Wat gaat mis:** De client secret van de Azure Service Principal heeft een einddatum (standaard 6 maanden, maximaal 2 jaar bij aanmaak via de portal). Na verloop retourneert het Entra ID token-endpoint een fout en het script kan niet meer authenticeren.

**Waarom het gebeurt:** Bij het aanmaken van de Service Principal wordt een verloopdatum ingesteld. Niemand bewaakt wanneer het secret verloopt. Het script draait jarenlang totdat het plotseling stopt.

**Gevolgen:** Volledige uitval van de DDNS-functionaliteit. Het script kan geen token meer ophalen. Het DNS-record wordt niet meer bijgewerkt.

**Preventie:**
- Documenteer de verloopdatum van het secret in de projectdocumentatie.
- Zet een herinnering in de agenda voor 2 weken voor het verloop.
- Gebruik een langere geldigheidsduur (maximaal 24 maanden via portal).
- Het script moet de fout van het token-endpoint duidelijk loggen zodat het opvalt.
- Overweeg certificaat-authenticatie (langere geldigheid, veiliger, maar complexer in bash).

**Detectie:** Token-aanvraag retourneert `AADSTS7000215: Invalid client secret provided` of vergelijkbare foutcode. Log monitoring pikt dit op.

**Fase:** Fase 2 (hardening/operations) -- reminder-mechanisme, maar de error logging moet in Fase 1.

**Confidence:** HIGH -- officieel gedocumenteerd op Microsoft Learn, Service Principal credential management.

---

### Pitfall 4: Cron-omgeving mist PATH en environment variables

**Wat gaat mis:** Het script werkt perfect als je het handmatig draait, maar faalt in cron. Cron draait met een minimale omgeving: `PATH=/usr/bin:/bin`, geen geladen shell-profile, en geen environment variables die je in `.bashrc` of `.profile` hebt gezet.

**Waarom het gebeurt:** Cron erft niet de gebruikersomgeving. `curl`, `jq`, of andere tools staan mogelijk in `/usr/local/bin` wat niet in cron's PATH zit. Environment variables zoals `AZURE_TENANT_ID` zijn niet beschikbaar tenzij expliciet meegegeven.

**Gevolgen:** Het script faalt met "command not found" of lege variabelen. Zonder `set -e` loopt het script door met lege waarden, wat leidt tot incorrecte API-calls.

**Preventie:**
- Gebruik volledige paden naar binaries: `/usr/bin/curl`, `/usr/bin/jq`.
- OF definieer PATH bovenaan het script: `export PATH="/usr/local/bin:/usr/bin:/bin"`
- Laad environment variables vanuit een `.env`-bestand of definieer ze in de crontab zelf.
- Crontab-syntax voor env vars: `AZURE_TENANT_ID=xxx` boven de cronjob regel.
- Of gebruik een wrapper: `* * * * * /bin/bash -l -c '/path/to/script.sh'` (let op: `-l` laadt login profile, maar dat brengt eigen risico's mee).
- Test het script expliciet vanuit een schone omgeving: `env -i HOME=$HOME /bin/bash /path/to/script.sh`

**Detectie:** Cron stuurt foutmeldingen naar de lokale mailbox van de gebruiker (`/var/mail/pi`). Veel mensen configureren dit niet of lezen het nooit.

**Fase:** Fase 1 (core implementatie) -- direct ontwerpen voor cron-compatibiliteit.

**Confidence:** HIGH -- universeel bekende cron-pitfall, goed gedocumenteerd.

---

### Pitfall 5: Geen error handling -- set -e ontbreekt en fouten worden genegeerd

**Wat gaat mis:** Het bash-script heeft geen `set -e` (of `set -euo pipefail`) en controleert geen exit codes. Een falende `curl`-call (netwerk down, DNS-fout, timeout) leidt ertoe dat het script doorgaat met lege of incorrecte variabelen.

**Waarom het gebeurt:** Bash is standaard tolerant: een falend commando stopt het script niet. Ontwikkelaars testen op het "happy path" en vergeten de faalgevallen.

**Gevolgen:**
- Een lege `$IP`-variabele wordt naar Azure gestuurd, wat een API-fout of corrupt record oplevert.
- Een lege `$TOKEN`-variabele wordt als Bearer token meegestuurd, wat een 401 oplevert.
- Met `set -e` ZONDER goede `trap` kun je het omgekeerde probleem krijgen: het script stopt stil zonder duidelijke foutmelding.

**Preventie:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# set -e: stop bij eerste fout
# set -u: fout bij ongedefinieerde variabelen
# set -o pipefail: pipe retourneert de exit code van het eerste falende commando

# Plus: controleer elke kritieke stap expliciet
token_response=$(curl --silent --fail --max-time 10 ...) || {
    echo "FOUT: Token ophalen mislukt" >&2
    exit 1
}
```
- Gebruik `curl --fail` (retourneert exit code > 0 bij HTTP 4xx/5xx).
- Gebruik `curl -w "%{http_code}"` om de HTTP status te loggen.
- Gebruik een `trap` voor cleanup en foutmelding bij onverwachte exits.

**Detectie:** Het script meldt "succes" terwijl het record niet is bijgewerkt. Pas merkbaar als de dienst onbereikbaar wordt.

**Fase:** Fase 1 (core implementatie) -- de allereerste regel van het script.

**Confidence:** HIGH -- fundamentele bash best practice.

## Matige Pitfalls

### Pitfall 6: DNS TTL te laag of te hoog ingesteld

**Wat gaat mis:** Een te lage TTL (bijv. 60 seconden) veroorzaakt meer DNS-queries naar Azure DNS (kost geld en verhoogt load). Een te hoge TTL (bijv. 86400 seconden / 24 uur) betekent dat na een IP-wijziging cached resolvers het oude IP nog urenlang serveren.

**Preventie:**
- Kies een TTL die past bij het verwachte IP-wijzigingsinterval. Voor een thuisnetwerk met stabiel IP: 300-3600 seconden is redelijk.
- Het script moet de TTL als configureerbare variabele aanbieden, niet hardcoden.
- Azure DNS propageert wijzigingen naar hun nameservers binnen 60 seconden (officieel gedocumenteerd), maar downstream resolvers cachen tot de vorige TTL verloopt.

**Detectie:** Onverwacht hoge Azure DNS-kosten (te lage TTL) of langdurige onbereikbaarheid na IP-wijziging (te hoge TTL).

**Fase:** Fase 1 (configuratie) -- TTL als configureerbare environment variable.

**Confidence:** HIGH -- officieel in Azure DNS FAQ: "DNS caching by DNS clients and DNS recursive resolvers outside of Azure DNS can affect timing. The cache duration is dependent on the Time-To-Live (TTL) property."

---

### Pitfall 7: Service Principal met te brede rechten (DNS Zone Contributor op resource group)

**Wat gaat mis:** De Service Principal krijgt de `DNS Zone Contributor` rol op de hele resource group in plaats van op de specifieke DNS zone of zelfs het specifieke record set. Dit geeft het script rechten om ALLE zones en records in die resource group te beheren.

**Waarom het gebeurt:** De documentatie laat het meest eenvoudige voorbeeld zien (resource group scope). Veel tutorials kopieen dit zonder na te denken over least privilege.

**Gevolgen:** Als de credentials lekken (bijv. via een git push of compromised Pi), kan een aanvaller alle DNS-records in de resource group manipuleren, niet alleen het ene A-record.

**Preventie:**
- Scope de `DNS Zone Contributor` rol naar de specifieke DNS zone:
  ```
  /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}
  ```
- Of, nog beter, maak een custom role die alleen `Microsoft.Network/dnsZones/A/write` en `Microsoft.Network/dnsZones/A/read` toestaat op die specifieke zone. Azure RBAC ondersteunt zelfs record-set level permissies (officieel gedocumenteerd).
- Bewaar credentials NOOIT in het script zelf of in git. Gebruik environment variables of een `.env`-bestand met restrictieve file permissions (`chmod 600`).

**Detectie:** Audit logs in Azure tonen onverwachte DNS-wijzigingen buiten het verwachte record.

**Fase:** Fase 1 (setup documentatie) -- correct instellen bij eerste configuratie.

**Confidence:** HIGH -- officieel gedocumenteerd op Microsoft Learn: "Zone level Azure RBAC" en "Record set level Azure RBAC".

---

### Pitfall 8: Azure API tijdelijk onbeschikbaar -- geen retry of graceful failure

**Wat gaat mis:** De Azure REST API (management.azure.com) of het Entra ID token-endpoint (login.microsoftonline.com) is tijdelijk onbereikbaar. Het script faalt en het DNS-record wordt niet bijgewerkt.

**Waarom het gebeurt:** Netwerk-glitch, Azure onderhoud, of ARM throttling (hoewel de limieten ruim zijn: 200 writes/min per zone, 200 bucket size voor subscription writes met 10/sec refill).

**Gevolgen:** Eenmalige uitval is geen probleem als cron het script binnen 5 minuten opnieuw draait. Maar als de fout persistent is (bijv. verkeerde endpoint URL, verlopen secret), blijft het falen zonder dat iemand het merkt.

**Preventie:**
- Log duidelijk WELKE stap faalde (token ophalen vs. DNS update) met de HTTP status code en response body.
- Voeg een eenvoudige retry toe (1x, na 5 seconden) voor transiente fouten (HTTP 429, 500, 502, 503, 504).
- Vertrouw verder op cron voor herhaalde uitvoering -- als het 5 minuten later opnieuw draait, lost een transiente fout zichzelf op.
- Overweeg een "last success" timestamp-bestand dat een extern monitoring-systeem kan bewaken.

**Detectie:** De log toont herhaalde fouten bij dezelfde stap. Het "last success" bestand is ouder dan verwacht.

**Fase:** Fase 2 (hardening) -- basis error logging in Fase 1, retry logica in Fase 2.

**Confidence:** HIGH -- ARM throttling limieten officieel gedocumenteerd (token bucket algorithm, 200 writes/min per zone).

---

### Pitfall 9: Onnodige DNS-updates wanneer IP niet is gewijzigd

**Wat gaat mis:** Het script stuurt elke run een PUT naar Azure DNS, ook als het IP-adres niet is veranderd. Dit is verspilling van API-calls en kan bij veel runs bijdragen aan throttling.

**Waarom het gebeurt:** Het script vergelijkt het huidige IP niet met het bestaande record voordat het een update stuurt.

**Gevolgen:** Geen directe schade (Azure's PUT is idempotent voor record sets), maar onnodig API-gebruik, meer logging noise, en bij agressieve cron-intervallen (elke minuut) onnodige load.

**Preventie:**
- Haal eerst het huidige A-record op via GET en vergelijk met het gedetecteerde IP.
- OF: bewaar het laatst geschreven IP lokaal in een bestandje en vergelijk daartegen (bespaart een API-call).
- Log alleen bij daadwerkelijke wijzigingen: "IP gewijzigd van X.X.X.X naar Y.Y.Y.Y, DNS bijgewerkt."
- Skip de Azure API-call als het IP niet is veranderd.

**Detectie:** De log toont elke run een "update" terwijl het IP al dagen hetzelfde is.

**Fase:** Fase 1 (core logica) -- vergelijking is triviaal en essentieel voor goede logging.

**Confidence:** HIGH -- standaard DDNS-patroon.

---

### Pitfall 10: Bash quoting-fouten in variabelen met speciale tekens

**Wat gaat mis:** Variabelen worden niet juist gequote in bash, waardoor waarden met spaties, speciale tekens, of lege waarden onverwacht gedrag veroorzaken. Vooral relevant voor JSON-constructie in curl-calls.

**Waarom het gebeurt:** Bash split unquoted variabelen op whitespace (word splitting) en voert glob expansion uit. Bij JSON-constructie met string concatenatie gaat dit snel fout.

**Gevolgen:** Malformed JSON naar Azure API, wat een `400 Bad Request` oplevert. Of erger: command injection als er user-controlled input in variabelen terechtkomt.

**Preventie:**
- Quote ALTIJD variabelen: `"$VAR"` in plaats van `$VAR`.
- Gebruik `jq` voor JSON-constructie in plaats van string concatenatie:
  ```bash
  json_body=$(jq -n \
    --arg ip "$CURRENT_IP" \
    --argjson ttl "$DNS_TTL" \
    '{properties: {TTL: $ttl, ARecords: [{ipv4Address: $ip}]}}')
  ```
- Gebruik `shellcheck` (statische analyse) op het script om quoting-fouten te detecteren.
- Gebruik `set -u` om ongedefinieerde variabelen te vangen.

**Detectie:** `shellcheck ns4j.sh` toont waarschuwingen. Azure API retourneert `400 Bad Request` met "invalid JSON".

**Fase:** Fase 1 (core implementatie) -- correcte quoting en jq-gebruik vanaf het begin.

**Confidence:** HIGH -- fundamentele bash best practice.

## Kleine Pitfalls

### Pitfall 11: IP-detectieservice rate limiting bij frequent cron-interval

**Wat gaat mis:** Bij een cron-interval van elke minuut (of korter) kan de IP-detectieservice het IP rate-limiten en een `429 Too Many Requests` of een leeg antwoord retourneren.

**Preventie:**
- Gebruik een cron-interval van minimaal 5 minuten. IP-adressen van thuisnetwerken wijzigen zelden vaker.
- Implementeer fallback naar een alternatieve service bij een niet-200 response.
- Gebruikte services en hun gedrag (getest 2026-03-30):
  - `ifconfig.me` -- retourneert plain text IPv4, geen bekende rate limit bij normaal gebruik
  - `api.ipify.org` -- retourneert plain text IPv4, snelle response (~120ms)
  - `icanhazip.com` -- retourneert plain text IPv4 + newline, snelle response (~45ms)
- Stel een `User-Agent` header in op curl-requests: sommige services blokkeren requests zonder User-Agent.

**Fase:** Fase 1 (configuratie) -- redelijk cron-interval documenteren.

**Confidence:** MEDIUM -- rate limits van deze services zijn niet officieel gedocumenteerd, maar normaal gebruik (5 min interval) levert geen problemen op.

---

### Pitfall 12: jq ontbreekt op het systeem of is een andere versie

**Wat gaat mis:** Het script vereist `jq` voor JSON-parsing, maar `jq` is niet standaard geinstalleerd op alle Raspberry Pi OS images. Of een oudere versie mist bepaalde features.

**Preventie:**
- Controleer aan het begin van het script of `jq` beschikbaar is:
  ```bash
  command -v jq >/dev/null 2>&1 || { echo "jq is vereist maar niet geinstalleerd" >&2; exit 1; }
  ```
- Documenteer de installatie: `sudo apt-get install -y jq`
- Alternatief: gebruik `grep`/`sed` voor eenvoudige JSON-parsing, maar dit is fragiel en niet aanbevolen.

**Fase:** Fase 1 (dependency check) -- preconditie-check bovenaan het script.

**Confidence:** HIGH -- `jq` staat vermeld als dependency in PROJECT.md maar is niet standaard op alle systemen.

---

### Pitfall 13: Azure REST API versie niet gepind

**Wat gaat mis:** De Azure DNS REST API vereist een `api-version` query parameter. Als deze ontbreekt of een onbekende versie bevat, retourneert de API een fout. Als een toekomstige API-versie breaking changes heeft, kan het script breken.

**Preventie:**
- Pin de API-versie: `?api-version=2018-05-01` (de huidige stabiele versie voor Azure DNS).
- Hardcode dit als constante in het script, niet als configureerbare variabele.
- De huidige API URL format: `PUT https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/dnsZones/{zone}/A/{record}?api-version=2018-05-01`

**Fase:** Fase 1 (core implementatie).

**Confidence:** HIGH -- officieel gedocumenteerd, API versie 2018-05-01 is de huidige stabiele versie.

---

### Pitfall 14: Scope van het OAuth2 token verkeerd ingesteld

**Wat gaat mis:** De `scope` parameter bij het token-request moet `https://management.azure.com/.default` zijn voor Azure Resource Manager. Een verkeerde scope (bijv. `https://graph.microsoft.com/.default`) levert een token op dat niet werkt voor DNS-management.

**Preventie:**
- Gebruik exact: `scope=https%3A%2F%2Fmanagement.azure.com%2F.default` in het token-request.
- Dit is de Resource Manager scope, niet de Graph API scope.
- Hardcode dit als constante.

**Fase:** Fase 1 (core implementatie).

**Confidence:** HIGH -- officieel gedocumenteerd in OAuth2 client credentials flow documentatie.

---

### Pitfall 15: Response body van curl niet opvangen bij fouten

**Wat gaat mis:** Bij een HTTP-fout bevat de response body waardevolle foutinformatie (bijv. "Invalid client secret provided" of "AuthorizationFailed"). Het script logt alleen de exit code van curl, niet de body.

**Preventie:**
- Vang altijd de response body EN de HTTP status code op:
  ```bash
  response=$(curl --silent --write-out "\nHTTP_STATUS:%{http_code}" ...)
  http_status=$(echo "$response" | tail -1 | sed 's/HTTP_STATUS://')
  body=$(echo "$response" | sed '$d')
  ```
- Log de body bij niet-200 responses naar stderr.

**Fase:** Fase 1 (error handling).

**Confidence:** HIGH -- standaard curl-patroon.

## Fase-specifieke waarschuwingen

| Fase | Waarschijnlijke Pitfall | Mitigatie |
|------|------------------------|-----------|
| Fase 1: Core script | IP-validatie vergeten (Pitfall 2) | Regex validatie direct na IP-ophalen |
| Fase 1: Core script | set -euo pipefail ontbreekt (Pitfall 5) | Eerste regel van het script |
| Fase 1: Core script | Cron PATH-problemen (Pitfall 4) | Volledige paden of PATH-export |
| Fase 1: Core script | Verkeerde OAuth2 scope (Pitfall 14) | management.azure.com/.default |
| Fase 1: Core script | JSON-constructie via string concat (Pitfall 10) | jq gebruiken |
| Fase 1: Core script | Geen vergelijking huidig vs nieuw IP (Pitfall 9) | GET-then-PUT patroon |
| Fase 1: Setup docs | Te brede SP-rechten (Pitfall 7) | Zone-level RBAC scope |
| Fase 2: Hardening | Secret verloopt ongemerkt (Pitfall 3) | Monitoring + reminder |
| Fase 2: Hardening | Geen retry bij transiente fouten (Pitfall 8) | Eenvoudige retry met backoff |
| Fase 2: Hardening | IP-service rate limiting (Pitfall 11) | Fallback-service configureren |

## Bronnen

- Microsoft Learn -- Azure DNS REST API Record Sets Create Or Update: https://learn.microsoft.com/en-us/rest/api/dns/record-sets/create-or-update
- Microsoft Learn -- OAuth 2.0 client credentials flow: https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow
- Microsoft Learn -- Protecting DNS Zones and Records (RBAC): https://learn.microsoft.com/en-us/azure/dns/dns-protect-zones-recordsets
- Microsoft Learn -- ARM request limits and throttling: https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/request-limits-and-throttling
- Microsoft Learn -- Azure subscription service limits (DNS): https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-dns-limits
- Microsoft Learn -- Service Principal credential management: https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal
- Microsoft Learn -- Azure DNS FAQ (TTL, propagatie): https://learn.microsoft.com/en-us/azure/dns/dns-faq
- Directe tests IP-detectieservices (ifconfig.me, api.ipify.org, icanhazip.com): 2026-03-30
