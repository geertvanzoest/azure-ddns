# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| latest (main) | Yes |
| < latest | No |

## Reporting a vulnerability

Found a security issue in azure-ddns? Do **not** report it via a public issue.

**Submit a private report via GitHub:**

1. Go to [Security Advisories](https://github.com/geertvanzoest/azure-ddns/security/advisories)
2. Click **"New draft security advisory"**
3. Describe the issue, its impact, and any steps to reproduce

You will receive a response within 7 days.

## Scope

Relevant reports:
- Credential leakage (e.g. AZURE_CLIENT_SECRET in logs/output)
- Command injection via environment variables
- Insecure file permissions (lock file, env file)
- HTTPS downgrade or certificate validation bypass

Out of scope:
- Denial of service on external IP services (icanhazip.com, checkip.amazonaws.com)
- Azure API rate limiting
- Issues in dependencies (bash, curl, jq) — report those upstream
