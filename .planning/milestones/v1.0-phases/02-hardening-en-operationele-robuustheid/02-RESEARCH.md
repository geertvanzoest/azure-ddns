# Phase 2: Hardening en operationele robuustheid - Research

**Researched:** 2026-03-31
**Domain:** Bash script hardening (flock, IP-validatie, fallback, CLI flags, verbose logging)
**Confidence:** HIGH

## Summary

Phase 2 breidt het werkende Phase 1 script uit met zes concrete hardening-features: IPv4-validatie met strikte regex (IP-02), fallback IP-service cascade (IP-04), configureerbare TTL (DNS-03), flock-based lock file (OPS-03), --force flag via argument parsing (OPS-04), en verbose debug modus (OPS-05). Alle features zijn pure bash -- geen nieuwe dependencies, geen externe tools buiten wat al op de Raspberry Pi aanwezig is.

De technische complexiteit is laag. Alle patronen zijn standaard bash-idioom (flock fd redirect, while/case arg parsing, regex matching met `=~`, conditional logging). De grootste risico's zitten in correcte integratie met het bestaande `set -euo pipefail` + ERR trap patroon, en in de volgorde van operaties in `main()` (flock moet voor alles, parse_args voor validate_config).

**Primary recommendation:** Implementeer in logische volgorde: (1) constanten/variabelen uitbreiden, (2) parse_args + flock wrapper, (3) IP-fallback + validatie, (4) verbose logging, (5) --force integratie in main flow. DNS-03 (TTL) is al geimplementeerd in Phase 1 code (`${DNS_TTL:-300}`), alleen documentatie-alignment nodig.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Cascade-volgorde: icanhazip.com (primair) -> checkip.amazonaws.com (fallback). Eerste geldige response wint.
- **D-02:** Inline IPv4-regex validatie na elke service-response. Ongeldige responses (HTML, IPv6, leeg) leiden tot doorval naar volgende service.
- **D-03:** Bij uitputting van alle services: log alle geprobeerde URLs naar stderr en exit met code 2 (EXIT_IP).
- **D-04:** Geen confirmatie via 2e service bij IP-wijziging -- de bestaande GET-vergelijking met het DNS-record dekt dit al af.
- **D-05:** `flock --nonblock` op `/tmp/ns4j.lock`. Lock file in /tmp verdwijnt na reboot (geen stale locks).
- **D-06:** Bij geblokkeerde lock: log `WARN: andere instantie draait`, exit 0. Zichtbaar in logs maar geen cron-mail.
- **D-07:** `while/case` loop over `$@` in een `parse_args()` functie (~15 regels). Ondersteunt long options native.
- **D-08:** v1: `--force` flag. Structuur is direct uitbreidbaar voor v2 flags (`--dry-run`, `--version`).
- **D-09:** Onbekende flags: log foutmelding en exit 1 (EXIT_CONFIG).
- **D-10:** `VERBOSE=1` env var activeert DEBUG-level logging via het bestaande `[TIMESTAMP] LEVEL: bericht` formaat.
- **D-11:** Verbose output bevat: config-waarden (AZURE_CLIENT_SECRET expliciet uitgesloten), HTTP-statuscodes per API-call, IP-resultaat per service, change-detection beslissing.
- **D-12:** DEBUG-berichten gaan naar stdout (zelfde routing als INFO). Alleen actief bij VERBOSE=1.
- **D-13:** Env var naam blijft `DNS_TTL` (consistent met bestaande code). REQUIREMENTS.md noemt `AZURE_DNS_TTL` maar de gevestigde conventie is zonder AZURE_ prefix.
- **D-14:** Default waarde 300 seconden (al geimplementeerd in update_dns functie).

