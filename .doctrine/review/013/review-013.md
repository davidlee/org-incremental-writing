# Review RV-013 — reconciliation of SL-004

Adversarial-review ledger. Structured findings live in the sister
ledger toml; this prose companion carries the reviewer's framing.

## Brief

<!-- Pre-reading + lines of attack: what this review is probing, the invariants
     it must hold the subject to, and where the bodies are likely buried. Seeded
     at `review new`; the reviewer fills it before raising findings. -->

Mode: conformance. Surface: the primary tree at 6deb5a7 (not dispatched;
PHASE-01..06 ran through capsule-driver in the main worktree). SL-004's
code range is 69117cf..HEAD: `org-iw-discovery.el`, `org-iw-write.el`,
`org-iw.el`, four test files, `test/org-iw-test-helpers.el`, `justfile`,
`flake.nix`, README. Canon: design.md (locked), DEC-021..028, RV-012
(14 findings verified), ADR-001..004, POL-001..003, STD-001..004.

Roster (STD-003, scaled up): the slice changes the write path (drawer
insertion on put-rank `:document`, the document drawer-removal rule in
delete-rank, DEC-022), and STD-003 § Scope names the scale-up. CHR-001
and CHR-002 (the mechanical substitutes) are still open. So the roster
is: modelling/architecture reviewer (opus), test reviewer (opus, with a
mutation pass), legibility/DRY reviewer (opus), and an opus verifier.
Reviewers are read-only, each in its own scratch copy under
`/home/scratch/sl-004/review/<role>/`. The seat is the sole ledger
writer. No per-phase code reviews ran; this pass covers the whole range.

Lines of attack:
- Write path (ADR-002, DEC-022, I3, I7): `:document` guards (marker at
  widened point-min of the base buffer; slotless → EXPECTED `:absent`);
  drawer insertion, ensure-id and put in one change group, one undo;
  heading byte-identical; delete classifies document-vs-heading *before*
  apply; a heading's rank-only drawer still errors and rolls back.
- Identity (DEC-021, REQ-007, POL-002): one owner
  (`org-iw-discovery-document-id`, `--identities`); file-level `:ID:` counts
  once; a heading copying the Denote identifier is a duplicate; slotless
  files never read the first heading's `:ID:` as the document's; Denote
  soft load once, one warning, never signals; I2 (no `:ID:` on Denote
  notes).
- One add step (POL-002, § 4.1): Add, Add-document and batch share
  `org-iw--add-entry`; `:expected :absent` and `org-iw-core-place` for
  adding only there; ENTRY equals the rescanned member.
- Batch fold (DEC-024..028, REQ-012, REQ-021): canonical order; catch
  only `org-iw-refusal` / `file-error`; summary after quit and
  uncaught errors; buffer kill rule (I5: never a pre-existing or
  modified buffer); in-run identity set (F-5); one scan and one sources
  walk (I4, DEC-027); session untouched.
- Layering (ADR-003, STD-004): no cross-file `org-iw-<layer>--` use;
  discovery owns Org-structure reads; commands hold no ordering logic.
- Tests (STD-001): mutation over the write and batch surfaces, oracle
  self-tests, isolation (`just test-each`), Denote-route skips per binary.
- Adaptations to reconcile (tier 5, notes): S1 public
  `org-iw-discovery-entry` (PHASE-04); O1 PROGRESS takes `(FILE .
  OUTCOME)`, command owns the summary (PHASE-05). Check each against the
  design's intent before it goes to the brief.
- Carry-ins: REQ-002/007/011 identity wording (DEC-021, RV-012 F-11) →
  REV; PHASE-01/EX-1 "Denote 4.x" vs design A1 / § 5.2 (≥ 4.1.0);
  e14c071 jail mount (unverified at harvest); SL-001 PHASE-06 VT-2
  waived (DEC-023); SL-001 PHASE-07 VT-2 stale keyword (pre-existing).

Out of scope, already captured: IMP-002, IMP-010, IDE-002, ASM-001,
ISS-002, ISS-003, ISS-004, CHR-001..004.

## Synthesis

