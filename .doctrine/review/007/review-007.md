# Review RV-007 — code-review of SL-003

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Scope: SL-003 PHASE-04..06, diff 6b06c30..83885ef (org-iw.el, tests,
test helpers). The write layer is untouched in this range.
Roster per STD-003 (per-phase review before PHASE-07 builds on the view):
modelling/architecture reviewer (opus), test reviewer (opus, mutation
pass), verifier (sonnet). Reviewers are read-only; the seat writes the
ledger.

Lines of attack:
- Design conformance (§ 5.2 interfaces, § 5.4 messages, § 5.5 I10'..I14):
  Move, Remove, Continue's Remove, view display/open/refresh.
- POL-002 / I14: one placer, one deleter, one owner each for session
  hint, removed/empty texts; the five helpers PHASE-05 added outside
  § 5.2 (--removed-text, --entry-marker, --queue-at-point, --empty-text,
  --scanned-entry-at QUEUE) — earned, or near-duplicates?
- Continue split into --continue-place / --continue-remove: SL-002
  behaviour preserved; session semantics after a delete.
- View: window point vs buffer point after RET and g (RV-005 F-1 probe
  real); tabulated-list lifecycle; buffer naming; what PHASE-07 inherits.
- OQ-1: non-empty list-queue reports no source problems — design gap or
  defect?
- Tests (STD-001/002): PHASE-04 had no recorded red run — mutation pass
  stands in; fixture changes (view buffers killed, save-window-excursion)
  sound for every test; no theatre; isolation.

