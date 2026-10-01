# Review RV-004 — reconciliation of SL-002

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Mode: conformance. Surface: the primary tree at 1e91b08; SL-002's code range
is 30b4a8d..HEAD (`org-iw-core.el`, `org-iw.el`, `org-iw-write.el` docstring,
both test files, README). Canon: design.md (locked, dr-01a0f578), DEC-007..011,
ADR-002/003/004, POL-002, STD-001, STD-004.

Roster (STD-003 default): modelling/architecture reviewer (opus), test
reviewer (opus, with a mutation pass), verifier (sonnet; opus if majors or
contested). No legibility reviewer: the slice is not refactor-heavy, but the
mechanical substitutes STD-003 names (private-symbol lint, `just mutate`) are
not in place, so the modelling reviewer also sweeps POL-002 duplication.

Lines of attack:
- I10: every rank from `org-iw-core-rank-at`, every placement decision from
  `org-iw-core-place`; no command computes a depth, rank or neighbour.
- I2′ / I9: unchanged and no-gap outcomes write nothing, navigate nowhere,
  keep the session.
- § 5.4 check order for Continue and Add (session → placement → scan →
  empty → absent → sole → place); refusals before prompts (RV-003 F-7).
- § 5.2 vocabulary contract: plist-member semantics, default resolution,
  refusal sources named (RV-003 F-6).
- Chooser: configured order under icomplete/fido (cycle-sort-function, a
  known design delta from § 5.2's display-sort-function).
- Test oracles: property test both directions, checker self-test, literal
  pins, isolation (`just test-each`).
- Conformance: `org-iw-write.el` undeclared (docstring-only edit vs § 10's
  "untouched").
- Reconcile carry-ins: PRD-001 OQ-3 text (DEC-009); ISS-001 Continue half.

Evidence already in hand: `doctrine check gate` 195/195 on both Emacs;
`just test-each` green; per-phase mutation 22/22, 8/10 (two equivalent,
killed later), 21/21, 11/11, 7/7; VH-1 passed with step 3 waived by the user.
