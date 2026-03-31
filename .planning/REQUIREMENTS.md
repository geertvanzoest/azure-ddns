# Requirements: ddns4j (v1.1)

**Defined:** 2026-03-31
**Core Value:** Het Azure DNS A-record is altijd actueel met het huidige publieke IP-adres van het thuisnetwerk.

## v1.1 Requirements

Requirements for rename, CI, and documentation milestone.

### Rename

- [x] **REN-01**: Script-bestand hernoemen van `ns4j` naar `ddns4j`
- [x] **REN-02**: Alle interne referenties naar ns4j (lock file, log output, variabelen) hernoemen naar ddns4j
- [x] **REN-03**: Test suite aangepast aan de nieuwe scriptnaam ddns4j

### CI

- [x] **CI-01**: GitHub Actions workflow die bats tests automatisch draait bij push en PR
- [x] **CI-02**: CI draait op Linux (Ubuntu) met bash, curl, jq en bats-core geinstalleerd

### Documentatie

- [ ] **DOC-01**: README.md met project-overzicht, features, en quick start
- [ ] **DOC-02**: Installatie-instructies: dependencies, script plaatsen, permissions
- [ ] **DOC-03**: Configuratie-instructies: Azure Service Principal aanmaken, env vars instellen
- [ ] **DOC-04**: Gebruiksinstructies: handmatig draaien, cron job instellen, --force, VERBOSE=1
- [ ] **DOC-05**: Troubleshooting: exit codes, veelvoorkomende fouten, debug modus

## Future Requirements

Deferred from v1.0:

- **OPS-06**: Dry-run modus (--dry-run)
- **OPS-07**: Retry logica bij tijdelijke fouten
- **OPS-08**: Token caching
- **OPS-09**: Versie-informatie (--version flag)

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| GitHub repo rename | Handmatig door eigenaar via GitHub Settings |
| man page | README + troubleshooting volstaat |
| Automatische releases/packaging | Overkill voor een enkel script |
| Meertalige documentatie | Nederlands is de doeltaal |

## Traceability

| Requirement | Phase | Status |
| ----------- | ----- | ------ |
| REN-01 | Phase 3 | Complete |
| REN-02 | Phase 3 | Complete |
| REN-03 | Phase 3 | Complete |
| CI-01 | Phase 4 | Complete |
| CI-02 | Phase 4 | Complete |
| DOC-01 | Phase 5 | Pending |
| DOC-02 | Phase 5 | Pending |
| DOC-03 | Phase 5 | Pending |
| DOC-04 | Phase 5 | Pending |
| DOC-05 | Phase 5 | Pending |

**Coverage:**

- v1.1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---

*Requirements defined: 2026-03-31*
