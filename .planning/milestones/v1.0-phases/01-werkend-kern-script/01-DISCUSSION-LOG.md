# Phase 1: Werkend kern-script - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-31
**Phase:** 01-werkend-kern-script
**Areas discussed:** Log output formaat, Env var validatie, Eerste-keer gedrag, Script bestandsnaam

---

## Log output formaat

| Option | Description | Selected |
|--------|-------------|----------|
| Gestructureerd + routing | [TIMESTAMP] LEVEL: bericht — INFO/SKIP naar stdout, ERROR naar stderr. Cron mailt alleen bij fouten. | ✓ |
| Gestructureerd alleen | [TIMESTAMP] LEVEL: bericht — alles naar stdout, geen split. | |
| Minimaal | Alleen berichten zonder prefix of timestamp. | |

**User's choice:** Gestructureerd + routing (recommended)
**Notes:** Combineert leesbaarheid met operationele stilte bij succes.

---

## Env var validatie aanpak

| Option | Description | Selected |
|--------|-------------|----------|
| Alle ontbrekende tegelijk | Loop over alle 7 vars, toon elke ontbrekende met beschrijving, dan exit 1. | ✓ |
| Stop bij eerste ontbrekende | Eenvoudigste: check per var, stop zodra er een mist. | |
| Gegroepeerd met samenvatting | Alle fouten + samenvattingsregel ('2 van 7 ontbreken'). | |

**User's choice:** Alle ontbrekende tegelijk (recommended)
**Notes:** Past bij CFG-02 requirement en voorkomt iteratief trial-and-error bij onboarding.

---

## Eerste-keer gedrag

| Option | Description | Selected |
|--------|-------------|----------|
| GET + 404-als-nieuw | GET het record. 200 = vergelijk IP. 404 = record nieuw, altijd PUT. Andere fouten = abort. | ✓ |
| Altijd PUT, skip GET | Elke run doet direct een PUT. Simpelst, maar geen skip-bij-ongewijzigd mogelijk. | |

**User's choice:** GET + 404-als-nieuw (recommended)
**Notes:** Azure CreateOrUpdate endpoint handelt create en update af. 404 wordt geinterpreteerd als "record nog niet aanwezig".

---

## Script bestandsnaam

| Option | Description | Selected |
|--------|-------------|----------|
| ns4j in root | Bestandsnaam 'ns4j' (zonder extensie) in de repo-root. Shebang #!/bin/bash. | ✓ |
| ns4j.sh in root | Met .sh extensie in de root. Herkenbaar als shell script. | |
| bin/ns4j | Zonder extensie in bin/ map. Unix-conventie, makkelijk te symlinken. | |
| update-azure-dns in root | Zelfverklarende naam, losgekoppeld van projectnaam. | |

**User's choice:** ns4j in root (recommended)
**Notes:** Consistente branding met repo-naam, geen extensie volgt Unix-conventie.

---

## Claude's Discretion

- Script interne structuur (functies vs lineair)
- Exact timestamp formaat
- Variabele naamgeving binnen het script

## Deferred Ideas

None — discussion stayed within phase scope.
