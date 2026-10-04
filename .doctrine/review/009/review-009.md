# Review RV-009 — code-review of SL-003

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

Scope: SL-003 PHASE-07, diff 7f86726..4f212ee (org-iw.el, test/org-iw-test.el,
README.md). Roster per STD-003 (per-phase review before the PHASE-08 human
trial): modelling/architecture reviewer (opus), test reviewer (opus, mutation
pass), verifier (sonnet). Reviewers are read-only; the seat writes the ledger.

Lines of attack:
- Design conformance (§ 5.2 interfaces, § 5.4 view keys and messages, § 5.5
  invariants): reorder, mark and b/a, D with confirmation, the mark across g
  (RV-005 F-2, PHASE-07/EX-4).
- The orchestrator's rulings A1..A7 where the design is silent (mark tag ">",
  silent m/u, n to D writes nothing, b/a off-row refusal order, plain
  buffer-local mark): sound, or do they contradict the design's spirit?
- POL-002: --view-move shared by up/down and b/a; --view-set-mark as sole
  owner of mark display; --moved-text reuse with nil WHERE; any new
  duplication (IMP-006 already captures Add's position text).
- ADR-002/003: D and b/a write through the mutation layer; stale-row
  handling (the row's entry changed or gone since the last redraw).
- Tests (STD-001/002): T8 tests written after the code (no red run); the
  y-or-n-p recorder's single "Answer of the wrong kind" failure; fixtures
  isolation; mutation pass over mark, b/a and D.
- README: accuracy against the shipped behaviour and design § 10 / DEC-015;
  the out-of-row edits the worker made.

## Synthesis

**Overall:** solid.

**Synopsis.** PHASE-07 adds the view's reorder (up/down), mark and place
before/after (b/a), D with confirmation, and the README. It follows the
locked design closely:
- the keymap and every message and refusal text match § 5.2 and § 5.4;
- the orchestrator's rulings A1–A7, where the design is silent, are sound;
- every view write goes through `--move`, `--put-rank` or `--delete-rank`
  (ADR-002/003, I12, I14);
- `--moved-text`, `--view-set-mark` and `--view-move` are single owners
  (POL-002);
- the EX-4 negative control (RV-005 F-2) holds.

There was one user-visible defect (F-1): tabulated-list's inherited `{`/`}`
reprint the buffer, erasing the mark's tag while `b`/`a` still used the
mark. It was the RV-005 F-2 failure through another reprint path. The fix
draws the tag from the row printer, so every reprint shows it. The
`--view-redraw` text in § 5.2 ("re-tags the mark") still holds in effect;
the re-tag now happens inside the print. Note it at reconciliation.

The rest were test gaps on correct code (F-2, F-3; mutants survived), a
repeated four-line prelude (F-4), a misleading name (F-5) and two
over-broad README claims (F-6). A 36-mutant pass killed 33 before the fix;
the three survivors are now killed. The prompt recorder's tolerance of
unused answers predates the phase and went to IMP-007. All fixed in
409272b; 329/329 on Emacs 31.1 and 30.2.

**Haiku.**

    Brace keys widen rows;
    the small arrow slipped away.
    Now the printer draws.
