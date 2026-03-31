# Roadmap: ddns4j

## Milestones

- **v1.0 Azure DNS Dynamic Updater** — Phases 1-2 (shipped 2026-03-31) — [archive](milestones/v1.0-ROADMAP.md)
- **v1.1 ddns4j — CI, Docs & Rename** — Phases 3-5 (in progress)

## Phases

<details>
<summary>v1.0 Azure DNS Dynamic Updater (Phases 1-2) — SHIPPED 2026-03-31</summary>

- [x] Phase 1: Werkend kern-script (1/1 plan) — completed 2026-03-31
- [x] Phase 2: Hardening en operationele robuustheid (2/2 plans) — completed 2026-03-31

</details>

### v1.1 ddns4j — CI, Docs & Rename

- [ ] **Phase 3: Rename naar ddns4j** - Script, interne referenties en tests hernoemen van ns4j naar ddns4j
- [ ] **Phase 4: CI pipeline** - GitHub Actions workflow die bats tests automatisch draait
- [ ] **Phase 5: Documentatie** - README en gebruikersdocumentatie voor zelfstandige overdracht

## Phase Details

### Phase 3: Rename naar ddns4j

**Goal**: Het project draait volledig onder de naam ddns4j — script, lock files, logs, en tests refereren nergens meer aan ns4j
**Depends on**: Phase 2 (v1.0 shipped)
**Requirements**: REN-01, REN-02, REN-03
**Plans:** 1 plan

Plans:
- [ ] 03-01-PLAN.md — Hernaam script, lock file en test suite van ns4j naar ddns4j

**Success Criteria** (what must be TRUE):

  1. Het script-bestand heet `ddns4j` en is uitvoerbaar
  2. Lock file, log output en variabelenamen bevatten `ddns4j` in plaats van `ns4j`
  3. Alle bats tests draaien tegen `ddns4j` en slagen

### Phase 4: CI pipeline

**Goal**: Elke push en PR wordt automatisch gevalideerd door de test suite op een schone Linux-omgeving
**Depends on**: Phase 3
**Requirements**: CI-01, CI-02

**Success Criteria** (what must be TRUE):

  1. Een push naar een branch triggert automatisch een GitHub Actions workflow die alle bats tests draait
  2. Een pull request toont een groen/rood CI-status check
  3. De CI-omgeving is Ubuntu met bash, curl, jq en bats-core beschikbaar

**Plans**: TBD

### Phase 5: Documentatie

**Goal**: Een Pi-beheerder kan ddns4j zelfstandig installeren, configureren en troubleshooten zonder hulp van de ontwikkelaar
**Depends on**: Phase 4
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05

**Success Criteria** (what must be TRUE):

  1. README.md bevat een project-overzicht, feature-lijst en quick start sectie
  2. Een nieuwe gebruiker kan het script installeren door de installatie-instructies stap voor stap te volgen
  3. Configuratie-instructies beschrijven het volledige pad: Azure Service Principal aanmaken, RBAC-rol toekennen, env vars instellen
  4. Gebruiksinstructies tonen handmatig draaien, cron job instellen, --force en VERBOSE=1
  5. Troubleshooting sectie documenteert alle exit codes (0-4) met oorzaken en oplossingen

**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
| ----- | --------- | -------------- | ------ | --------- |
| 1. Werkend kern-script | v1.0 | 1/1 | Complete | 2026-03-31 |
| 2. Hardening en operationele robuustheid | v1.0 | 2/2 | Complete | 2026-03-31 |
| 3. Rename naar ddns4j | v1.1 | 0/1 | Planned | - |
| 4. CI pipeline | v1.1 | 0/? | Not started | - |
| 5. Documentatie | v1.1 | 0/? | Not started | - |
