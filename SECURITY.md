# Security Policy

## Ondersteunde versies

| Versie | Ondersteund |
|--------|-------------|
| latest (main) | Ja |
| < latest | Nee |

## Kwetsbaarheid melden

Heb je een beveiligingsprobleem gevonden in azure-ddns? Meld het **niet** via een publieke issue.

**Stuur een privé rapport via GitHub:**

1. Ga naar [Security Advisories](https://github.com/geertvanzoest/azure-ddns/security/advisories)
2. Klik **"New draft security advisory"**
3. Beschrijf het probleem, de impact, en eventuele stappen om te reproduceren

Je ontvangt binnen 7 dagen een reactie.

## Scope

Relevante meldingen:
- Credential leakage (bijv. AZURE_CLIENT_SECRET in logs/output)
- Command injection via environment variables
- Onveilige file permissions (lock file, env file)
- HTTPS downgrade of certificate validatie bypass

Niet in scope:
- Denial of service op externe IP-services (icanhazip.com, checkip.amazonaws.com)
- Azure API rate limiting
- Problemen in dependencies (bash, curl, jq) — meld die upstream