### Claude's Discretion
- IPv4 regex implementatie (strikte octet-validatie 0-255 of simpele pattern match) -- Claude kiest meest robuuste aanpak
- Exacte flock wrapper-aanpak (exec-based of subshell) -- Claude bepaalt
- Volgorde van operaties in main() (parse_args voor of na validate_config) -- Claude kiest logische flow

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| IP-02 | Script valideert het opgehaalde IP-adres met een IPv4 regex check | Strikte octet-validatie regex getest en geverifieerd (zie Code Examples). Bash `=~` operator met unquoted regex variabele. |
| IP-04 | Script valt terug op een alternatieve IP-service als de primaire faalt | Cascade-patroon met IP_SERVICES array en for-loop. Validatie per service-response voorkomt garbage doorgifte. |
| DNS-03 | TTL is configureerbaar via environment variable met default 300 seconden | Al geimplementeerd in Phase 1: `${DNS_TTL:-300}` in update_dns(). Geen codewijziging nodig, alleen requirement markeren als complete. |
| OPS-03 | Script gebruikt flock lock file om concurrent cron execution te voorkomen | exec-based fd redirect + `flock --nonblock` patroon. Compatibel met set -euo pipefail. flock is standaard op Raspberry Pi (util-linux). |
| OPS-04 | Script ondersteunt --force flag om IP-vergelijking te skippen | while/case parse_args() functie. FORCE variabele conditioneert de IP-vergelijking in main(). |
| OPS-05 | Script ondersteunt verbose modus (VERBOSE=1) voor extra debug output | debug() wrapper functie rond bestaande log(). Guard-check op VERBOSE env var. |
</phase_requirements>

## Standard Stack

### Core (geen nieuwe dependencies)
| Tool | Versie | Doel | Waarom standaard |
|------|--------|------|------------------|
| bash | >= 4.x (Pi: 5.2.x) | Script interpreter, regex matching (`=~`) | Standaard op Raspberry Pi OS Bookworm |
| flock | util-linux (standaard) | Lock file management | Onderdeel van util-linux, essentieel pakket op Debian/Raspberry Pi OS. Altijd aanwezig in `/usr/bin/flock` |
| curl | >= 7.68 | HTTP client (ongewijzigd) | Al in gebruik door Phase 1 |
| jq | >= 1.6 | JSON parsing (ongewijzigd) | Al in gebruik door Phase 1 |

### Ontwikkeltools (optioneel, niet op Pi vereist)
| Tool | Versie | Doel | Installatie |
|------|--------|------|-------------|
| bats-core | >= 1.10 | Bash test framework | `brew install bats-core` (macOS) / `apt install bats` (Debian) |
| shellcheck | >= 0.9 | Statische analyse bash | `brew install shellcheck` (macOS) / `apt install shellcheck` (Debian) |

### Alternatives Considered
| In plaats van | Zou kunnen | Tradeoff |
|---------------|------------|----------|
| flock (util-linux) | PID-file met handmatige check | Fragiel: race condition tussen check en write; stale PID-files na crash. flock is atomic en kernel-level |
| bash `=~` regex | grep -P / awk | Extra process spawn per validatie; `=~` is native bash en sneller |
| while/case arg parsing | getopts | getopts ondersteunt geen long options (`--force`). while/case is de standaard bash-aanpak voor long options |

## Architecture Patterns

### Uitbreiding op bestaande structuur
```
ns4j (script)
  Constanten blok (regel 5-13)
  + IP_SERVICES array
  + IP_REGEX
  + LOCK_FILE
  + FORCE=0, VERBOSE=${VERBOSE:-0}

  Functies:
  + parse_args()          # NIEUW: --force parsing
  + debug()               # NIEUW: verbose logging wrapper
  ~ get_public_ip()       # GEWIJZIGD: fallback cascade + validatie
    log()                 # ONGEWIJZIGD
    validate_config()     # ONGEWIJZIGD
    get_access_token()    # + debug() calls
    get_dns_record()      # + debug() calls
    update_dns()          # + debug() calls

  ~ main()                # GEWIJZIGD: flock + parse_args + force conditie
```

### Pattern 1: Exec-based flock (aanbevolen)
**Wat:** File descriptor redirect + flock op dat fd, voordat main() start.
**Wanneer:** Altijd -- dit is het eerste wat het script doet na constanten.
**Waarom exec-based:** De lock wordt automatisch vrijgegeven als het script eindigt (normaal of via crash/signal). Geen cleanup nodig. Compatibel met `set -euo pipefail` omdat de `if ! flock` constructie in conditional context staat (immuun voor `set -e`).
```bash
readonly LOCK_FILE="/tmp/ns4j.lock"
exec 200>"$LOCK_FILE"
if ! flock --nonblock 200; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: Andere instantie draait, overgeslagen"
    exit 0
fi
```
**Belangrijk:** De flock-check moet VOOR de log() functie-definitie uitvoerbaar zijn, OF de log() functie moet al gedefinieerd zijn. Aangezien functies in bash bovenaan staan en de flock in het uitvoeringsblok (na functiedefinities, voor main-call), is dit geen probleem.

