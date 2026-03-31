## Project

**azure-ddns** — Bash DDNS-client voor Azure DNS op Raspberry Pi.

Detecteert publiek IP via icanhazip.com (fallback: checkip.amazonaws.com), authenticeert via OAuth2 Service Principal, en update een A-record via Azure DNS REST API 2018-05-01.

**Core Value:** Het Azure DNS A-record is altijd actueel met het huidige publieke IP-adres van het thuisnetwerk.

## Commands

```bash
# Run
./azure-ddns                    # Normaal: update alleen bij IP-wijziging
./azure-ddns --force            # Forceer update ongeacht huidig record
VERBOSE=1 ./azure-ddns          # Debug output (secret uitgesloten)

# Test
bats test/                      # Alle 27 tests (Linux: 27 ok, macOS: 24 ok + 3 skipped flock)

# Docker test (macOS dev)
docker run --rm -it -v "$(pwd)":/app -w /app debian:bookworm-slim bash
apt-get update && apt-get install -y curl jq && bats test/
```

## Architecture

```
azure-ddns                      # Hoofdscript (267 regels)
test/
  test_helper.bash              # Gemeenschappelijke setup: load_azure_ddns(), curl mock
  test_ip_validation.bats       # 8 tests — IPv4 regex (IP-02)
  test_ip_fallback.bats         # 4 tests — service cascade (IP-04)
  test_force_flag.bats          # 4 tests — --force parsing (OPS-04)
  test_verbose.bats             # 4 tests — VERBOSE=1 (OPS-05)
  test_ttl.bats                 # 4 tests — DNS_TTL config (DNS-03)
  test_locking.bats             # 3 tests — flock (OPS-03, Linux-only)
.github/workflows/test.yml     # CI: bats op ubuntu-latest bij push/PR
README.md                       # Gebruikersdocumentatie (Nederlands)
```

## Script flow

`main()` → `parse_args` → `validate_config` → `get_access_token` → `get_public_ip` → `get_dns_record` → vergelijk → `update_dns` (of skip)

Entry point: `BASH_SOURCE` guard + `flock --nonblock` op `/tmp/azure-ddns.lock`

## Exit codes

| Code | Constante | Betekenis |
|------|-----------|-----------|
| 0 | EXIT_OK | Succes of skip (IP ongewijzigd / lock bezet) |
| 1 | EXIT_CONFIG | Env var ontbreekt of jq niet gevonden |
| 2 | EXIT_IP | Alle IP-services onbereikbaar |
| 3 | EXIT_AUTH | OAuth2 token request mislukt |
| 4 | EXIT_DNS | Azure DNS API fout (GET of PUT) |

## Environment variables

Verplicht: `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `DNS_ZONE_NAME`, `DNS_RECORD_NAME`

Optioneel: `DNS_TTL` (default 300), `VERBOSE` (1 = debug)

## Code patterns

- **HTTP responses:** `curl --write-out "\n%{http_code}"` → `tail -n1` voor code, `sed '$d'` voor body
- **JSON extractie:** `jq -r '.field // empty'` — altijd `// empty` om "null" string te voorkomen
- **JSON constructie:** `jq -n --arg/--argjson` — nooit string concatenatie
- **Log routing:** ERROR naar stderr (`>&2`), rest naar stdout
- **Fail-fast:** Alle ontbrekende env vars verzamelen, dan exit (niet bij eerste stoppen)
- **IP validatie:** `[[ "$ip" =~ $IP_REGEX ]]` — regex unquoted in `=~`
- **Test mocking:** PATH-based curl mock (niet `export -f`), betrouwbaar in bats subprocessen

## Constraints

- **Runtime:** bash + curl + jq (geen andere dependencies)
- **Platform:** Raspberry Pi (ARM, Linux) — `flock` vereist, niet beschikbaar op macOS
- **API:** Azure DNS REST API 2018-05-01 (stabiel, geen nieuwere GA)
- **Auth:** OAuth2 client_credentials met scope `https://management.azure.com/.default`

## Gotchas

- `flock` bestaat niet op macOS — script exit 0 met "Andere instantie draait" melding. Test op Linux (Docker).
- `bats-core` niet beschikbaar via apt op Ubuntu — CI installeert via `git clone` + `install.sh`
- Env var namen zijn `DNS_ZONE_NAME`/`DNS_RECORD_NAME` (niet `AZURE_DNS_ZONE`/`AZURE_DNS_RECORD`)
