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

## Synthesis

**Overall: solid.**

**Synopsis.** SL-001 delivers the first vertical slice of org-iw: a pure
ordering core, discovery (file selection, scan, ID resolution), one write
path through visiting buffers, and the Add / Visit / Continue / End
commands with a mode-line session. It passed the user's VH-1 trial on
their real notes, and is usable as is.

Three opus reviewers (modelling and architecture; legibility, factoring
and DRY; tests plus forward strategy) and one opus verifier produced 26
findings. None is a blocker or a major. The verifier confirmed 24 of 25
candidates; one was a duplicate (T6 = F-1), and part of another (F-22,
the stub claims) was refuted.

What the review found, by theme:
- **Write safety and ownership.** Read-only buffers were written (F-1).
  The second-drawer guard sat in Add rather than the one write path (F-2),
  a hazard for SL-004's batch add. Org calls ran in non-Org buffers (F-3).
  RANK was unchecked, so a float could silently drop an entry (F-6). Scan
  and Org readers lived in the command layer, against ADR-003 (F-11), and
  one classification rule sat in discovery instead of core (F-15).
- **POL-002 drift.** Three refusal constructors, two queue-ID owners and
  three base-buffer expressions (F-7..F-9). The reviewers proposed
  follow-up despite POL-002 making duplication blocking; the user ruled
  fix now.
- **Test oracles.** One test was order-dependent (F-17). Four plausible
  bugs shipped green (F-18). The "nothing changed" helpers were untested,
  so the I1/I7 assertions could go vacuous (F-19).

20 findings were fixed in this unit: 5846207..31fdb54 and 8ac1d0b. The
fix for F-3 was extended to Add by user ruling. The gate is green: lint
has zero warnings, and 158/158 tests pass on Emacs 31.1 and 30.2.
Re-anchored mutation testing kills 71/79 mutants, up from 63/80. All
named probes are killed, and the surviving mutants are equivalent apart
from A16, the double scan.

Deferred: F-4 to IMP-004 (SL-005), F-5 to IMP-002 (SL-004), F-24 to
IMP-003. Tolerated: F-20 (VT keywords met by prose, plan criteria
immutable) and F-23 (exact message assertions pin designed text).

**Standing risks.**
- Interactive commands scan twice (IMP-002 / F-5); DEC-003's cost
  envelope holds only if SL-004 fixes it.
- `verify-vt` keyword matching can be met by prose (F-20). Future VTs
  need a rule that rejects that.
- 22 exact-message assertions will churn when SL-005 rewrites the
  messages (F-23).
- The display surface is fixed to `global-mode-string` (IMP-001), so
  custom mode lines such as lambda-line can't show the session.

**Tradeoffs accepted.**
- put-rank's QUEUE contract narrowed to canonical IDs, a public API change
  with no caller affected.
- Resolve's refusal for a non-Org buffer drops the ID prefix, so Add and
  resolve share one message.
- `org-iw-discovery-buffer` keeps its name (public, named in design §5.2).

**Proposed governance** (not findings; for the user, after reconcile).
Detail is in /home/scratch/sl-001-review/governance-proposals.md, and the
test strategy for the next slices in test-strategy.md beside it.
1. A test-quality standard: isolation, oracle self-tests, a curated
   `just mutate` at phase end.
2. A VT-evidence standard: keywords name tests or code symbols, never
   prose.
3. An ADR-003 amendment or new ADR on write-safety and reader ownership.
4. An Elisp module-conventions standard, with a lint for cross-file `--`
   use.
5. A POL-002 clarification: what counts as a concept, and that confirmed
   duplication is never deferred.
6. A DEC-003 clarification: one scan per command.

**Haiku.**
One path writes the drawer;
three refusals learned one voice —
the queue keeps its turn.

## Reconciliation Brief

### Per-slice (direct edit)