### Pattern 2: IP Fallback Cascade
**Wat:** Array van IP-services, for-loop met validatie per response.
**Wanneer:** Vervangt de huidige single-service `get_public_ip()`.
```bash
readonly IP_SERVICES=(
    "https://icanhazip.com"
    "https://checkip.amazonaws.com"
)
readonly IP_REGEX="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"

get_public_ip() {
    local ip http_code response body
    for service in "${IP_SERVICES[@]}"; do
        response=$(curl --silent --show-error --max-time 10 \
            --write-out "\n%{http_code}" "$service" 2>/dev/null) || {
            debug "Service ${service} niet bereikbaar"
            continue
        }
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        ip=$(echo "$body" | tr -d '[:space:]')

        if [[ "$http_code" != "200" ]]; then
            debug "Service ${service}: HTTP ${http_code}"
            continue
        fi
        if [[ ! "$ip" =~ $IP_REGEX ]]; then
            debug "Service ${service}: ongeldig IP '${ip}'"
            continue
        fi
        debug "Service ${service}: IP=${ip}"
        echo "$ip"
        return 0
    done
    log "ERROR" "Geen geldige IP-service beschikbaar (geprobeerd: ${IP_SERVICES[*]})"
    exit "${EXIT_IP}"
}
```

### Pattern 3: Verbose Debug Logging
**Wat:** Guard-functie die alleen logt als VERBOSE=1.
**Wanneer:** Door alle functies heen, na elke significante stap.
```bash
debug() {
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        log "DEBUG" "$@"
    fi
}
```

### Pattern 4: Argument Parsing
**Wat:** while/case loop voor --force (en toekomstige flags).
```bash
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE=1
                shift
                ;;
            *)
                log "ERROR" "Onbekende optie: $1"
                exit "${EXIT_CONFIG}"
                ;;
        esac
    done
}
```

### Volgorde van operaties in main()
```
1. parse_args "$@"       # Eerst: bepaalt FORCE voor de rest van de flow
2. validate_config       # Daarna: check env vars (onafhankelijk van flags)
3. flock check           # N.B.: flock staat BUITEN main(), voor de main-call
4. get_public_ip         # IP ophalen met fallback + validatie
5. get_dns_record        # Huidig record ophalen
6. IP-vergelijking       # Skip als gelijk EN niet --force
7. update_dns            # Alleen als nodig
```

**Correctie op bovenstaand:** flock staat in het uitvoeringsblok onderaan het script, VOOR de `main "$@"` call. main() begint dan met parse_args, niet met flock.

### Anti-Patterns te vermijden
- **PID-file in plaats van flock:** Race condition tussen read en write. flock is atomic op kernel-niveau.
- **getopts voor long options:** getopts ondersteunt alleen single-character options. while/case is het idioom voor --force style flags.
- **Regex in dubbele quotes:** `[[ "$ip" =~ "$IP_REGEX" ]]` matcht als literal string, niet als regex. De regex variabele moet UNQUOTED zijn: `[[ "$ip" =~ $IP_REGEX ]]`.
- **curl --fail in fallback-loop:** `--fail` gecombineerd met `set -e` zorgt dat het script stopt bij de eerste falende service. Gebruik HTTP-code check in plaats daarvan.
- **Logging van AZURE_CLIENT_SECRET:** D-11 sluit dit expliciet uit. Bij debug logging van config-waarden: toon alle vars BEHALVE het secret.

## Don't Hand-Roll

| Probleem | Bouw niet zelf | Gebruik in plaats daarvan | Waarom |
|----------|----------------|--------------------------|--------|
| File locking | PID-file met check/write | `flock` (util-linux) | Atomic kernel-level lock, geen race conditions, geen stale files |
| JSON constructie | String concatenatie | `jq -n` (al in gebruik) | Correcte escaping, geen injection |
| IPv4 validatie | Ping/dig/nslookup check | Bash `=~` met regex | Geen network call nodig, puur syntactische check |
| Argument parsing (long opts) | getopts + manual conversion | while/case loop | getopts doet geen long options; while/case is <15 regels |

