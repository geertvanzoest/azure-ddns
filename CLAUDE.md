# ns4j — Project Guidelines

## Project Overview

Zero-dependency Azure DDNS client for Raspberry Pi. Updates Azure DNS A-records
when the public IP address changes. Designed for systemd timer (oneshot) or
standalone daemon mode.

## Architecture

```
index.mjs (single file, ~360 lines)
├── CONFIG          — frozen config from env vars
├── IP detection    — multi-service failover + confirmation
├── OAuth2          — client credentials flow, token caching
├── DNS update      — Azure REST API PUT
├── Retry           — exponential backoff with jitter
├── State           — tmpfs JSON persistence
└── Entry point     — oneshot (systemd timer) or daemon (while-loop)
```

- **Runtime**: Node.js 18+ (ESM, `.mjs`) — requires native `fetch()`
- **Dependencies**: Zero — hard constraint, no npm packages allowed
- **Deployment**: systemd timer + oneshot service on Raspberry Pi
- **State**: tmpfs (`/run/ns4j/`) to avoid SD card wear
- **Auth**: Azure service principal (client credentials OAuth2 flow)
- **API**: Azure DNS REST API `2018-05-01` — direct PUT, no SDK

## File Structure

| File | Purpose |
|------|---------|
| `index.mjs` | Entire application — single entry point |
| `systemd/ns4j.service` | systemd oneshot service (security-hardened) |
| `systemd/ns4j.timer` | 5-minute interval timer with `Persistent=true` |
| `.env.example` | Configuration template with all env vars |
| `install.sh` | One-command Pi deployment script |
| `package.json` | Metadata only — no dependencies |
| `.github/workflows/claude-code-review.yml` | Claude Code CI bot |

## Code Standards

- ESM modules only — no CommonJS, no `require()`
- No external npm dependencies — this is a **hard constraint**
- Use only native Node.js APIs: `fetch`, `crypto`, `fs`, `path`
- Prefer `const` and `Object.freeze()` for configuration
- Keep total codebase under 500 lines
- Use `HttpError` class for all HTTP failure paths
- Validate env vars at startup — fail fast with actionable errors

## Key Design Patterns

### IP Detection

IP changes are detected via external HTTP services with cascading failover.
When a change is detected, a **different** service must confirm it before
updating DNS. This prevents false positives from a single misbehaving service.

### Token Management

OAuth2 tokens are cached in the state file (tmpfs) and reused across timer
invocations. Tokens are refreshed 5 minutes before expiry. On reboot the
state is lost, so the first run always acquires a fresh token.

### Error Handling

- `HttpError` class carries the HTTP status code for typed error matching
- `withRetry()` uses exponential backoff with jitter (3 attempts: ~5s, ~10s, ~20s)
- Auth errors (401/403) are never retried — they indicate config problems
- Network timeouts and 5xx errors are retried

### Daemon Mode

Uses a serial `while (true) { await tick(); await sleep(); }` loop — never
`setInterval` — to prevent overlapping runs when a cycle takes longer than
the check interval.

## Review Criteria

### Security (MUST PASS)

- No hardcoded credentials or secrets
- Azure credentials only via environment variables
- Validate all external input (IP addresses, API responses)
- Use HTTPS for all external requests
- URL-encode all path segments in Azure API URLs
- systemd service must use `ProtectSystem=strict` and `NoNewPrivileges=yes`

### Reliability (MUST PASS)

- All network calls must have timeouts (`AbortController`)
- Retry logic with exponential backoff for transient failures
- Never retry authentication errors (401/403)
- IP changes must be confirmed by a **second, different** service before updating
- Daemon mode must use serial scheduling (no overlapping runs)
- Forced DNS refresh every 24 hours even if IP hasn't changed

### Lightweight (MUST PASS)

- No npm dependencies added — zero `node_modules`
- Minimal memory footprint (~15-25 MB RSS)
- No unnecessary file writes (SD card wear)
- State stored in tmpfs only

### Code Quality

- Functions should have a single responsibility
- Error messages must be actionable (include HTTP status, service URL, etc.)
- Logging must include ISO timestamps and levels (`info`/`warn`/`error`)
- Numeric env vars must be validated with `Number.isFinite()`
- IPv4 addresses must be validated with octet range checks (0-255)

## Testing

No test framework — keep it zero-dependency. Validate with:

```bash
node --check index.mjs                          # syntax check
sudo systemctl start ns4j.service               # manual run
journalctl -u ns4j.service -f                   # watch logs
systemctl list-timers ns4j.timer                # verify timer
```

## Common Tasks

### Adding a new IP detection service

Add the URL to the `IP_SERVICES` array in `index.mjs`. Services are tried
in order — place more reliable services first. All services must return a
plain-text IPv4 address (optionally with trailing whitespace).

### Changing the check interval

Set `CHECK_INTERVAL_MS` in `/etc/ns4j/.env`. Default is `300000` (5 min).
The TTL (`DNS_TTL`) should match or exceed this interval.

### Debugging auth failures

Check `journalctl -u ns4j.service` for `HTTP 401` or `HTTP 403` errors.
Verify the service principal credentials in `/etc/ns4j/.env` and ensure
the RBAC role is assigned at the DNS zone scope.
