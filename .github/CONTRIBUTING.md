# Bijdragen aan azure-ddns

Bedankt voor je interesse in het bijdragen aan azure-ddns!

## Bugs melden

Open een [issue](https://github.com/geertvanzoest/azure-ddns/issues) met:

1. Wat je verwachtte
2. Wat er gebeurde (inclusief volledige output met `VERBOSE=1`)
3. Je omgeving (OS, bash versie, curl versie)

## Code bijdragen

1. Fork de repo
2. Maak een feature branch (`git checkout -b feature/mijn-verbetering`)
3. Zorg dat tests slagen: `bats test/`
4. Commit met een duidelijke beschrijving
5. Open een Pull Request

## Code richtlijnen

- Bash 4.x compatible
- Gebruik `shellcheck` als dat beschikbaar is
- Voeg tests toe voor nieuwe functionaliteit (bats-core)
- Houd het simpel — dit is een single-file script voor een Pi

## Tests draaien

```bash
# Lokaal (Linux)
bats test/

# Via Docker (macOS)
docker run --rm -it -v "$(pwd)":/app -w /app debian:bookworm-slim bash
apt-get update && apt-get install -y curl jq bats && bats test/
```

## Beveiligingsproblemen

Meld beveiligingsproblemen **niet** via een publieke issue. Gebruik in plaats daarvan een [privé security advisory](https://github.com/geertvanzoest/azure-ddns/security/advisories).
