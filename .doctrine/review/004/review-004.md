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

## Synthesis

SL-002 matches its locked design in substance. The core owns every
placement decision and rank (I10): `org-iw-core-place` and `rank-at` are
the only places depth, neighbour and rank are computed, and `append-rank`,
`org-iw--append-rank` and `org-iw--move-to-end` are gone (POL-002). Both
commands write only through `org-iw-write-put-rank` with `:expected`
(ADR-002). Continue's check order, messages and session handling follow
§ 5.4. The vocabulary follows § 5.2, and every refusal names the option at
fault. The chooser keeps configured order under default completion,
icomplete and fido on 30.2 and 31.1 (checked in a real terminal), with the
default first where the UI floats it, as DEC-011 accepts.

The audit found no user-visible defect and no blocker. Its yield was in
the evidence:

- **Plan evidence was stale.** Two PHASE-02 VT rows failed after PHASE-04
  changed the messages, and seven rows keyed on message text against
  STD-002 item 1 (F-1). The re-keyed rows now name tests.
- **One oracle arm was untested.** The property checker's `moved` arm could
  be deleted with the suite still green (F-2). Its generator coverage was
  unguarded (F-9). Two SL-001 oracles had no self-test, and four overlapped
  (F-8).
- **Four behaviours were correct but unpinned:** plain Add with a non-End
  default (F-4), C-u Add with an invalid queue (F-6), Add's placement before
  the scan (F-7), and dotted placement lists and label case (F-10, F-12).
- **One POL-002 duplicate:** the empty-queue report (F-3).
- **Docstring drift (F-5):** Continue's refusal list. The PHASE-04 note had
  recorded ISS-001's Continue half as fixed too early; it is fixed now.

All fix-now items landed in 0341dd7. A targeted rerun killed every mutant
that had survived (19 of 19). Gate: 200/200 on both Emacs, lint clean,
test-each green, verify-vt clean.

Tradeoffs consciously accepted:

- The Customize types admit values that are refused on use (F-13). This
  follows design § 4, and IMP-004/SL-005 own load-time diagnostics.
- `rank-at` trusts its documented DEPTH precondition (F-14).
- C-u Add is chooser-tested with Later only (F-16).
- Duplicate case-variant queue keys are folded into IMP-004 (F-15).

Standing risks:

- **Hot-spot exhaustion (EVD-002).** About ten repeated Soons hit "no
  room" until SL-006. The refusal is tested at both commands; the user
  waived the trial's exhaustion step (PHASE-05 VH-1, step 3).
- **Vertico** was not available to check. It is expected to behave like
  icomplete (it floats the default and honours cycle-sort-function), but
  that is unverified.
- **ISS-001's put-rank half** stays open.

Roster per STD-003: opus modelling/architecture reviewer, opus test
reviewer (99-mutant pass), and an opus verifier because majors were
present. No legibility reviewer: the slice is not refactor-heavy, and the
modelling reviewer swept POL-002. Reviewer scratch is under
`/home/scratch/sl-002/review/` and the audit's under
`/home/scratch/sl-002/audit/`.

## Reconciliation Brief

### Per-slice (direct edit)

- **F-17, selectors (load-bearing).** Run `doctrine slice selector add` on
  SL-002 for `org-iw-write.el` with intent `design-target`, so `slice
  conformance` reads it as declared. Mirror the change in design.md:
  - § 10: add a row, "`org-iw-write.el` | docstring cites
    `org-iw-core-rank-at` (POL-002, after `append-rank`'s deletion)".
  - § 2 ("need no change") and § 5.1 ("write untouched"): qualify both as
    "no behavioural change".
- **F-18, design.md § 5.2 and § 8.** `org-iw--read-placement`'s table
  metadata sets both `display-sort-function` and `cycle-sort-function` to
  `identity`. Say so in both sections, with the reason: icomplete and fido
  order candidates through `cycle-sort-function` in
  `completion-all-sorted-completions`.
- **slice-002.md:** no edit. Its closure trial (each choice on a
  configured and an unconfigured queue) was met by VH-1 steps 1 and 2.

### Governance/spec (REV)

- **F-19, PRD-001 OQ-3.** REV modify: mark it settled by DEC-009 — Soon
  `(after 2)`, Later `(fraction 1 2)`, End `end`, in that chooser order,
  default End — and implemented by SL-002.