SL-004 matches its locked design in substance. The audit found no
blocker and no user-visible defect in the shipped flows. The one major
finding, F-3, was a test gap over correct code. Every invariant the
brief named was proved by execution, in the reviewers' probes and the
verifier's reruns:

- **Write path (ADR-002, DEC-022, I3, I7).**
  - In a heading-first file, the heading is byte-identical after
    Add-document, and one undo restores the file.
  - A failing `org-entry-put` rolls back the inserted drawer and the
    `:ID:`.
  - A document drawer holding `:ID:` or other properties keeps them
    after Remove.
  - A Denote note returns to its original text.
  - A heading's rank-only drawer still errors.
- **Identity (DEC-021, REQ-007).**
  - One owner, `org-iw-discovery-document-id`, over `--identities`.
  - A heading copying the Denote identifier is a `duplicate-id`.
  - The soft load warns once across batches and never signals.
  - I2 holds for single adds and batches.
- **One add step (POL-002).** Adding writes the rank with `:expected
  :absent`, and calls `org-iw-core-place`, only inside `--add-entry`.
  Add, Add-document and the batch all go through it.
- **Batch (DEC-024..028, REQ-012, REQ-021).**
  - Canonical order, with ranks strictly increasing.
  - Only refusals and file errors are caught.
  - One scan and one sources walk per run.
  - I5 (pre-existing and modified buffers are kept) and I6 hold.
- **Layering (STD-004).** No `org-iw-<layer>--` symbol is used outside
  its own file.

The audit's yield was evidence, honesty of the batch report, and single
ownership:

- **Unpinned behaviour (F-3, F-6, F-7).**
  - The test reviewer ran 22 new cross-phase mutants on three
    configurations: 15 killed, 1 equivalent, 6 survived.
    - The 6 survivors: n3 (Add's DOCUMENT flag), b1/b2 (an unsaved add's
      rank and ID), b6 (a symlinked pre-existing buffer), d3 (Denote
      not installed) and n12 (an empty `:ID:`).
    - The per-phase passes' 118 mutants were not repeated.
  - Tests added in d65edcc kill all six. The shared `--should-fail`
    oracle now has a self-test.
- **Report honesty (F-1, F-2, F-12).**
  - An interrupted batch now says it stopped and lists the files not
    added.
  - A buffer the batch opened and left modified is reported whatever
    the outcome.
  - A report line names its file once.
- **POL-002 (F-8, F-9, F-11, F-14).**
  - One owner of the document's start, `org-iw-discovery-document-marker`,
    and `--target-at-point` decides DOCUMENT once.
  - One outcome sink in the batch.
  - One not-a-source refusal text.
  - Fixture-owned report cleanup, one Denote identifier constant, one
    start-of-file marker helper and one relative-name helper.
- **Gate integrity (F-4).** A set-but-broken `ORG_IW_DENOTE_DIR` used to
  give 15 silent skips on emacs-30. A guard test now fails instead, and
  two tests that tested the Denote-absent case no longer need Denote.
- **Docs (F-10, F-13, F-15).** README no longer overclaims what Remove
  restores. The docstrings name the document drawer, and
  `org-iw-discovery-title` is private again.

The user approved the four design-touching fixes on 2026-10-05: F-1's
summary text, F-8's owner and the M4 put at `point-min`, F-15 and F-9.
Their design deltas are in the brief.

All fix-now findings landed in d65edcc. Gate: 408/408 on 31.1 and 30.2
with the Denote dir set (0 skipped). Unset, emacs-30 skips the 14
Denote-route tests plus the guard. Lint and checkdoc are clean.
verify-vt SL-004: 11 PASS. `just test-each`: 408 all pass alone on emacs
and emacs-30, with the dir set and unset.

Tradeoffs consciously accepted:

- **F-17.** A quit inside `find-file-noselect` or `save-buffer` can leave
  one extra buffer open, or lose that file's outcome. I5 still holds,
  and the summary lists the file as stopped.
- **F-1, part.** The command loop's Quit/error message overwrites the
  echo summary. The report buffer and `*Messages*` keep it.

Not raised: L5, L14, L19 and L17 (composition over one owner, or
naming nits; the verifier agreed). M10 was folded into F-17.

Standing risks:

