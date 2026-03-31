# Phase 5: Documentatie - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning
**Mode:** Auto-generated (autonomous mode — content phase with clear requirements)

<domain>
## Phase Boundary

Een Pi-beheerder kan ddns4j zelfstandig installeren, configureren en troubleshooten zonder hulp van de ontwikkelaar. Alle documentatie in het Nederlands.

</domain>

<decisions>
## Implementation Decisions

### Documentatie structuur
- Eén README.md met alle secties (geen aparte docs/ directory — overkill voor een enkel script)
- Secties: overzicht, features, prerequisites, installatie, configuratie (Azure SP + env vars), gebruik, troubleshooting
- Taal: Nederlands (doeltaal van het project)

### Doelgroep
- Linux-beheerder met basiskennis van terminal, cron, en Azure Portal
- Geen verwachte kennis van OAuth2, REST APIs, of bash scripting
- Stap-voor-stap instructies met kopieerbare commando's

### Claude's Discretion
- Exacte formatting en opmaak keuzes
- Volgorde van secties binnen de constraints
- Mate van detail per sectie

</decisions>

<code_context>
## Existing Code Insights

### Script capabilities
- `ddns4j` — hoofdscript, 267 regels bash
- Dependencies: bash (>=4.x), curl (>=7.68), jq (>=1.6)
- 7 verplichte env vars + 1 optioneel (DNS_TTL)
- Exit codes: 0=ok, 1=config, 2=IP, 3=auth, 4=DNS
- Flags: --force
- Env vars: VERBOSE=1 voor debug

### Azure setup (uit CLAUDE.md)
- Service Principal met DNS Zone Contributor role
- Scope: alleen de specifieke DNS zone
- OAuth2 client credentials flow

</code_context>

<specifics>
## Specific Ideas

Documentatie moet compleet genoeg zijn voor iemand die het zelfstandig moet installeren, configureren, runnen en beheren op een Raspberry Pi. Self-explained overdracht.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
