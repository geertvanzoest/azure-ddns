# ns4j — Azure DNS Dynamic Updater

## What This Is

Een lightweight bash script dat als DDNS-client werkt voor Azure DNS. Het detecteert het publieke IP-adres van het netwerk via een externe service en update een A-record in Azure DNS via curl. Ontworpen om als cron job op een Raspberry Pi te draaien met zero dependencies buiten standaard systeemtools.

## Core Value

Het Azure DNS A-record is altijd actueel met het huidige publieke IP-adres van het thuisnetwerk.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Script detecteert het huidige publieke IP via een externe service
- [ ] Script authenticeert naar Azure via Service Principal credentials (env vars)
- [ ] Script update een A-record in Azure DNS via curl REST API calls
- [ ] Script logt wijzigingen en errors naar console (stdout/stderr)
- [ ] Configuratie volledig via environment variables
- [ ] Zero dependencies buiten bash en curl
- [ ] Script draait als single-run (voor cron job), geen daemon

### Out of Scope

- Node.js / Python / andere runtimes — bash + curl volstaat
- Azure SDK of CLI — directe REST API calls via curl
- Meerdere DNS records/zones tegelijk — een A-record is genoeg
- Push notificaties (email, Slack, etc.) — logging volstaat
- Docker container — overkill voor een simpel cron script
- IPv6 / AAAA records — niet gevraagd
- Ingebouwde scheduling — cron handelt dit af

## Context

- Draait op een Raspberry Pi — ARM-architectuur, beperkte resources
- bash en curl zijn standaard beschikbaar op Raspberry Pi OS
- Azure DNS zone bestaat al, alleen het A-record moet bijgewerkt worden
- Service Principal met DNS Zone Contributor rechten op de betreffende zone
- Cron job regelt het interval (configureerbaar door gebruiker via crontab)
- Publiek IP wordt gedetecteerd via een externe service zoals ifconfig.me of ipify.org
- Azure REST API vereist OAuth2 token via Service Principal flow

## Constraints

- **Runtime**: bash + curl (standaard op elke Pi)
- **Platform**: Raspberry Pi (ARM, beperkt geheugen/CPU)
- **Dependencies**: Zero — alleen bash, curl, en jq (voor JSON parsing)
- **Auth**: Azure Service Principal (client ID, client secret, tenant ID)
- **Netwerk**: Moet uitgaand HTTPS kunnen bereiken (IP-service + Azure REST API)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bash + curl i.p.v. Node.js | Zero dependencies, lichter kan niet, curl zit al op de Pi | — Pending |
| Direct Azure REST API i.p.v. SDK/CLI | Geen extra tooling nodig, curl volstaat voor twee API calls | — Pending |
| Cron job i.p.v. daemon/systemd | Simpelst mogelijke uitvoeringsmodel, Pi-friendly | — Pending |
| Env vars i.p.v. config file | Past bij cron-model, geen file management nodig | — Pending |
| Externe IP-service (ifconfig.me) | Simpel, betrouwbaar, geen lokale netwerk-parsing nodig | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-30 after initialization*
