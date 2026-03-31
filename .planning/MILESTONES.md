# Milestones

## v1.1 ddns4j — CI, Docs & Rename (Shipped: 2026-03-31)

**Phases completed:** 3 phases, 3 plans, 4 tasks

**Key accomplishments:**

- Script hernoemd van ns4j naar ddns4j met lock file pad update en volledige test suite migratie (27/27 tests groen)
- GitHub Actions workflow met bats-core test suite op ubuntu-latest, getriggerd door push en pull request
- Complete README.md in het Nederlands met Azure SP setup, env vars, cron, exit codes en troubleshooting voor Pi-beheerders

---

## v1.0 Azure DNS Dynamic Updater (Shipped: 2026-03-31)

**Phases completed:** 2 phases, 3 plans, 6 tasks

**Key accomplishments:**

- Compleet ns4j DDNS-client script: OAuth2 auth, IP-detectie via icanhazip.com, Azure DNS GET/PUT met fail-fast config validatie en gestructureerde logging
- IPv4-validatie, fallback IP-service cascade, flock locking, --force flag en verbose debug modus in ns4j script
- 27 bats-core unit tests over 6 bestanden die alle Phase 2 hardening requirements valideren met PATH-based curl mocks

---
