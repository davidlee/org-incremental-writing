# Review RV-002 — reconciliation of SL-001

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Subject: SL-001 as landed on `main` (primary tree), PHASE-01..08,
ce0b766^..e3c5f16 plus PHASE-01 (405af23, 31e311c). Mode: conformance.
Pre-close review; code-review lens per the user's request (2026-10-01).

Held to: design.md (locked, rev 38), plan.toml EX/VT (including routed
RV-001 F-n), ADR-001 (queue state on the entry), ADR-002 (visiting
buffers, single writer), ADR-003 (four layers, fixed direction), POL-001
(lint and test gate), POL-002 (one implementation per concept), POL-003
(human trial).

Lines of attack (three reviewers in parallel, then one verifier):

1. Modelling and architecture: entry / problem / scan / session model;
   rank and append semantics; refusal taxonomy; invariants and where they
   are enforced; layering and public/private boundaries (commands call
   discovery `--` helpers across files); error handling; design letter
   and spirit.
2. Legibility, factoring, DRY: function length and branching
   (Continue), cohesion of `org-iw.el` and `org-iw-discovery.el`, naming,
   parallel implementations (POL-002).
3. Test suite quality: behaviour vs implementation, theatre, coverage of
   the significant risks (write path, supersession, indirect buffers,
   RV-001 cases), fixtures and helpers, test DRY, brittleness (e.g.
   docstrings restating literals for `verify-vt`). Forward-looking: test
   strategy for the next ~10 slices.
4. Verifier: re-checks every candidate against the cited lines or by
   execution; proposes missing governance for code quality.

Mechanical leads (`slice conformance`): undeclared `justfile`,
`README.md`, notes/observations; undelivered `Makefile`, `flake.nix`.
Gate: `doctrine check gate` green, 135/135 on Emacs 31.1 and 30.2.
