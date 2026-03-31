# Phase 2: Hardening en operationele robuustheid - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 02-hardening-en-operationele-robuustheid
**Areas discussed:** Fallback-strategie, Lock file gedrag, CLI flags & argumenten, Verbose output

---

## Fallback-strategie

| Option | Description | Selected |
|--------|-------------|----------|
| Cascade + validatie + hard failure | Probeer icanhazip -> checkip.amazonaws, valideer elk antwoord met IPv4-regex, exit 2 als alles faalt | ✓ |
| Cascade-only + hard failure | Geen regex-validatie, gewoon eerste niet-lege response gebruiken | |
| Cascade + confirmatie bij wijziging | Bij IP-wijziging extra check met 2e service. Complexer maar veiliger tegen false positives | |

**User's choice:** Cascade + validatie + hard failure (Recommended)
**Notes:** Advisor research bevestigde dat confirmatie via 2e service overbodig is — de bestaande GET-vergelijking met het DNS-record dekt dit al af.

---

## Lock file gedrag

| Option | Description | Selected |
|--------|-------------|----------|
| Log + exit 0 | Log 'WARN: andere instantie draait (PID X)', exit 0. Zichtbaar in logs maar geen cron-mail | ✓ |
| Stille exit (code 0) | Geen output, geen log. Invisible maar zero noise | |
| Log + exit 5 | Eigen exit code voor monitoring. Vereist MAILTO="" in crontab om spam te voorkomen | |

**User's choice:** Log + exit 0 (Recommended)
**Notes:** flock --nonblock op /tmp/ns4j.lock. Lock in /tmp verdwijnt na reboot.

---

## CLI flags & argumenten

| Option | Description | Selected |
|--------|-------------|----------|
| while/case loop | Handmatige long-option parsing: while/case over $@, ~15 regels, direct uitbreidbaar voor v2 --dry-run/--version | ✓ |
| getopts (POSIX) | Alleen short flags (-f, -v). Long options vereisen workarounds | |
| GNU getopt | Short + long, maar extra dependency en portability-risico op non-Linux | |

**User's choice:** while/case loop (Recommended)
**Notes:** Requirements specificeren --force als long option. while/case is idiomatisch bash voor long options zonder dependencies.

---

## Verbose output

| Option | Description | Selected |
|--------|-------------|----------|
| Gecombineerd zonder secrets | Config-waarden (ex. secret), HTTP-statuscodes, IP per service, change-detection beslissing. Via DEBUG log level | ✓ |
| Alleen variabelen & state | Config + state logging, geen HTTP details. Minder info maar ook minder output | |
| HTTP details (curl -v equivalent) | Maximale netwerk-debug, maar risico op token leakage in logs | |

**User's choice:** Gecombineerd zonder secrets (Recommended)
**Notes:** AZURE_CLIENT_SECRET expliciet uitsluiten uit verbose output. DEBUG-berichten naar stdout.

---

## Claude's Discretion

- IPv4 regex implementatie (strikte octet-validatie vs simpele pattern)
- flock wrapper-aanpak (exec-based vs subshell)
- Volgorde parse_args vs validate_config in main()

## Deferred Ideas

None — discussion stayed within phase scope.