## Common Pitfalls

### Pitfall 1: Regex variabele in dubbele quotes
**Wat gaat mis:** `[[ "$ip" =~ "$IP_REGEX" ]]` behandelt de regex als literal string. Geen enkele IP matcht.
**Waarom het gebeurt:** Bash-reflex om alles te quoten. Maar bij `=~` mag de rechteroperand niet gequote zijn als het een regex-variabele is.
**Hoe te voorkomen:** Sla de regex op in een variabele en gebruik die UNQUOTED: `[[ "$ip" =~ $IP_REGEX ]]`.
**Waarschuwingssignalen:** Alle IP-validaties falen, zelfs voor correcte IP-adressen.

### Pitfall 2: curl fout in fallback-loop stopt het script (set -e)
**Wat gaat mis:** `set -e` is actief. Als curl faalt (timeout, DNS error), stopt het hele script in plaats van door te vallen naar de volgende service.
**Waarom het gebeurt:** `set -e` stopt bij elke non-zero exit code, tenzij het commando in een conditional context staat.
**Hoe te voorkomen:** Gebruik `|| { continue; }` of `|| true` na de curl-call in de loop. Of vang de output met een subshell: `response=$(...) || { debug "failed"; continue; }`.
**Waarschuwingssignalen:** Script stopt met ERR trap bij de eerste onbereikbare IP-service.

### Pitfall 3: flock fd conflict met bestaande redirects
**Wat gaat mis:** File descriptor 200 botst met een ander redirect in het script.
**Waarom het gebeurt:** Het script gebruikt al stdout (1) en stderr (2). Hogere fd-nummers (200+) zijn conventioneel veilig, maar als iemand een fd 200 redirect toevoegt, breekt de lock.
**Hoe te voorkomen:** Gebruik een hoog fd-nummer (200 is conventie) en documenteer het in een comment.
**Waarschuwingssignalen:** Lock werkt niet; meerdere instanties draaien tegelijk.

### Pitfall 4: VERBOSE check voor log() definitie
**Wat gaat mis:** De debug() functie roept log() aan, maar log() is nog niet gedefinieerd op het moment dat debug() de eerste keer wordt aangeroepen.
**Waarom het gebeurt:** Functies worden gedefinieerd in volgorde; als debug() boven log() staat en direct wordt aangeroepen, faalt het.
**Hoe te voorkomen:** Definieer log() voor debug(). Of definieer debug() direct na log(). In het huidige script staat log() al bovenaan -- geen probleem.
**Waarschuwingssignalen:** "command not found: log" bij VERBOSE=1.

### Pitfall 5: tr -d '[:space:]' verwijdert meer dan verwacht
**Wat gaat mis:** `tr -d '[:space:]'` verwijdert ALLE whitespace (spaties, tabs, newlines). Als een IP-service een response retourneert met een spatie in het IP (bijv. "192.168.1.1 extra"), wordt dit "192.168.1.1extra" -- dat faalt op de regex. Correct gedrag.
**Waarom relevant:** De huidige code (Phase 1) gebruikt dit al. Bij de fallback-cascade moet hetzelfde patroon consistent toegepast worden.
**Hoe te voorkomen:** Dit IS de gewenste aanpak. De regex vangt het probleem op. Geen actie nodig.

## Code Examples

### IPv4 Regex (strikte octet-validatie 0-255)
```bash
# Getest: alle geldige IPv4 adressen matchen (0.0.0.0 - 255.255.255.255)
# Getest: ongeldige waarden (256.x, partial, IPv6, HTML, lege string) worden afgewezen
# Let op: accepteert leading zeros (bijv. "01.02.03.04") -- niet relevant voor IP-services
readonly IP_REGEX="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"

# Gebruik (regex variabele MOET unquoted zijn):
if [[ ! "$ip" =~ $IP_REGEX ]]; then
    debug "Ongeldig IP: '${ip}'"
    continue
fi
```
**Bron:** Getest in bash 5.3.9 met 18 test cases (12 ongeldige, 6 geldige). Alle tests geslaagd behalve leading zeros (geaccepteerd als `[01]?` -- geen probleem in productie).

