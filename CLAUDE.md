# ns4j — Project Guidelines

## Project Overview
Zero-dependency Azure DDNS client for Raspberry Pi. Updates Azure DNS A-records
when the public IP address changes. Designed for systemd timer (oneshot) or
standalone daemon mode.

## Architecture
- **Runtime**: Node.js 18+ (ESM, `.mjs`)
- **Dependencies**: Zero — uses native `fetch()` only
- **Deployment**: systemd timer + oneshot service on Raspberry Pi
- **State**: tmpfs (`/run/ns4j/`) to avoid SD card wear

## Code Standards
- ESM modules only (no CommonJS)
- No external npm dependencies — this is a hard constraint
- Use native Node.js APIs (`fetch`, `crypto`, `fs`, `path`)
- Prefer `const` and `Object.freeze()` for configuration
- Keep total codebase under 500 lines

## Review Criteria

### Security (MUST PASS)
- No hardcoded credentials or secrets
- Azure credentials only via environment variables
- Validate all external input (IP addresses, API responses)
- Use HTTPS for all external requests

### Reliability (MUST PASS)
- All network calls must have timeouts
- Retry logic with exponential backoff for transient failures
- Never retry authentication errors (401/403)
- IP changes must be confirmed by a second service before updating DNS

### Lightweight (MUST PASS)
- No npm dependencies added
- Minimal memory footprint
- No unnecessary file writes (SD card wear)

### Code Quality
- Functions should have a single responsibility
- Error messages must be actionable
- Logging must include timestamps and levels