- design.md: apply every bullet in `.doctrine/slice/001/notes.md`
  § "Design deltas for /reconcile". Bullets marked *Superseded* are
  overridden by the RV-002 bullets after them. The RV-002 findings that
  change design text:
  - F-1: §5.2 write preflight gains "base buffer read-only" → refusal,
    for every caller.
  - F-2: §4 and §5.2 — the second-drawer guard is in write preflight,
    after compare-and-set. §5.4 Add drops step 4, and the refusal order
    changes as the notes describe.
  - F-3 (and its Add extension): §5.2 sources wording ("a file is used as
    is") gains the Org-mode rule. §5.2 discovery API gains
    `org-iw-discovery-require-org-mode`. §5.4 resolve and Add refuse
    non-Org buffers, with the message "FILE: buffer not in Org mode".
  - F-6: §5.2 core gains `org-iw-core-rank-p`; put-rank checks RANK.
  - F-7: §5.1 and §5.2 core gain `org-iw-core-refuse`; the layer
    prefixes are as recorded.
  - F-8: §5.2 put-rank's QUEUE must be canonical
    (`org-iw-core-canonical-queue-id-p`); the "invalid queue ID" refusal
    has one owner, `org-iw--queue-id`.
  - F-9: §5.2 gains `org-iw-discovery-base-buffer`.
  - F-11 (closes G10): §5.1, §5.2 and §5.4 — discovery's public reader
    API as listed in notes; commands and write use no `--` privates.
  - F-12: §5.3 session start/end ownership.
  - F-15: §5.2 classify table gains the `IW_<id>+` → `(accumulate . ID)`
    row.
- Selectors (F-26), load-bearing: use `doctrine slice selector` to remove
  `Makefile` and add `justfile` and `README.md` as design-targets.
  `flake.nix` was delivered in the user's commit 145b226, outside the
  recorded source-deltas, so keep its selector. Mirror the changes in
  design §6.
- Off-surface, do not edit `plan.toml`: the PHASE-05 VT-3 wording
  ("a hook error" via `before-save-hook`) and PHASE-06 EX-3's same-file
  half are false as written. Record them in the design's §9 and notes as
  known criterion wording errors. Criteria ids stay immutable.

### Governance/spec (REV)

- POL-001 § Verification (F-27): replace "`make lint` and `make test`"
  and "The Makefile targets are established in SL-001" with `just lint`
  and `just test-all` (both Emacs; `just gate` = `doctrine check gate`)
  and the justfile → REV modify.
- Otherwise none required for SL-001's truth: the code now conforms to ADR-003 and
  POL-002 more closely than before. The proposed amendments (Synthesis
  § Proposed governance) are new governance for the user to accept, not
  reconciliation of drift.

## Reconciliation Outcome

User assent: "agreed" (session 2026-10-01), covering the design and scope
edits and the POL-001 REV as presented.

### Direct edits applied
- design.md (edited directly; the run is locked, so per the CLI no
  `design adopt`):
  - § 4 refusal owners: core `org-iw-core-refuse`, discovery Org-mode
    rule, write preflight for every caller (F-1, F-2, F-3, F-7).
  - § 5.1 diagram and edges: discovery public readers, write → discovery,
    no cross-file `--` calls (F-11, G10 closed).
  - § 5.2 core: `refuse`, `canonical-queue-id-p`, `rank-p`,
    `append-rank (ORDERED QUEUE)`, classify `(accumulate . ID)` row (F-6,
    F-7, F-8, F-15; PHASE-02 delta).
  - § 5.2 discovery: `org-iw-scan-create`, `base-buffer`,
    `require-org-mode`, the six readers, Org-mode rule for sources,
    resolve's refusal texts (F-3, F-9, F-11).
  - § 5.2 write: put-rank contract (canonical QUEUE, `rank-p` RANK,
    required EXPECTED), read-only refusal, drawer guard after CAS,
    `save-failed` causes, `--apply` sample synced (F-1, F-2, F-6, F-8).
  - § 5.2 org-iw.el: commands return their message, visit-next QUEUE,
    `--queue-id`, session pair (G1, G7, F-8, F-12).
  - § 5.3 session constructor, start/end ownership, mode-line trailing
    space (F-12; VH-1 request).
  - § 5.4 scan accumulate rule, Continue G3/G4/G7/G8, Visit `point-max`
    widening, Add steps 1/4/5/6/7 (F-2, F-3, F-11, G6).
  - § 6, § 8, § 9, § 10: justfile replaces Makefile; README.md added;
    flake row corrected; Known criterion wording errors recorded for
    PHASE-05 VT-3 and PHASE-06 EX-3 (plan.toml untouched) (F-26).
  - Every bullet of notes.md § "Design deltas for /reconcile" is now in
    the design; *Superseded* bullets were applied as overridden.
- slice-001.md: Tooling bullet and affected surface name the justfile and
  README.md; Emacs 30 risk marked resolved (plan.md delta).
- Selectors (F-26): removed `Makefile`; added `justfile`, `README.md` as
  design-targets. `flake.nix` kept, with a note (delivered in 145b226).
  Conformance: Makefile/README/justfile resolved; `flake.nix` stays
  "undelivered" by design.

### REVs completed
- REV-001 (`reconcile-sl-001`): done — POL-001 § Verification names
  `just lint` / `just test-all` / `just gate` and the justfile (F-27).
  Rationale and before/after in revision-001.md.

### Withdrawn / tolerated / follow-up
- F-20, F-23: tolerated; rationale in their dispositions.
- F-4 → IMP-004, F-5 → IMP-002, F-24 → IMP-003 (follow-up).

### Handed back (not a finding)
- ISS-001: put-rank and continue docstrings omit preflight refusals;
  found while confirming design wording.

Reconcile pass complete — handoff to /close.
