# Feature Landscape

**Domain:** Dynamic DNS client (bash script voor Azure DNS)
**Onderzocht:** 2026-03-30
**Bronnen:** ddclient docs (ddclient.net, DeepWiki), inadyn docs (GitHub, DeepWiki), Azure DNS REST API docs

## Overzicht DDNS-client ecosysteem

Gevestigde DDNS-clients (ddclient, inadyn) zijn volwassen tools met tientallen providers, meerdere IP-detectiemethodes, daemon-modi, en uitgebreide configuratieopties. ns4j is bewust geen generieke DDNS-client -- het is een single-purpose bash script voor precies een provider (Azure DNS) en een record. De featureset moet daar bij passen: robuust maar minimaal.

De onderstaande categorisering is gebaseerd op wat ddclient en inadyn bieden, gefilterd door de context van ns4j: een cron-based single-run script op een Raspberry Pi.

## Table Stakes

Features die gebruikers verwachten. Zonder deze is het script kapot of onbruikbaar.

| Feature | Waarom verwacht | Complexiteit | Opmerkingen |
|---------|-----------------|-------------|-------------|
| Publiek IP ophalen via externe service | Kernfunctie; zonder IP geen update | Laag | Eenvoudige curl naar ifconfig.me/ipify. Beide ddclient en inadyn doen dit standaard |
| IP-validatie (regex check) | Ongeldig IP naar Azure sturen corrumpeert het DNS record | Laag | Simpele regex: `^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$`. ddclient en inadyn valideren beide |
| IP-caching (vergelijk met vorige run) | Zonder caching: elke run een onnodige Azure API call + OAuth2 token request. Verspilt API quota en is trager | Laag | Cache in een bestand (bijv. `/tmp/ns4j.ip` of configureerbaar pad). ddclient heeft een uitgebreid cache-bestand; inadyn gebruikt `/var/cache/inadyn/` |
| Azure OAuth2 token verkrijgen | Authenticatie is vereist voor de Azure REST API | Middel | curl POST naar `login.microsoftonline.com/{tenant}/oauth2/v2.0/token`. Service Principal flow met client_id + client_secret |
| Azure DNS A-record updaten via REST API | Dit IS het script. Zonder dit doet het niets | Middel | PUT naar `management.azure.com/.../recordsets/A/{name}` met JSON body. API versie: `2018-05-01` |
| Configuratie via environment variables | Cron-model vereist dit; geen interactieve configuratie mogelijk | Laag | Minimaal: `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_DNS_ZONE`, `AZURE_DNS_RECORD` |
| Validatie van verplichte env vars bij startup | Script moet duidelijk falen als configuratie ontbreekt | Laag | Check en exit 1 met beschrijvende foutmelding per ontbrekende variabele |
| Exit codes (0 = ok, niet-0 = fout) | Cron en monitoring verwachten exit codes om succes/falen te detecteren | Laag | Conventie: 0=succes, 1=configuratiefout, 2=IP-detectie mislukt, 3=Azure auth mislukt, 4=DNS update mislukt |
| Basis logging naar stdout/stderr | Zonder output is debugging onmogelijk bij problemen | Laag | stdout voor succes/info, stderr voor fouten. Cron mailt stderr standaard |
| HTTP response code controle | Zonder check weet je niet of de Azure API call daadwerkelijk succesvol was | Laag | curl `-w '%{http_code}'` of `-o /dev/null -s -w`. Check op 200/201 |

## Differentiators

Features die het script robuuster maken. Niet strikt vereist, maar verhogen betrouwbaarheid.

| Feature | Waardepropositie | Complexiteit | Opmerkingen |
|---------|-------------------|-------------|-------------|
| Fallback IP-service | Als ifconfig.me down is, faalt het script niet | Laag | Probeer ifconfig.me, dan ipify.org, dan icanhazip.com. ddclient ondersteunt 20+ providers; ns4j heeft er 2-3 nodig |
| Verbose/debug modus (`-v` flag of env var) | Troubleshooting zonder code te lezen | Laag | `VERBOSE=1` of `LOG_LEVEL=debug`. ddclient heeft `--verbose` en `--debug`; inadyn heeft `-l debug` |
| Force update (`--force` flag) | Na handmatige wijzigingen of troubleshooting: cache negeren en altijd updaten | Laag | ddclient heeft `--force`, inadyn heeft `forced-update` interval. Simpele flag die IP-cache skip |
| Lock file (voorkom concurrent cron execution) | Als cron-interval kort is en een run lang duurt (netwerk traag), voorkom dubbele runs | Laag | `flock` commando of handmatige PID-file check. ddclient gebruikt een PID-file; inadyn ook |
| TTL-configuratie | Standaard TTL in Azure is 3600s. Bij DDNS wil je vaak lager (300s) voor snellere propagatie | Laag | Env var `AZURE_DNS_TTL` met default 300. Wordt meegegeven in de PUT body |
| Dry-run modus (`--dry-run`) | Testen zonder daadwerkelijk te updaten | Laag | ddclient heeft `--noexec`. Print wat zou gebeuren zonder API calls te doen |
| Retry bij tijdelijke fouten | Netwerk kan even onbereikbaar zijn; een enkele retry voorkomt vals alarm | Middel | Maximaal 1-2 retries met korte backoff (5s). Meer niet -- cron herhaalt het script toch. inadyn onderscheidt recoverable/fatal errors |
| Azure token caching | OAuth2 tokens zijn ~1 uur geldig; niet elke run een nieuw token nodig | Middel | Token + expiry opslaan in cache-bestand. Alleen nieuw token als expired. Vermindert API calls significant |
| Graceful degradatie bij jq-afwezigheid | jq is dependency; als het ontbreekt moet het script dat melden | Laag | Check `command -v jq` bij startup; duidelijke foutmelding |
| Versie-informatie (`--version`) | Standaard voor CLI tools; helpt bij bug reports | Laag | Hardcoded versienummer in het script |

