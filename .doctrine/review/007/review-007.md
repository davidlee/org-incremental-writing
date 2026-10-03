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


## Synthesis

**Overall:** acceptable.

**Synopsis.** PHASE-04..06 add Move, Remove (from the source and from
Continue) and the queue view's display, open and refresh. They follow
the locked design closely. I10′ and I14 hold: ranks come only from the
core, and every move goes through `--move`. ADR-003 layering holds, and
the helpers PHASE-05 added outside § 5.2 each own one concept. The
RV-005 F-1 probe (window point after RET) is real: removing the
`set-window-point` step fails three tests.

There was one user-facing defect (F-12): an entry whose line for one
queue was excluded, while it was a valid member of another, was refused
as "not in queue". Interactively this could pick the other queue. It
came from two drifted copies of the "excluded" check, now one helper.
The other findings are test gaps on correct code (F-1, F-5, F-10, F-13),
a third copy of the move text before PHASE-07 (F-2), test-fixture
hazards for interactive ERT (F-3, F-4), and small view robustness fixes
(F-7, F-8, F-11).

Two were design gaps, ruled by the user and amended into the locked
design via RV-008:
- F-6: the view reports its count and scan problems.
- F-9: `g` keeps the line when its row's entry has gone.

All were fixed in 136fe79. Out of scope: ISS-002 and ISS-003.

**Haiku**

    Two checks, one question:
    which queue holds what we excluded?
    Now one voice answers.
