# Review RV-008 — design of SL-003

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Scope: the post-lock amendment of design § 5.2 (`--view-redraw` point
fallback) and § 5.4 (view show/refresh report, messages table row), made
on the user's rulings on RV-007 F-6 and F-9 (2026-10-03: "1. agreed
2. accept"). Checked: the diff touches only those two sections; no other
section (§ 5.5 invariants, § 9 tests, § 10 code impact) contradicts it;
the report reuses `org-iw--report` and adds no new owner.

## Synthesis

**Overall:** solid. Zero findings: two small, user-ruled amendments,
consistent with the rest of the design.