- **Jail provisioning (F-5 → ISS-005).** The jail's `ORG_IW_DENOTE_DIR`
  names an unmounted path. Until the host fixes it, the guard test fails
  the gate in the jail unless the variable is set by hand.
- **Stale Denote document in a slotless file (F-16 → ISS-006).**
  Reaching it takes three coincidences, and the fix is a design change.
- **Scale.** IMP-010 and IMP-002 are unchanged. The VH-1 trial was
  instant at 74 files. Batch placement is quadratic in queue length
  (about 1.6 s at 3,000 files).
- **SL-001 evidence rot.** `verify-vt SL-001` fails PHASE-02 VT-3
  (CHR-004) and PHASE-07 VT-2 (`already at end`, removed by SL-002 in
  126e91f). Both are outside this slice.

Roster (STD-003, scaled up for the write path):
- opus modelling/architecture reviewer: 7 candidates, 6 probe files;
- opus test reviewer: the mutation pass, 9 probe tests;
- opus legibility/DRY reviewer: 19 candidates;
- opus verifier: 33 candidates, 30 confirmed, 3 plausible, none
  rejected, with 4 severity corrections.

Scratch is under `/home/scratch/sl-004/review/` and
`/home/scratch/sl-004/audit/`.

Where to look:
- `doctrine show DEC-022`: the write-layer document rule;
- `doctrine show DEC-026`: the batch's buffer rule, now honoured for
  every outcome;
- `doctrine show ISS-005`: the jail mount;
- `doctrine show ISS-006`: stale identity resolution.

## Reconciliation Brief

### Per-slice (direct edit)

- **design.md § 5.2 Discovery (F-8, F-15, F-18).**
  - Add `org-iw-discovery-document-marker ()`: a marker at the widened
    `point-min` of the base buffer, insertion type nil, and the one
    owner of the document's start. `--at-document-start` uses it.
  - Add public `org-iw-discovery-entry (file)`: the entry at point,
    through the private one constructor `--entry` shared with
    `--read-entry` (S1). Note that the identity `--add-entry` takes
    before the write agrees with the reader's after it, because the
    write guarantees a slot.
  - `org-iw-discovery-title` stays private as `--title`. Remove "made
    public (RV-012 F-7)".
- **design.md § 5.2 Write (F-8, M4).**
  - The new-drawer branch puts the rank at `point-min`, not at the
    caller's marker.
  - `--document-start-p` compares MARKER against
    `org-iw-discovery-document-marker`.
- **design.md § 5.2 Commands (F-8, F-9, F-2, F-11).**
  - `org-iw--document-marker` is deleted. Its callers use the discovery
    owner.
  - `org-iw--target-at-point` returns `(MARKER . DOCUMENT)`.
  - `org-iw--batch-add (scan queue files sources on-outcome)`:
    ON-OUTCOME is called with each `(FILE . OUTCOME)` and is the only
    sink, and the fold returns nothing useful (O1).
  - `org-iw--batch-outcome (file fn)` owns visiting, the catch
    (refusal, file error; a leading "FILE: " is stripped), the kill rule
    and the `left-open` mark. It replaces `--call-in-file-buffer` and
    `--batch-add-file`.
  - `org-iw--batch-outcome-text` reports one file's outcome.
  - The constant `org-iw--not-source` is the one not-a-source text.
- **design.md § 5.3 (F-1, F-2).** The outcome shapes are `(added
  STATUS)`, `(existing)`, `(failed REASON)` and `(stopped)`, each ending
  in `left-open` when the batch opened the buffer and left it modified.
  Update the example.
- **design.md § 5.4 (F-1, F-2, F-10, F-13).**
  - Step 1: the empty refusal is "no existing file selected".
  - Step 3.6: a modified opened buffer is marked `left-open` on any
    outcome and counted as unsaved.
  - Step 4: after a quit or error, the remaining files are `(stopped)`.
    The summary adds ", stopped after K of M files", and the report
    lists those files.
  - "Remove a document's last membership": the drawer goes only if
    nothing else is in it. A Denote note returns to its text before
    Add; any other document keeps the `:ID:` Add gave it.
- **design.md § 5.5 (F-10, F-19).**
  - I7: "keeps no `IW_` line; its drawer is removed when that empties
    it".
  - A1: "Denote ≥ 4.1.0".