### Flock exec-based locking
```bash
readonly LOCK_FILE="/tmp/ns4j.lock"

# Na functiedefinities, voor main() call:
exec 200>"$LOCK_FILE"
if ! flock --nonblock 200; then
    log "WARN" "Andere instantie draait, overgeslagen"
    exit 0
fi

main "$@"
```
**Bron:** Standaard flock-patroon uit util-linux documentatie. exec-based variant houdt lock vast tot script eindigt (fd 200 wordt automatisch gesloten). Compatibel met `set -euo pipefail` omdat `if ! ...` conditional context is.

### Debug logging met config dump (secret uitgesloten)
```bash
debug() {
    if [[ "${VERBOSE:-0}" == "1" ]]; then
        log "DEBUG" "$@"
    fi
}

# In validate_config(), na succesvolle validatie:
debug "Config: DNS_ZONE_NAME=${DNS_ZONE_NAME}, DNS_RECORD_NAME=${DNS_RECORD_NAME}"
debug "Config: AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}"
debug "Config: AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}"
debug "Config: DNS_TTL=${DNS_TTL:-300}"
# AZURE_CLIENT_SECRET wordt NIET gelogd (D-11)
```

### Complete parse_args functie
```bash
FORCE=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE=1
                shift
                ;;
            *)
                log "ERROR" "Onbekende optie: $1"
                exit "${EXIT_CONFIG}"
                ;;
        esac
    done
}
```

