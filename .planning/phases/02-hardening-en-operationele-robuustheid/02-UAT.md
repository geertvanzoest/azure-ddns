---
status: complete
phase: 02-hardening-en-operationele-robuustheid
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md]
started: 2026-03-31T09:42:00Z
updated: 2026-03-31T09:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Verbose debug modus

expected: `VERBOSE=1 ./ns4j --force 2>&1` toont DEBUG-regels. `VERBOSE=1 ./ns4j --force 2>&1 | grep -i secret` mag GEEN output geven (secret niet gelekt).
result: pass

### 2. flock locking: concurrent execution preventie

expected: Twee gelijktijdige instanties: de tweede toont "Andere instantie draait, overgeslagen" en exit 0. Test: `./ns4j --force & ./ns4j --force; wait`
result: pass

### 3. Onbekende optie afwijzen

expected: `./ns4j --onzin 2>&1` toont "Onbekende optie: --onzin" op stderr en exit code 1.
result: pass

### 4. Test suite draait succesvol

expected: `bats test/` in de Docker container draait alle 27 tests. Resultaat: 24 ok, 3 skipped (flock tests op macOS). Op Linux: alle 27 ok.
result: pass

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