## Anti-Features

Features die bewust NIET gebouwd worden. Elke toevoeging vergroot complexiteit zonder evenredige waarde.

| Anti-Feature | Waarom vermijden | Wat wel te doen |
|--------------|-----------------|----------------|
| Daemon-modus met ingebouwde scheduling | Cron doet dit al. Een bash-daemon is fragiel en moeilijk te monitoren | Cron-entry documenteren in README |
| Meerdere DNS records/zones tegelijk | Scope creep. Voegt configuratiecomplexiteit toe | Meerdere cron-entries met verschillende env vars |
| Push-notificaties (email, Slack, webhook) | ddclient heeft `--mail`, maar dit is overkill voor een cron script | Cron mailt stderr output. Gebruiker kan wrapper script toevoegen |
| Plugin-systeem voor providers | ddclient en inadyn hebben dit nodig voor 30+ providers. ns4j heeft precies 1 provider | Hardcode Azure DNS REST API |
| IPv6 / AAAA records | Niet gevraagd; verdubbelt complexiteit (andere validatie, andere API call) | Documenteer als mogelijke toekomstige uitbreiding |
| Config-bestand parsing | Env vars zijn simpeler voor cron-model. Config file vereist parser-logica | Env vars met duidelijke naamgeving |
| Automatische detectie van netwerk-interface IP | ddclient kan IP van interfaces/firewalls lezen. Overkill voor thuisnetwerk met NAT | Altijd externe IP-service gebruiken |
| Syslog integratie | inadyn logt naar syslog. Voor een cron script is stdout/stderr voldoende | Gebruiker kan output redirecten naar syslog indien gewenst |
| Interactieve setup wizard | Complexe UI-logica in bash is fragiel en moeilijk te testen | Goede README met voorbeelden |
| Docker container | Overkill voor een enkel bash script op een Pi | Documenteer directe installatie |
| Token refresh in achtergrond | Vereist daemon-achtig gedrag. Token caching is voldoende | Token caching met expiry check |
| Rate limiting / backoff bij API throttling | Azure DNS API throttling is extreem onwaarschijnlijk bij 1 record, elke N minuten | Retry (1-2x) dekt dit voldoende af |

## Feature Dependencies

```
Env var validatie ─────> [alle andere features hangen hier van af]
       |
       v
IP ophalen ──> IP-validatie ──> IP-caching (vergelijken met vorige)
                                    |
                                    v (alleen als IP gewijzigd OF --force)
                           Azure OAuth2 token ──> DNS record update
                                    |                    |
                                    v                    v
                           Token caching         HTTP response check
                                                         |
                                                         v
                                                  Exit code + logging
```

Toelichting:
- **IP-caching** is het cruciale beslispunt: als IP niet gewijzigd is, stopt het script hier (exit 0)
- **Force update** bypass het caching-beslispunt
- **Token caching** is onafhankelijk van IP-caching; een token kan hergebruikt worden zelfs als IP wel gewijzigd is
- **Lock file** is orthogonaal: het staat helemaal aan het begin, voor alles andere
- **Dry-run** bypass de Azure API calls maar voert alles daarvoor normaal uit

## MVP Aanbeveling

Prioriteer (Fase 1 -- werkend script):
1. **Env var validatie** -- zonder dit is debugging een nachtmerrie
2. **IP ophalen + validatie** -- kernfunctie
3. **IP-caching** -- voorkomt onnodige API calls; dit is wat het script slim maakt
4. **Azure OAuth2 token + DNS update** -- de daadwerkelijke waarde
5. **Exit codes + basis logging** -- cron-integratie vereist dit
6. **HTTP response controle** -- weten of de update slaagde

Fase 2 (robuustheid):
1. **Lock file** -- eenvoudig en voorkomt race conditions
2. **Fallback IP-service** -- verhoogt beschikbaarheid
3. **TTL-configuratie** -- env var met default 300
4. **Force update flag** -- debugging tool
5. **Verbose modus** -- debugging tool

Uitstel (nice-to-have, niet noodzakelijk voor eerste release):
- **Token caching** -- optimalisatie; pas relevant bij zeer frequente cron runs (<5 min interval)
- **Retry logica** -- cron herhaalt het script toch; 1 retry is luxe, niet kritisch
- **Dry-run modus** -- handig maar niet noodzakelijk
- **Versie-informatie** -- triviaal toe te voegen wanneer nodig

## Bronnen

- ddclient configuratie-opties: https://ddclient.net/general.html [HIGH confidence -- officiele docs]
- ddclient caching systeem: https://deepwiki.com/ddclient/ddclient/2.4-caching-system [MEDIUM confidence -- DeepWiki analyse van broncode]
- ddclient DNS update proces: https://deepwiki.com/ddclient/ddclient/2.3-dns-update-process [MEDIUM confidence]
- ddclient IP-detectiemethodes: https://deepwiki.com/ddclient/ddclient/2.2-ip-detection-methods [MEDIUM confidence]
- inadyn configuratie: https://deepwiki.com/troglobit/inadyn/2.2-configuration [MEDIUM confidence]
- inadyn error handling: https://deepwiki.com/troglobit/inadyn/3.5-error-handling [MEDIUM confidence]
- inadyn forced-update en verify-address settings: bron inadyn.conf.5 man page via DeepWiki [MEDIUM confidence]
- Azure DNS REST API record sets: https://learn.microsoft.com/en-us/rest/api/dns/record-sets/create-or-update [HIGH confidence -- officiele Microsoft docs]