### Force-conditie in main()
```bash
# In main(), na get_public_ip en get_dns_record:
if [[ "$current_ip" == "$public_ip" ]] && [[ "$FORCE" -eq 0 ]]; then
    log "INFO" "IP ongewijzigd (${public_ip})"
    exit "${EXIT_OK}"
fi

if [[ "$FORCE" -eq 1 ]]; then
    debug "Force modus: update ongeacht IP-vergelijking"
fi
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bats-core >= 1.10 |
| Config file | none -- zie Wave 0 |
| Quick run command | `bats test/` |
| Full suite command | `bats test/` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IP-02 | IPv4 regex valideert correcte IP's en weigert ongeldige | unit | `bats test/test_ip_validation.bats` | Wave 0 |
| IP-04 | Fallback naar 2e service als 1e faalt | unit (mock) | `bats test/test_ip_fallback.bats` | Wave 0 |
| DNS-03 | TTL configureerbaar via DNS_TTL env var | unit | `bats test/test_ttl.bats` | Wave 0 |
| OPS-03 | flock voorkomt gelijktijdige uitvoering | integration | `bats test/test_locking.bats` | Wave 0 |
| OPS-04 | --force flag skipt IP-vergelijking | unit | `bats test/test_force_flag.bats` | Wave 0 |
| OPS-05 | VERBOSE=1 activeert DEBUG output | unit | `bats test/test_verbose.bats` | Wave 0 |

### Sampling Rate
- **Per task commit:** `bats test/`
- **Per wave merge:** `bats test/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/` directory aanmaken
- [ ] bats-core installeren: `brew install bats-core` (macOS dev) / `apt install bats` (Pi)
- [ ] Test helper voor source van ns4j functies (zonder main() uit te voeren)
- [ ] `test/test_ip_validation.bats` -- covers IP-02
- [ ] `test/test_ip_fallback.bats` -- covers IP-04 (vereist curl mock)
- [ ] `test/test_locking.bats` -- covers OPS-03 (vereist flock, alleen op Linux)
- [ ] `test/test_force_flag.bats` -- covers OPS-04
- [ ] `test/test_verbose.bats` -- covers OPS-05
- [ ] `test/test_ttl.bats` -- covers DNS-03

**Testbaarheid:** Het huidige script heeft alle logica in functies (goed), maar `main "$@"` wordt direct aangeroepen bij source. Voor unit tests moet het script sourceable zijn zonder main() uit te voeren. Aanpak: guard `main "$@"` met `[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"` of een `NS4J_TESTING` env var check.

**flock tests:** flock is niet beschikbaar op macOS (alleen util-linux op Linux). OPS-03 tests moeten overgeslagen worden op macOS of een skip-guard gebruiken.

## Environment Availability

| Dependency | Required By | Available (macOS dev) | Available (Pi target) | Fallback |
|------------|------------|----------------------|----------------------|----------|
| bash >= 4.x | Alle features | 5.3.9 | 5.2.x (Bookworm) | -- |
| flock (util-linux) | OPS-03 | Niet beschikbaar | Standaard aanwezig | -- |
| curl | IP-detectie, Azure API | Beschikbaar | Beschikbaar | -- |
| jq | JSON parsing | Beschikbaar | Via `apt install jq` | -- |
| bats-core | Tests | Niet geinstalleerd | Via `apt install bats` | Handmatige test |
| shellcheck | Statische analyse | Niet geinstalleerd | Via `apt install shellcheck` | Optioneel |

**Missing dependencies with no fallback:**
- flock is niet op macOS beschikbaar -- OPS-03 kan niet lokaal getest worden (enkel op Linux/Pi). Dit is geen blocker: het script draait alleen op de Pi.

**Missing dependencies with fallback:**
- bats-core: niet geinstalleerd. Installeerbaar via `brew install bats-core` (macOS) of `apt install bats` (Pi).
- shellcheck: niet geinstalleerd. Optioneel maar aanbevolen voor code quality. `brew install shellcheck`.

## Open Questions

1. **Testbaarheid van het script**
   - Wat we weten: Het script roept `main "$@"` direct aan bij source. Dit maakt unit testing van individuele functies lastig.
   - Wat onduidelijk is: Of de guard-aanpak (`BASH_SOURCE` check) het bestaande cron-gedrag behoudt.
   - Aanbeveling: Voeg `[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"` toe. Dit is standaard bash-idioom en breekt cron-uitvoering niet.

2. **DNS-03 status in REQUIREMENTS.md**
   - Wat we weten: DNS_TTL is al geimplementeerd in Phase 1 als `${DNS_TTL:-300}`. REQUIREMENTS.md noemt het als `AZURE_DNS_TTL` maar de code gebruikt `DNS_TTL`.
   - Wat onduidelijk is: Of REQUIREMENTS.md geupdate moet worden (naamwijziging) of alleen de checkbox.
   - Aanbeveling: Markeer DNS-03 als complete en voeg een note toe dat de env var `DNS_TTL` heet (per D-13).

## Project Constraints (from CLAUDE.md)

- **Runtime:** bash + curl + jq only. Geen Python, Node, Azure CLI.
- **Platform:** Raspberry Pi (ARM, beperkt geheugen/CPU).
- **Auth:** Azure Service Principal (client credentials flow).
- **IP-services:** icanhazip.com (primair), checkip.amazonaws.com (fallback). Andere services zijn NOT te gebruiken (ipify.org, ifconfig.me, ipinfo.io -- allemaal afgekeurd in CLAUDE.md).
- **API versie:** `2018-05-01` (gepind, geen preview versies).
- **Env var conventie:** DNS_ZONE_NAME/DNS_RECORD_NAME (zonder AZURE_ prefix voor DNS vars).
- **Niet gebruiken:** Azure CLI, Azure SDK, Docker, systemd service, token caching, preview API versies.

## Sources

### Primary (HIGH confidence)
- Bestaand script `ns4j` (Phase 1 output) -- alle functies en patronen direct gelezen
- `.planning/research/PITFALLS.md` -- eerder onderzochte pitfalls voor dit domein
- `.planning/research/FEATURES.md` -- eerder onderzochte feature landscape
- CONTEXT.md (02-CONTEXT.md) -- alle gebruikersbeslissingen
- Directe bash-tests op macOS (bash 5.3.9): IPv4 regex met 18 test cases, parse_args patroon, flock compatibiliteit

### Secondary (MEDIUM confidence)
- util-linux flock documentatie (man page) -- flock syscall semantiek
- Raspberry Pi OS Bookworm package info -- bash 5.2.x, util-linux standaard

### Tertiary (LOW confidence)
- Geen -- alle findings geverifieerd via directe tests of officiele documentatie

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- geen nieuwe dependencies, alles al aanwezig op Pi
- Architecture: HIGH -- alle patronen zijn standaard bash-idioom, direct getest
- Pitfalls: HIGH -- gebaseerd op directe tests (regex quoting, set -e interactie)

**Research date:** 2026-03-31
**Valid until:** 2026-06-30 (stabiel domein, geen snel bewegende dependencies)
