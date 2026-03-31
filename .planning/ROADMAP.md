# Roadmap: ns4j

## Overview

ns4j is een bash script dat als DDNS-client werkt voor Azure DNS. De roadmap bestaat uit twee fasen: eerst een volledig werkend kern-script dat het publieke IP detecteert en het Azure DNS A-record bijwerkt via de REST API, daarna hardening met IP-validatie, fallback-service, lock file, en operationele flags die het script productieklaar maken voor onbeheerde cron-uitvoering op een Raspberry Pi.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Werkend kern-script** - Volledige happy path: config-validatie, Azure auth, IP-detectie, DNS GET/PUT
- [ ] **Phase 2: Hardening en operationele robuustheid** - IP-validatie, fallback, lock file, --force, verbose, TTL-config

## Phase Details

### Phase 1: Werkend kern-script
**Goal**: Gebruiker kan het script draaien via cron en het Azure DNS A-record wordt automatisch bijgewerkt wanneer het publieke IP wijzigt
**Depends on**: Nothing (first phase)
**Requirements**: IP-01, IP-03, AUTH-01, AUTH-02, DNS-01, DNS-02, CFG-01, CFG-02, OPS-01, OPS-02
**Success Criteria** (what must be TRUE):
  1. Script haalt het publieke IP op en update het Azure DNS A-record wanneer het IP gewijzigd is
  2. Script skipt de update wanneer het IP ongewijzigd is ten opzichte van het huidige DNS-record
  3. Script weigert te starten wanneer een verplichte env var ontbreekt, met beschrijvende foutmelding per variabele
  4. Script geeft exit code 0 bij succes, en specifieke non-zero codes (1-4) bij verschillende fouttypen
  5. Succesberichten verschijnen op stdout, fouten op stderr
**Plans**: 1 plan

Plans:
- [ ] 01-01-PLAN.md -- Bouw het complete ns4j script met alle functies en validatie

### Phase 2: Hardening en operationele robuustheid
**Goal**: Script is productieklaar voor onbeheerde cron-uitvoering met bescherming tegen edge cases en debugging-mogelijkheden
**Depends on**: Phase 1
**Requirements**: IP-02, IP-04, DNS-03, OPS-03, OPS-04, OPS-05
**Success Criteria** (what must be TRUE):
  1. Script valideert het opgehaalde IP met een IPv4 regex en weigert ongeldige waarden door te sturen naar Azure
  2. Script valt automatisch terug op een alternatieve IP-service wanneer de primaire faalt
  3. Script voorkomt gelijktijdige uitvoering via flock lock file
  4. Script ondersteunt --force om altijd te updaten en VERBOSE=1 voor extra debug output
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md -- Implementeer alle hardening-features in het ns4j script (IP-validatie, fallback, flock, --force, verbose)
- [ ] 02-02-PLAN.md -- Schrijf bats-core test suite voor alle Phase 2 requirements

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Werkend kern-script | 0/1 | Not started | - |
| 2. Hardening en operationele robuustheid | 0/2 | Not started | - |
