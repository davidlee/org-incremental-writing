# SL-003 research — queue view and membership ops

**Producers:** Thread 1 (governance) and Thread 2 (code map) were each run
by a read-only general-purpose subagent, since the project defines no
research agents; 2026-10-03. The design agent assembled this document and
verified the ✓ rows. The verbatim thread output is in `raw/governance.md`
and `raw/code-map.md`, and this document points there for bulk. Baseline:
`baseline.toml` (stamped by `doctrine slice research SL-003`).

**Legend:** ✓ = verified by the design agent by reading or running the
cited site. Unmarked = researcher claim: cited, not re-checked.

## Thread 1 — governance applicability

Binding (full table in `raw/governance.md`):

- ✓ ADR-003 — layer 3, "Org mutation", "sets **or removes** one
  property". Layer 4, "Commands and view", holds the queue view and no
  ordering logic. A delete verb belongs in `org-iw-write.el`, and the view
  in the command layer.
- ✓ STD-004 item 1 — one file per ADR-003 layer: the four files are named.
  Item 2: a `--` symbol is file-private. A separate `org-iw-view.el`
  breaches item 1 and needs the `org-iw--` helpers made public. So the
  view goes in `org-iw.el` (also DEC-001).
- ✓ SL-002 design I10 — every rank comes from `org-iw-core-rank-at` and
  every placement decision from `org-iw-core-place`; "no other function
  computes a rank, a depth or a neighbour". This bears on up/down and
  before/after.
- ✓ DEC-011 consequence — "Remove joins the chooser only when SL-003
  provides it". The decision defines the chooser as vocabulary labels.
- ✓ DEC-005 — a single global session, "set by visit/continue/opening
  from a view, cleared by org-iw-end-session".
- ADR-001 / DEC-003 — the view is a disposable display copy. Every action
  and every refresh rescans.
- ADR-002 / REQ-021 / REQ-022 — writes go through visiting buffers under
  the save policy, and single-entry undo is buffer undo. The view must
  reflect undo on refresh.
- ADR-004 / REQ-010 — the core alone computes ranks. A no-op writes
  nothing, and no gap stops before any change (no redistribution until
  SL-006).
- REQ-004 — remove deletes one line. Other properties, content and TODO
  state stay byte-identical.
- REQ-007 / REQ-015 — an unresolvable or removed target is reported and
  never recreated.
- REQ-008 — the view shows ordinals 1..N, not ranks.
- REQ-013 — acceptance criteria (ACs): (1) every configured and discovered
  queue offered; (2) same-title entries distinguishable by file/outline
  context; (3) refresh reflects undo; (4) open = Visit-next session.
- REQ-017 — ask for the queue only outside a session with more than one
  membership at point. Only that membership's rank changes.
- REQ-018 — delete only the selected property. Remove in the Continue
  chooser does not reinsert.
- POL-002 — one implementation per concept, including messages and test
  helpers. No second preflight, resolver or prompt recorder.
- POL-003 — the VH trial is already named in the SL-003 scope.
- STD-003 — the write path is high stakes, so the pre-close roster scales
  up (legibility reviewer plus an opus verifier) or the audit justifies not
  doing so.
- REQ-024 — Emacs 30.1+, built-ins only. `tabulated-list-mode` is built
  in. Avoid 31-only APIs.

Checked, not applicable (reasons in `raw/governance.md`): REQ-011,
REQ-012, REQ-019/020, DEC-002 (unless Remove is configurable), the DEC-009
revisit, EVD-001, QUE-001/IMP-002, IMP-001, IMP-004, CHR-001/002, PRD-001
OQ-1/2/4, REV-001..003.

Relevant memories: `mem.fact.emacs.batch-test-gotchas`,
`mem.fact.emacs.org-write-idioms`, `mem.fact.emacs.save-hook-errors-demoted`,
`mem.fact.emacs.completing-read-default-bubbles`,
`mem.fact.emacs.completion-table-with-metadata-31-only`,
`mem.pattern.doctrine.vt-keywords-match-prose`,
`mem.pattern.doctrine.design-review-gate-gotchas`. There are no memories
on tabulated-list, mutation or property removal.

Revision candidates:

- The commentary and docstring in `org-iw-write.el` ("the one write path")
  and the `org-iw--save-status` docstring become false once delete lands.
  ISS-001 can be fixed in passing.
- DEC-011 needs amending if Remove joins the chooser.
- DEC-005 needs amending only if remove ends the session.
- I10 needs a clarifying DEC if commands translate a view index into
  `(after k)`.
- The SL-003 `governed_by` relations omit ADR-004 and STD-001..004.
- PRD-001 §6 "Move / remove" names no placement form for a source move.

## Thread 2 — code map

Hotspots:

| file | likely change |
|---|---|
| `org-iw-core.el` | an outline-context field on `org-iw-entry` (:48-54); perhaps a relative-placement helper |
| `org-iw-discovery.el` | read outline context during the scan (`--read-entry` :213-231, `--scan-buffer` :256-282); a reader for the memberships at point |
| `org-iw-write.el` | a delete-membership verb that reuses `--preflight` (:59-79) and `--apply` (:81-97) |
| `org-iw.el` | the view mode and commands; source-entry move and remove; Remove in the Continue chooser (:267-280, :561-604) |
| `test/org-iw-test-helpers.el` | promote the prompt recorder and the no-op oracles from `test/org-iw-test.el` (:66-98, :1011-1050) if the view tests use them |

Cited facts:

1. ✓ `org-iw-entry` holds `id title file memberships`, with no outline
   context (org-iw-core.el:48-54). The scan runs every file in an Org-mode
   temp buffer (org-iw-discovery.el:308-317), so `org-get-outline-path` is
   available at no extra I/O. Its output strips cookies and reduces links,
   while the title is raw (org-iw-discovery.el:199-206 vs org.el:7836-7846).