- **design.md § 8 (F-19).** In the first risk row, Denote "4.x" becomes
  "≥ 4.1.0".
- **design.md § 10.** List the helpers above.
- **Selectors.** None: conformance has 10 conformant paths and 0
  undelivered (the undeclared paths are `.doctrine/` only).
- **slice-004.md.** No edit. Its closure trial was met by PHASE-07
  VH-1.
- **plan.toml.** No edit. PHASE-01/EX-1 "Denote 4.x" is immutable and
  was met by 4.2.3.

### Governance/spec (REV)

- **F-20: REQ-002, REQ-007 and REQ-011.** REV modify: a document's
  identity is its file-level `:ID:`, else Denote's filename identifier
  when Denote is available, else none, and Add inserts an `:ID:`
  (DEC-021). A Denote note gains no `:ID:`. REQ-007's duplicate rule
  counts a document's identity once, at the document.

## Reconciliation Outcome

The user assented to the brief on 2026-10-06 ("handover to … 2.
reconcile", with no items named for change).

### Direct edits applied
- design.md § 5.2 Discovery (F-8, F-15, F-18): added
  `org-iw-discovery-document-marker` (the one owner of the document's
  start) and public `org-iw-discovery-entry` over the one constructor
  `--entry`, with the before/after identity agreement noted.
  `--title` stays private; "made public (RV-012 F-7)" removed.
- design.md § 5.2 Write (F-8, M4): `--document-start-p` compares with the
  discovery owner. The new-drawer branch puts the rank at `point-min`.
- design.md § 5.2 Commands (F-2, F-8, F-9, F-11, F-12, F-18):
  - `--not-source`;
  - `--target-at-point` returning `(MARKER . DOCUMENT)`;
  - `--document-marker`, recorded as deleted;
  - `--add-at`, the shared body of Add and Add-document (PHASE-04,
    previously unlisted);
  - `--add-entry` reads ENTRY through `org-iw-discovery-entry`;
  - `--batch-add … on-outcome` as the only sink;
  - `--batch-outcome`, which replaces `--call-in-file-buffer` and
    `--batch-add-file`;
  - `--batch-outcome-text` and the outcome predicates.
- design.md § 5.3 (F-1, F-2): the outcome shapes, `(stopped)` and the
  `left-open` tail; the example updated. Ownership names
  `--batch-outcome` and the document-start owner.
- design.md § 5.4 (F-1, F-2, F-10): Add step 1. Batch step 1 reads "no
  existing file selected"; step 3 uses ON-OUTCOME and the discovery
  marker; step 3.6 adds `left-open` on any outcome; step 4 covers
  stopped files. The document-Remove passage is corrected.
- design.md § 5.5 (F-10, F-19): I7 reworded; A1 reads "Denote ≥ 4.1.0".
- design.md § 8 (F-19): **no edit; the item does not apply.** No risk row
  says "4.x". Row 2 cites Denote 4.2.3, which is accurate. The only
  "4.x" was A1, fixed above.
- design.md § 10: lists the helpers above.
- Selectors, slice-004.md, plan.toml: no edit, as briefed.
- design.md was edited outside the design run, as at SL-001..SL-003
  reconcile. `design show` notes it is behind run revision 40. It was
  deliberately not materialised: that would overwrite the reconciled
  prose.

### REVs completed
- REV-006 (`reconcile-sl-004`): done (F-20). REQ-002, REQ-007 and
  REQ-011 now state DEC-021's document identity. REQ-007 AC3 counts a
  document's identity once. REQ-011 AC3 means a Denote note gains no
  `:ID:`. The before/after text and rationale are in revision-006.md.

### Withdrawn / tolerated / follow-up
- F-17 and part of F-1: tolerated, as the Synthesis records.
- F-5 → ISS-005 (jail mount; diagnosed 2026-10-06, flake fix proposed
  to the user). F-16 → ISS-006.
- Found while reconciling, outside the brief: PRD-001's prose still says
  Org-ID-only identity (spec-001.md:32, :97) → CHR-005. It was not
  edited here.

Reconcile pass complete; handoff to /close.
