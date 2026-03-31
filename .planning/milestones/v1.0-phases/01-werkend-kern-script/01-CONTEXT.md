# Phase 1: Werkend kern-script - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Volledige happy path: config-validatie, Azure auth, IP-detectie, DNS GET/PUT. Gebruiker kan het script draaien via cron en het Azure DNS A-record wordt automatisch bijgewerkt wanneer het publieke IP wijzigt.

Scope: IP-01, IP-03, AUTH-01, AUTH-02, DNS-01, DNS-02, CFG-01, CFG-02, OPS-01, OPS-02.

</domain>

<decisions>
## Implementation Decisions

### Log output formaat
- **D-01:** Gestructureerd formaat: `[TIMESTAMP] LEVEL: bericht` (bijv. `[2026-03-31 08:00:01] INFO: IP unchanged (1.2.3.4)`)
- **D-02:** Routing: INFO/SKIP berichten naar stdout, ERROR berichten naar stderr. Cron mailt alleen bij stderr-output/non-zero exit.

### Env var validatie
- **D-03:** Alle ontbrekende variabelen tegelijk tonen, dan exit 1. Loop over de 7 verplichte vars, toon `ERROR: $var is niet ingesteld` per ontbrekende variabele.

### Eerste-keer gedrag (DNS record bestaat nog niet)
- **D-04:** GET het huidige A-record. HTTP 200 = vergelijk IP, skip PUT als ongewijzigd. HTTP 404 = record bestaat nog niet, IP is per definitie anders, doe PUT. Andere HTTP status = abort met exit code 4.

### Script bestandsnaam en structuur
- **D-05:** Bestandsnaam `ns4j` (zonder extensie) in de repo-root.
- **D-06:** Shebang `#!/bin/bash` (absoluut pad, gegarandeerd op Raspberry Pi OS, geen PATH-afhankelijkheid in cron).

### Claude's Discretion
- Script interne structuur (functies vs lineair) — Claude bepaalt de beste organisatie
- Exacte timestamp formaat (ISO 8601 of korter) — Claude kiest passend formaat
- Variabele naamgeving binnen het script — Claude volgt bash conventies

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Azure DNS REST API
- `CLAUDE.md` §Technology Stack — Bevat exacte API endpoints, versie (2018-05-01), rate limits, en OAuth2 flow details
- `CLAUDE.md` §Bronnen — URLs naar officiële Microsoft documentatie voor Record Sets Create/Update, Record Sets Get, en OAuth2 Client Credentials Flow

### Requirements
- `.planning/REQUIREMENTS.md` §IP-detectie — IP-01, IP-03 specificaties
- `.planning/REQUIREMENTS.md` §Azure Authenticatie — AUTH-01, AUTH-02 specificaties
- `.planning/REQUIREMENTS.md` §DNS Management — DNS-01, DNS-02 specificaties
- `.planning/REQUIREMENTS.md` §Configuratie — CFG-01, CFG-02 specificaties
- `.planning/REQUIREMENTS.md` §Operatie — OPS-01, OPS-02 specificaties

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Geen — greenfield project, repo bevat alleen CLAUDE.md

### Established Patterns
- Geen bestaande patronen — dit is het eerste script

### Integration Points
- Cron: script wordt aangeroepen als `*/5 * * * * /pad/naar/ns4j` (gebruiker configureert)
- Environment: 7 verplichte env vars worden extern gezet (crontab of /etc/environment)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches within the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-werkend-kern-script*
*Context gathered: 2026-03-31*