2. ✓ The write verb `org-iw-write-put-rank` = type checks → `--preflight`
   → `--apply` with a put lambda (org-iw-write.el:126-135). Only the lambda
   is specific to rank.
3. ✓ `org-entry-delete` matches the key under `case-fold-search`. With
   `case-fold-search` nil, `:iw_a:` is not deleted and the call returns nil;
   with t it is deleted and returns t (exp, design agent). It also deletes
   `IW_<Q>+` lines and an emptied drawer. A member always has an `:ID:` in
   the same drawer, and preflight with an integer EXPECTED refuses
   duplicate and accumulate shapes (org-iw-write.el:48-57).
4. ✓ Any depth is expressible as `(after N)`, which is exact for N in
   [0, count] (org-iw-core.el:164). Depth counts the order without the
   target (:202-203). With i the target's index in ORDER and j X's index
   in ORDER minus the target:
   - up = `(after (1- i))`
   - down = `(after (1+ i))`
   - before X = `(after j)`
   - after X = `(after (1+ j))`
5. Ties: `rank-at` needs neighbours more than 1 apart (org-iw-core.el:
   182-183), so moving between two equal ranks is `no-gap`. Ends always
   have room.
6. ✓ `org-iw--visit` resolves the entry, shows it with
   `pop-to-buffer-same-window`, starts the session and reports
   (org-iw.el:453-472). Continue finds the session entry by ID, so a moved
   entry is harmless and a removed one refuses "no longer in queue"
   (:505-514, :575-578).
7. tabulated-list-mode:
   - `tabulated-list-entries` may be a function, and `g` reverts through
     `tabulated-list-print t`;
   - REMEMBER-POS restores point by the row ID compared with `equal`, and
     jumps to `point-min` if the ID is gone;
   - `buffer-undo-list` is t, so there is no undo in the view.

   Use the Org ID as the row ID (tabulated-list.el:393-400, :464-521,
   :871-872).
8. Tests: shared fixture `org-iw-test-with-corpus`, builders, snapshot and
   changed-lines (test/org-iw-test-helpers.el:96-286). The command-test
   recorder and oracles are local to `test/org-iw-test.el`. There is no
   mutation tooling (CHR-001). Gates: `just check`, `just gate`,
   `just test-each`.
9. Conventions: `org-iw--report` returns the message; `org-iw--save-status`
   reports the write result; every refusal goes through `org-iw-core-refuse`.

Naming precedents: verb-object write verbs (`org-iw-write-put-rank`) and
`--` file-private symbols. There is no mode or keymap precedent in the
repo. The Emacs idiom is `define-derived-mode org-iw-view-mode
tabulated-list-mode` plus an autoloaded entry command.

## Cross-thread findings

- **X1 — view file vs layering.** ADR-003 puts the view in layer 4, and
  STD-004 maps layers to four files. The view needs about seven
  `org-iw--` helpers. → The view lives in `org-iw.el`, and no helpers are
  made public.
- **X2 — delete verb vs "the one write path".** ADR-003 (via REV-002)
  sanctions removal in the mutation layer. POL-002 forbids a second
  preflight. → `org-iw-write-delete-rank` (name TBD) shares `--preflight`
  and `--apply`. Its lambda binds `case-fold-search` to t and checks the
  result. The write commentary is reworded to "the write layer".
- **X3 — relative moves vs I10.** Fact 4 shows up/down/before/after map
  onto `(after k)`, so `core-place` still decides and `rank-at` still
  allocates. But computing k from an index is "computing a depth" by I10's
  wording. → A design decision: either a pure core helper turns a relative
  move into a placement, or a DEC rules that index→`(after k)` is input
  translation.
- **X4 — distinguishing context.** REQ-013 AC2 needs more than the file:
  two same-title headings can share a file. Discovery's temp buffer makes
  an outline path cheap (fact 1), but it adds a field to the core struct
  and a rendering inconsistency with the raw title.
- **X5 — stale rows.** DEC-003 (rescan, no cache) plus write preflight's
  `:expected` mean a view action should rescan, find the entry by ID, and
  write against the fresh rank. Acting on row data would refuse "changed
  since scan" after a source undo.
- **X6 — session on remove.** DEC-005 says the session is cleared only by
  `org-iw-end-session`. Removing the session entry otherwise leaves the
  session dangling until Continue refuses. Moving the entry is harmless.
- **X7 — Remove in the chooser.** DEC-011 anticipates it. Open: a label
  collision with a user label "Remove", that Remove must never be the
  default, and what Continue does after a remove (visit the new front?).
- **X8 — ties.** Up/down past a tied pair gives `no-gap` and refuses until
  SL-006. The refusal text "choose another placement" (org-iw.el:189-193)
  fits poorly for up/down, and POL-002 wants one owner, generalised.

## Design-input deltas

- The view lives in `org-iw.el` (X1). No new source file.
- There is one new mutation verb, a delete-membership verb sharing
  preflight and apply, with a case-insensitive delete (X2, fact 3).
- No new rank arithmetic. Every move funnels through `org-iw-core-place`
  (fact 4). The depth translation needs a decision (X3).
- Discovery likely gains outline context (X4). That is a core struct
  change, read in the scan.
- Every view action rescans and targets by ID (X5).
- Decisions to settle with the user:
  - the source-move placement form (vocabulary vs position vs relative to
    an entry);
  - the session on remove (X6);
  - Remove in the chooser (X7);
  - document entries in source-entry commands (refuse until SL-004?);
  - opening from the view replacing the view window.
- Governance hygiene: link SL-003 `governed_by` ADR-004 and STD-001..004.
