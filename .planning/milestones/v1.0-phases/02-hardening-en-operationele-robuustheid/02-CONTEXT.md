# Phase 2: Hardening en operationele robuustheid - Context

**Gathered:** 2026-03-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Script productieklaar maken voor onbeheerde cron-uitvoering met bescherming tegen edge cases en debugging-mogelijkheden. Scope: IP-validatie (IP-02), fallback IP-service (IP-04), configureerbare TTL (DNS-03), lock file (OPS-03), --force flag (OPS-04), verbose modus (OPS-05).

</domain>

<decisions>
## Implementation Decisions

### Fallback-strategie (IP-02 + IP-04)
- **D-01:** Cascade-volgorde: icanhazip.com (primair) -> checkip.amazonaws.com (fallback). Eerste geldige response wint.
- **D-02:** Inline IPv4-regex validatie na elke service-response. Ongeldige responses (HTML, IPv6, leeg) leiden tot doorval naar volgende service.
- **D-03:** Bij uitputting van alle services: log alle geprobeerde URLs naar stderr en exit met code 2 (EXIT_IP).
- **D-04:** Geen confirmatie via 2e service bij IP-wijziging — de bestaande GET-vergelijking met het DNS-record dekt dit al af.

### Lock file gedrag (OPS-03)
- **D-05:** `flock --nonblock` op `/tmp/ns4j.lock`. Lock file in /tmp verdwijnt na reboot (geen stale locks).
- **D-06:** Bij geblokkeerde lock: log `WARN: andere instantie draait`, exit 0. Zichtbaar in logs maar geen cron-mail.

### CLI flags & argumenten (OPS-04)
- **D-07:** `while/case` loop over `$@` in een `parse_args()` functie (~15 regels). Ondersteunt long options native.
- **D-08:** v1: `--force` flag. Structuur is direct uitbreidbaar voor v2 flags (`--dry-run`, `--version`).
- **D-09:** Onbekende flags: log foutmelding en exit 1 (EXIT_CONFIG).

### Verbose output (OPS-05)
- **D-10:** `VERBOSE=1` env var activeert DEBUG-level logging via het bestaande `[TIMESTAMP] LEVEL: bericht` formaat.
- **D-11:** Verbose output bevat: config-waarden (AZURE_CLIENT_SECRET expliciet uitgesloten), HTTP-statuscodes per API-call, IP-resultaat per service, change-detection beslissing.
- **D-12:** DEBUG-berichten gaan naar stdout (zelfde routing als INFO). Alleen actief bij VERBOSE=1.

### TTL configuratie (DNS-03)
- **D-13:** Env var naam blijft `DNS_TTL` (consistent met bestaande code en naamconventie DNS_ZONE_NAME/DNS_RECORD_NAME). REQUIREMENTS.md noemt `AZURE_DNS_TTL` maar de gevestigde conventie is zonder AZURE_ prefix.
- **D-14:** Default waarde 300 seconden (al geimplementeerd in update_dns functie).

### Claude's Discretion
- IPv4 regex implementatie (strikte octet-validatie 0-255 of simpele pattern match) — Claude kiest meest robuuste aanpak
- Exacte flock wrapper-aanpak (exec-based of subshell) — Claude bepaalt
- Volgorde van operaties in main() (parse_args voor of na validate_config) — Claude kiest logische flow

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bestaand script
- `ns4j` — Huidig werkend script (Phase 1 output). Bevat alle functies die uitgebreid moeten worden: log(), validate_config(), get_access_token(), get_public_ip(), get_dns_record(), update_dns(), main().

### Azure DNS REST API
- `CLAUDE.md` §Technology Stack — Exacte API endpoints, versie (2018-05-01), rate limits, OAuth2 flow details
- `CLAUDE.md` §Publiek IP Detectie — Geteste services met betrouwbaarheidsrating (icanhazip.com primair, checkip.amazonaws.com fallback)

### Requirements
- `.planning/REQUIREMENTS.md` §IP-detectie — IP-02 (IPv4 regex), IP-04 (fallback service)
- `.planning/REQUIREMENTS.md` §DNS Management — DNS-03 (TTL configureerbaar)
- `.planning/REQUIREMENTS.md` §Operatie — OPS-03 (flock), OPS-04 (--force), OPS-05 (verbose)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `log()` functie (regel 17-29): Herbruikbaar voor DEBUG level, alleen guard-check op VERBOSE nodig
- `get_public_ip()` functie (regel 95-120): Basis voor fallback-cascade, moet uitgebreid met service-array en validatie-loop
- `update_dns()` functie (regel 149-182): DNS_TTL al geimplementeerd (`${DNS_TTL:-300}`), geen wijziging nodig voor DNS-03
- Exit code constanten (regel 9-13): EXIT_IP=2 herbruikbaar voor fallback-uitputting

### Established Patterns
- HTTP response parsing: `curl --write-out "\n%{http_code}"` + `tail -n1`/`sed '$d'` splitsing — consistent toepassen in fallback-loop
- jq met `// empty` fallback — behouden in nieuwe code
- `set -euo pipefail` + ERR trap — flock moet hiermee compatibel zijn

### Integration Points
- `main()` functie (regel 184-212): Entry point voor parse_args() + flock wrapper
- `get_public_ip()`: Wordt vervangen door fallback-versie met validatie
- Constanten blok (regel 6-13): Uitbreiden met IP_SERVICES array en IP_REGEX

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

*Phase: 02-hardening-en-operationele-robuustheid*
*Context gathered: 2026-03-31*
