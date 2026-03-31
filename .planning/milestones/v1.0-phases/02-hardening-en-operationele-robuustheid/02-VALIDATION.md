---
phase: 2
slug: hardening-en-operationele-robuustheid
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-31
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bats-core >= 1.10 |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `bats test/` |
| **Full suite command** | `bats test/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bats test/`
- **After every plan wave:** Run `bats test/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 0 | ALL | infra | `bats test/` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | IP-02 | unit | `bats test/test_ip_validation.bats` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | IP-04 | unit | `bats test/test_ip_fallback.bats` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | OPS-03 | integration | `bats test/test_locking.bats` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 1 | OPS-04 | unit | `bats test/test_force_flag.bats` | ❌ W0 | ⬜ pending |
| 02-01-06 | 01 | 1 | OPS-05 | unit | `bats test/test_verbose.bats` | ❌ W0 | ⬜ pending |
| 02-01-07 | 01 | 1 | DNS-03 | unit | `bats test/test_ttl.bats` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/` directory aanmaken
- [ ] bats-core installeren: `brew install bats-core` (macOS dev) / `apt install bats` (Pi)
- [ ] Test helper: guard `main "$@"` met `[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"`
- [ ] `test/test_ip_validation.bats` — stubs for IP-02
- [ ] `test/test_ip_fallback.bats` — stubs for IP-04 (vereist curl mock)
- [ ] `test/test_locking.bats` — stubs for OPS-03 (flock, alleen Linux)
- [ ] `test/test_force_flag.bats` — stubs for OPS-04
- [ ] `test/test_verbose.bats` — stubs for OPS-05
- [ ] `test/test_ttl.bats` — stubs for DNS-03

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| flock werkt op Raspberry Pi | OPS-03 | flock niet beschikbaar op macOS (util-linux only) | Test op Pi: `./ns4j & ./ns4j` — tweede instantie moet WARN loggen en exit 0 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
