# ns4j — Azure DNS Dynamic Updater

## What This Is

Een lightweight bash script (267 regels) dat als DDNS-client werkt voor Azure DNS. Detecteert het publieke IP-adres via icanhazip.com (met checkip.amazonaws.com als fallback), authenticeert via OAuth2 Service Principal credentials, en update een A-record in Azure DNS via de REST API. Productieklaar voor onbeheerde cron-uitvoering op een Raspberry Pi.

## Core Value

Het Azure DNS A-record is altijd actueel met het huidige publieke IP-adres van het thuisnetwerk.

## Current State

**Shipped:** v1.0 (2026-03-31)
**LOC:** 616 (267 script + 349 tests)
**Test suite:** 27 bats-core tests over 6 bestanden

### What's Working
- Publiek IP-detectie met IPv4 validatie en fallback cascade
- OAuth2 client credentials flow naar Azure Entra ID
- Azure DNS REST API 2018-05-01: GET huidig record, PUT bij wijziging
- Fail-fast config validatie (7 env vars + jq check)
- flock locking, --force flag, VERBOSE=1 debug modus
- Correcte exit codes (0-4) en log routing (ERROR->stderr, INFO->stdout)

## Requirements

### Validated

- IP-01: Publiek IP ophalen via icanhazip.com — v1.0
- IP-02: IPv4 regex validatie — v1.0
- IP-03: IP vergelijken met DNS record, skip als ongewijzigd — v1.0
- IP-04: Fallback naar checkip.amazonaws.com — v1.0
- AUTH-01: OAuth2 access token via client credentials — v1.0
- AUTH-02: HTTP response codes controleren op alle Azure API calls — v1.0
- DNS-01: GET huidig A-record via Azure DNS REST API — v1.0
- DNS-02: PUT A-record bij IP-wijziging — v1.0
- DNS-03: Configureerbare TTL via DNS_TTL env var (default 300) — v1.0
- CFG-01: Alle configuratie via environment variables — v1.0
- CFG-02: Validatie verplichte env vars bij startup — v1.0
- OPS-01: Exit codes 0=ok, 1=config, 2=IP, 3=auth, 4=DNS — v1.0
- OPS-02: Logging naar stdout (info) en stderr (errors) — v1.0
- OPS-03: flock lock file voor concurrent execution preventie — v1.0
- OPS-04: --force flag om altijd te updaten — v1.0
- OPS-05: Verbose modus via VERBOSE=1 — v1.0

### Active

(Geen actieve requirements — next milestone nog niet gedefinieerd)

### Out of Scope

- Node.js / Python / andere runtimes — bash + curl volstaat
- Azure SDK of CLI — directe REST API calls via curl
- Meerdere DNS records/zones tegelijk — een A-record is genoeg
- Push notificaties (email, Slack, etc.) — logging volstaat
- Docker container — overkill voor een simpel cron script
- IPv6 / AAAA records — niet gevraagd
- Ingebouwde scheduling — cron handelt dit af

## Constraints

- **Runtime**: bash + curl (standaard op elke Pi)
- **Platform**: Raspberry Pi (ARM, beperkt geheugen/CPU)
- **Dependencies**: bash, curl, jq (voor JSON parsing)
- **Auth**: Azure Service Principal (client ID, client secret, tenant ID)
- **Netwerk**: Moet uitgaand HTTPS kunnen bereiken (IP-service + Azure REST API)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bash + curl i.p.v. Node.js | Zero dependencies, lichter kan niet | Validated v1.0 |
| Direct Azure REST API i.p.v. SDK/CLI | Geen extra tooling nodig, curl volstaat | Validated v1.0 |
| Cron job i.p.v. daemon/systemd | Simpelst mogelijke uitvoeringsmodel | Validated v1.0 |
| Env vars i.p.v. config file | Past bij cron-model, geen file management | Validated v1.0 |
| icanhazip.com als primaire IP-service | Cloudflare-backed, betrouwbaar, snel | Validated v1.0 |
| IP fallback cascade | Twee betrouwbare providers, automatische failover | Validated v1.0 |
| flock --nonblock voor locking | Simpelste mechanisme, standaard op Linux | Validated v1.0 |
| VERBOSE env var i.p.v. --verbose flag | Env vars passen bij cron-model | Validated v1.0 |
| DNS_ZONE_NAME/DNS_RECORD_NAME naamgeving | Per CLAUDE.md conventie (niet AZURE_DNS_*) | Validated v1.0 |
| PATH-based curl mock voor tests | Betrouwbaarder dan export -f in bats subprocessen | Validated v1.0 |

## Context

Shipped v1.0 met 616 LOC (bash + bats tests).
Tech stack: bash, curl, jq, bats-core.
Getest op Debian bookworm (Docker) en macOS (dev).
UAT: 9/9 tests passed, 0 issues.

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-03-31 after v1.0 milestone*
