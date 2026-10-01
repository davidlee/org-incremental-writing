# Notes SL-001: Walking skeleton

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage (2026-09-30, exploring)

Constraining governance: ADR-001 (entry-resident state), ADR-002 (buffer-
mediated writes, save policy, single writer), ADR-003 (four layers), POL-001
(lint/test gate), POL-002 (one implementation per concept), POL-003 (human
trial), PRD-001 § 4 constraints. Evidence: `research/research.md` (T2-*, X1-X5).

Shaping decisions carried in from research:
- Discovery rescans every operation with a raw-text `:IW_` prefilter; no
  index (research X1; settles PRD-001 OQ-1 provisionally, revisit SL-004).
- Tests isolate `org-id-locations-file` (T2-7).
- Makefile parameterised by `EMACS=`; Emacs 30 run verified by the user (T2-10).

Open design questions: tracked as `inq-*` nodes in the design run
(`doctrine design show --format prompt SL-001`).

Risks:
- Emacs 30 compatibility unverifiable in the agent jail (T2-10).
- `org-id-get-create` side effects on the user's global id locations in real
  use are expected and fine; only tests must isolate.
- Doc-level entries appear in discovery reads via `point-min` but are not
  targeted in SL-001; keep the read path uniform so SL-004 adds no parallel
  reader (POL-002).

Assumptions:
- Configured sources are few enough that a synchronous rescan is imperceptible
  (measured 10 ms prefilter / 112 files).

## Design review (2026-09-30)

RV-001 (`doctrine review show RV-001`): adversarial agent pass, 4 rounds, 24
findings, all fix-now and verified by the raiser. Further pass: none needed
before planning. Residual probe targets for implementation (tests carry them):
the raw IW-line reader and block-skip rule (§ 5.4 step 4), `resolve` under
narrowing/indirect buffers, and put-rank's atomic/save-failed paths — all of
which are cheaper to prove by the § 9 tests than by more design review.

## Design lock (2026-09-30)

Locked at run rev 38 on the user's "accept and lock" (all 14 sections
attested; RV-001 disposed `conducted`). The user accepted knowingly over the
pass's 2 blockers / 8 majors (all repaired in prose); a code review follows
implementation. The lock required a route on every severe finding, so they
were backfilled (reopen → re-dispose): F-9, F-11 `review` (verified);
F-1, F-3 `probe`; F-2, F-4, F-6, F-10 `control`; F-5 `demonstrate`. The
seven instrument-routed findings stay `answered` — `/plan` must transcribe
each one's criterion sketch and host-phase constraint (on the RV) onto a
phase criterion; the raiser verifies after `slice phases`.
DEC-001..006 accepted. Slice → plan.

## Plan (2026-09-30)

8 phases (`plan.toml`; rationale and design deltas in `plan.md`). Planning
found the jail has no `make`; user chose a justfile and added `just` to
the flake — the Makefile→justfile swap is a recorded delta to reconcile into
design § 9/§ 10 and slice scope. PHASE-01/VH-1 is a hard gate: the user
rebuilds the dev shell (just + emacs-30) before the gate can run in-jail.
RV-001 instrument findings transcribed and verified (transcription only);
RV-001 now fully verified. verify-vt: all 23 mandates checkable (FAIL =
files not yet written). Slice → ready.

## PHASE-01 (2026-10-01) — completed, 405af23

Gate landed as a justfile (lint = compile + checkdoc + package-lint +
relint on Emacs 31; test-all on 31.1 and 30.2; `check` / `gate` recipes for
`doctrine check`). RV-001 F-10 controls observed: all four candidates fail
`just lint`; a shared-process compile masks the sibling-require fault, the
per-file compile catches it. Gotcha: package-lint in batch needs
`(require 'compile)` first or prints an autoload error (harmless).
Licence: GPL-3.0-or-later (user, LICENSE.md; headers 31e311c). URL header confirmed against origin (davidlee/org-incremental-writing).

## PHASE-02 (2026-10-01) — completed, 72d1071

org-iw-core landed, 11 tests; gate green on Emacs 31.1 and 30.2. I6 child-
Emacs test shown red with a temporary `(require 'org)`. Design delta for
/reconcile: § 5.2 `org-iw-core-append-rank` takes `(ORDERED QUEUE)`.

## PHASE-03 (2026-10-01) — completed, 82c3bd2

org-iw-discovery (files + scan) and the corpus fixture
(test/org-iw-test-helpers.el); 33 new tests (44 total), gate green on both
Emacs; discovery coverage 99%. Gap rulings: an entry with no surviving
membership is not emitted; `duplicate-id` per in-file-skipped entry plus one
per cross-entry shared ID; `IW_<Q>+` alone is `invalid-property`, with
`IW_<Q>` a `duplicate-property`; missing sources skipped; exclude regexp
case-sensitive. The ID-line owner (`org-iw-discovery--id-values`) exists for
PHASE-04's id-count. Worker choices: a live buffer's widened text is copied
into the temp buffer (one read path; the user's buffer untouched; non-Org-mode
live buffers work); inaccessible subdirectories are skipped. Org 9.7.11 and
9.8.10 agree on block lineage, `org-at-property-p` and document drawers.
Gotchas: a dangling lock symlink is already dropped by the regular-file
filter, so the `.#` rule needs a regular `.#` file to test;
`set-buffer-modified-p nil` alone releases a lock file. Deltas for /reconcile:
`org-iw-scan-create` constructor; fixture FILES is an evaluated form.

## PHASE-04 (2026-10-01) — completed, fec2d3c

`org-iw-discovery-buffer`, `-id-count`, `-resolve` added to
org-iw-discovery.el; 9 new tests (53 total), gate green on both Emacs.
Rulings: `id-count` (no buffer argument) works on
`(or (buffer-base-buffer) (current-buffer))`, widened, so a narrowed
indirect buffer still counts the whole base; `resolve` calls it inside
`(with-current-buffer (org-iw-discovery-buffer FILE) ...)`. POL-002: the
PHASE-03 owner became `org-iw-discovery--id-lines` returning
`((VALUE . LINE-START) ...)`; `--id-values` (scan tally) is its `mapcar
#'car`, `--id-positions` (count and resolve) filters it — one matcher. The
scan-excluded check is by ID only (a cross-file duplicate names just the first
file, so a file check would let the second file's entry through); refusal
wording differs per cause (duplicate / not found / ambiguous) and always
names ID and file. F-1 probe: holds for a same-file copy without and with
another membership, lowercase `:id:` key, case-variant value, a copy hidden by
narrowing, and via an indirect buffer. Copies present at scan time surface as
"duplicate"; copies added after the scan (test inserts them into the visiting
buffer) exercise the "ambiguous" path. The indirect-buffer claim of design § 3
holds on Emacs 30 and 31: `buffer-file-name` is nil and `find-buffer-visiting`
returns the base. `org-back-to-heading-or-point-min` is passed `t`
(invisible-ok) so a folded heading cannot fail the lookup. No design delta.

## PHASE-05 (2026-10-01) — completed, 0352b68

org-iw-write.el: `org-iw-write-put-rank` (the only public symbol) with
private `--base`, `--refuse`, `--queue-lines`, `--expected-p`,
`--preflight`, `--apply` (the design sketch). 23 new tests in
test/org-iw-write-test.el (76 total); gate green on Emacs 31.1/Org 9.8.10
and 30.2/Org 9.7.11; write-layer coverage 100%. T1 promoted the corpus
builders `org-iw-test-org`, `org-iw-test-heading`, `org-iw-test-unless-root`
from discovery-test into test/org-iw-test-helpers.el.

Rulings (orchestrator): gap 1, write requires `org-iw-discovery` and
reuses `--iw-lines`/`--line-class` (no second IW reader; grep-checked:
no `org-entry-get`/`org-entry-properties`/regexp in org-iw-write.el);
gap 2, private discovery readers called as they are; gap 3, edit in the
marker's buffer; gap 4, `(cl-check-type expected (or integer (member
:absent)))`, so omitting EXPECTED is `wrong-type-argument`; gap 5, QUEUE
canonicalised with `org-iw-core-queue-id`, invalid -> refusal, RANK not
range-checked (docstring says so); gap 6, no guard for a base without a
file; gap 7, order queue -> modtime -> writable -> compare-and-set, each
message is "FILE: reason" (the compare-and-set names `IW_<Q>`).

Outcomes:
- Gap 3 holds on both Emacs: in a cloned indirect buffer (`make-indirect-buffer
  ... t`) the edit lands in the base's text, the base is saved, `saved` is
  returned, and the indirect buffer's narrowing is kept. `save-buffer` in an
  indirect buffer saves the base anyway (`basic-save-buffer` delegates).
- The `widen` in `--apply` matters only for `org-id-get-create` (point-based);
  `org-entry-put` given a marker widens by itself. Red proof: without `widen`,
  :ensure-id from an indirect buffer narrowed away from the target fails.
- Undo (T6): one `undo` after `undo-boundary` reverts the whole put-rank,
  ensure-id insertion included; no amalgamation needed, since neither Org call
  inserts a boundary. Red proof: an `undo-boundary` between the two calls fails
  the test.
- Key case (T3): `org-entry-put` rewrites a lowercase `:iw_essays:` line as
  `:IW_ESSAYS:` on the same line (one removed, one added line).
- atomic-change-group restores text, the unmodified flag and hence the lock
  file on both Emacs (the design's RV-001 claim holds).
- **`before-save-hook` errors cannot fail a save**: `basic-save-buffer` wraps
  the hook in `with-demoted-errors` on 30.2 and 31.1. So `save-failed` is
  proven through `write-file-functions` (not demoted), and a separate test pins
  that a failing `before-save-hook` yields `saved`. PHASE-05 VT-3's wording
  ("failing before-save-hook yields save-failed") is false as written; see
  deltas.
- F-4 red proofs: modtime checked on `(marker-buffer marker)` -> the indirect
  case signals "Cannot resolve conflict in batch mode" (supersession), not a
  refusal; writable check dropped -> the read-only case reaches a
  `yes-or-no-p` save prompt. That prompt reads stdin: under a tool runner whose
  stdin stays open, `just test` hangs instead of failing; run it with
  `</dev/null`.
- No Org 9.7/9.8 differences observed.

## PHASE-06 (2026-10-01) — completed, 62c2437

org-iw.el: autoloaded `org-iw-add` (QUEUE) plus private `--refuse`,
`--files`, `--scan`, `--buffer-truename`, `--source-file-p`,
`--configured-queues`, `--configured-name`, `--queue-name`,
`--read-queue`, the message pair `--save-status` / `--report` (PHASE-07
reuses both), and Add's own `--add-target` (steps 1-2),
`--problem-types`, `--unrecognised-drawer-p`, `--shared-id-p`,
`--check-heading` (steps 4-6). org-iw.el requires `org`, core, discovery,
write. New test/org-iw-test.el: 27 tests (103 total); gate green on Emacs
31.1/Org 9.8.10 and 30.2/Org 9.7.11; `org-iw.el` coverage 100%. T1
promoted `-marker`, `-base`, `-text`, `-snapshot`, `-edit-elsewhere`,
`-call-with-indirect`, `-should-add-drawer` from write-test into
test/org-iw-test-helpers.el as `org-iw-test-*`, and added
`org-iw-test-state` (every corpus file's disk text plus every corpus
buffer's text and modified flag; PHASE-07's I1 checks can use it).
Command-test names use `org-iw-cmd-test-` so they cannot shadow fixture
internals.

Rulings (orchestrator, adopting the phase sheet's defaults):
- G1: steps 1-2 are `org-iw--add-target`, called from the interactive spec
  before the prompt and again by the body. G2: two scans per interactive
  Add, accepted.
- G3: `org-iw-write--queue-lines` moved to `org-iw-discovery--queue-lines`
  (pure move; write and org-iw call it). G8: the entry-ID read extracted as
  `org-iw-discovery--entry-id`, used by the scan and Add.
- G4: excluded-type text is `missing-id` for a heading without an ID, else
  the distinct problem types naming the ID in any file, else `unknown`.
- G5/G6/G7/G10: see deltas below. G9: title left out of the message; the
  suffix is always "[N source problems ignored]". G11: every Add read runs
  widened. G12: invalid configured IDs are dropped from completion and
  names (`--configured-queues`).
- Worker call beyond the sheet (POL-002): G6's test "the scan excluded ID
  as a duplicate" was inline in `org-iw-discovery-resolve`; extracted as
  `org-iw-discovery--excluded-id-p` and shared with Add rather than
  restated. Pure refactor under green.

Messages: "Added to NAME at M+1/M+1 STATUS", "Already in NAME at N/M",
refusals "BUFFER is not under org-iw-sources", "document targets are not yet
supported", "invalid queue ID %S", "heading has a property drawer Org
doesn't recognise", "heading has IW_Q but it is excluded (TYPES)", "ID
shared with another heading", "rank limit; redistribution needed". Refusals
are `org-iw-refusal` via `format` (not `format-message`, which would curl
the apostrophe).

Outcomes:
- F-2 (EX-3) holds: same-file and cross-file copies both refuse with every
  corpus file and buffer unchanged and the scan identical before and after.
  Red proof: without the cross-file entry condition, Add of the copy reports
  "Added to ESSAYS at 2/2 (saved)" and the rescan leaves ESSAYS empty (both
  excluded as `duplicate-id`), i.e. the member is knocked out. Without the
  G6 condition the three-file case fails.
- F-5 indirect half (EX-4) holds: from a cloned indirect buffer
  (`make-indirect-buffer ... t`) Add saves through the base; the disk diff is
  the one `IW_ESSAYS` line. Under a base narrowed to the subtree and an
  indirect buffer narrowed to the body only, Add succeeds and the narrowing
  is kept (the accessible text grows by the inserted line). Red proofs: a
  `buffer-file-name` without the base lookup fails the indirect and
  source-file tests; `--add-target` without widening fails the body-only case.
- Steps 1-3, 5 and 7 were written in T4/T5's green code before their T6
  tests; each was then proven by mutation (disable the check -> its tests
  fail), as was the pre-prompt check in the interactive spec.
- Malformed drawer: Org's `org-property-start-re` is the line test (same
  string on 9.7.11 and 9.8.10); the section ends at `outline-next-heading`
  (point-max for the last heading; both ends tested).
- A step-5 bug found by the no-op tests: a `when` whose value was dropped let
  a member fall through to step 6; now a `cond`, steps 5 and 6 exclusive.
- `doctrine slice verify-vt SL-001` reports PHASE-06 VT-1/VT-2
  UNATTRIBUTABLE until test/org-iw-test.el is committed (attribution is by
  commit); every keyword is present literally.
- Trap: moving the `make-indirect-buffer` helper to test/org-iw-test-helpers.el dropped the literal keyword from test/org-iw-write-test.el, regressing PHASE-05 VT-2 in `verify-vt`; fixed by naming `make-indirect-buffer` (via `org-iw-test-call-with-indirect`) in the two indirect tests' docstrings.
- Grep: no `org-entry-properties`, `org-find-entry-with-id` or IW regexp in
  org-iw.el; the three defcustoms are read only in org-iw.el (discovery's
  docstring names `org-iw-sources`, a reference).
- No Org 9.7/9.8 differences observed.

## PHASE-07 (2026-10-01) — completed, e315e8c

org-iw.el: session struct `org-iw--session` (constructor
`org-iw--session-create`), `defvar org-iw--session`, `defconst
org-iw--mode-line-construct` `(:eval (org-iw--mode-line))`,
`org-iw--mode-line`, `org-iw--visit`, autoloaded `org-iw-visit-next`,
`org-iw-continue`, `org-iw-end-session`, and private `--queue-id`
(validate or refuse "invalid queue ID %S"), `--order` (queue order of a
scan), `--append-rank` (rank or refuse "rank limit; redistribution
needed"), `--refuse-absent`, `--move-to-end`. Add now uses `--queue-id`,
`--order`, `--append-rank` (POL-002: each message string occurs once).
No lower-layer change (R2). Tests: 31 new in test/org-iw-test.el (134
total); fixture binds `org-iw--session` and `global-mode-string` nil;
`org-iw-write-test--rewrite-behind` promoted to the fixture file as
`org-iw-test-rewrite-behind NAME TEXT` (write-test's VT keywords intact).
Gate green on Emacs 31.1/Org 9.8.10 and 30.2/Org 9.7.11; `org-iw.el`
coverage 99% (the one "missed" line, visit-next's empty-queue report, is
asserted by `org-iw-cmd-test-visit-next-empty-queue`; undercover
misattributes it).

Rulings (orchestrator, adopting the phase sheet's defaults G1-G10):
- G1: `org-iw-visit-next` keeps one required QUEUE; its interactive spec
  gives the session's queue unless there is no session or a prefix arg,
  else prompts. G2: two scans per prompting call, accepted.
- G3: "T is the only entry in queue NAME" is a report (with the problems
  suffix), not a refusal; no write, no navigation, session kept.
- G4: Continue's visit echoes "IW NAME 1/N: NEXT", then Continue's own
  message replaces it; Continue returns its own.
- G5: end-session is idempotent: "org-iw session ended" / "No org-iw
  session", returned. Other `global-mode-string` items are kept.
- G6 wordings: "no session; run org-iw-visit-next first", "T is no
  longer in queue NAME" (T from the session), "ID X is duplicated; T not
  moved", "T already at end. Now 1/N: NEXT", "Moved T to end STATUS.
  Now 1/N: NEXT".
- G7: a refusal from the next entry's visit after a successful write
  propagates; not tested (as allowed).
- G8: T and NEXT in Continue's messages are the scanned titles; only the
  "no longer in queue" / "duplicated" refusals use the session title.
- G9, G10: see PHASE-08 below.

Outcomes:
- Strictly test-first: every branch had its test run red before code.
  Red conditions: void-function (`--session-create`, `--mode-line`,
  `--visit`, `visit-next`, `end-session`, `continue`), `commandp` for the
  interactive tests; no session -> `wrong-type-argument org-iw--session`;
  removed entry -> `wrong-type-argument org-iw-entry nil`; duplicated ID
  -> the refusal "A is no longer in queue ESSAYS" (this is the planned
  proof: without the excluded-ID branch a duplicate reads as "no longer
  in queue"); only entry -> wrote D, then failed visiting nil; already
  last -> rewrote A and reported "Moved"; rank limit -> `wrong-type-argument
  numberp nil`.
- Green on first run, proven by mutation: Continue propagating a write
  refusal (changed on disk; swallowing put-rank's refusal fails it); the
  unsaved and save-failed reports (forcing "(saved)" fails both;
  signalling on save-failed fails the navigation check); the problems
  suffix (dropping it in `--report` fails it). These reuse
  `--save-status` / `--report` from PHASE-06, so no code was written for
  them.
- Found by T3: a buffer narrowed to the previous subtree ends exactly at
  the next heading, so the marker equals `point-max` and "inside the
  narrowing" held while the heading was hidden (`org-fold-reveal`
  signalled end-of-buffer). Visit widens unless point-min <= marker <
  point-max.
- EX-4 (F-3) holds: after an unsaved edit in a directory source, with the
  lock file `.#a.org` present (asserted; appears on 30.2 and 31.1),
  Continue reports "queue change not saved", the disk is unchanged, the
  buffer holds the new rank, and B is visited.
- EX-5 (F-1) holds: with a same-file copy of the session ID (added in the
  buffer, unsaved), Continue refuses "ID a1 is duplicated; A not moved";
  every file and buffer, the session and the window are unchanged.
- I3: Continue acts on the session ID with point moved to C, and with C
  made the front in another file's unsaved buffer (A goes after the
  last of the rest; C visited; b.org stays unsaved).
- `format-mode-line` renders "" in batch (G10), so tests assert the raw
  `org-iw--mode-line` string ("IW[50%% Club: 100%% done]") and the
  construct's single presence in `global-mode-string`.
- `current-message` is nil under `--batch`; visit tests assert the
  returned message instead.
- Grep: 4 autoload cookies (add, visit-next, continue, end-session);
  `org-iw--session` assigned only in `org-iw--visit` and
  `org-iw-end-session` (R3); no `org-find-entry-with-id`,
  `org-entry-properties` or IW regexp in org-iw.el; `verify-vt` PASS for
  PHASE-02..07 (all 11 PHASE-07 keywords present literally in
  test/org-iw-test.el; every PHASE-06 keyword retained).
- No Org 9.7/9.8 differences observed; `org-fold-reveal` and
  `org-fold-show-entry` behave alike on both.

For PHASE-08 (human trial):
- G10: check the mode line shows `IW[Name: Title]` after visit-next; a
  queue name or title containing `%` shows a single `%`; it disappears
  after `M-x org-iw-end-session`, and other `global-mode-string` items
  stay.
- G9: a `global-mode-string` set to a bare string (not a list) makes the
  first visit signal in `add-to-list`; unhandled, SL-005 candidate.
- `pop-to-buffer-same-window` from a dedicated or minibuffer window may
  show the entry elsewhere; batch cannot show it.
- Continue shows two echoes in quick succession (G4); only the second
  stays visible, both are in *Messages*.

## PHASE-08 (2026-10-01) — completed, 8d5909f, 64b8e53

- G9 resolved in `org-iw.el`: `org-iw--visit` wraps a non-list
  `global-mode-string` into a one-element list before `add-to-list`;
  `org-iw-end-session` deletes our item only when the value is a list.
  Prepend order kept. Test
  `org-iw-cmd-test-mode-line-item-with-non-list-global-mode-string`
  (red: `wrong-type-argument listp "user"`; now green).
- Ruling: the string stays a one-element list after end-session (not
  restored to a bare string); content intact. A single-construct list
  value such as `(:eval ...)` is indistinguishable from a list of items
  and is out of scope.
- VA-1 green: `just lint` 0 diagnostics/warnings; `just test-all` 135/135
  on Emacs 31.1 and 30.2. VH-1 (human trial) pending; phase stays
  `in_progress`.
- README.md added at the user's request (2026-10-01), so the VH-1 trial
  runs against their real corpus from documented usage: install,
  configure, commands, write/save semantics, refusals, dev recipes.
  Sandbox trial kit: /home/scratch/sl-001-trial/ (TRIAL.md).
- VH-1 trial on the user's real corpus (2026-10-01): steps 1–3 pass, and
  the mode line, end-session and messages behave as described. Step 4
  (unsaved edit, then Continue) was not observed: the user's auto-save
  hook saves the buffer first. Covered in batch by
  `org-iw-cmd-test-continue-leaves-dirty-buffer-unsaved`. N2 confirmed
  (`…shpool]Thu …`); fixed by a trailing space on the mode-line item
  (test first: 2 red, then 135/135 green on 31.1 and 30.2; lint clean).
- Step 4 then passed: the user ran `M-: (org-iw-continue)` straight after
  an edit, before their save hook fired, and got the "buffer has unsaved
  changes … not saved" message. VH-1 held; PHASE-08 completed.
- User's headline finding: one vertical slice in, org-iw is usable on
  real notes — evidence for RFC-001's vertical delivery.

## Audit remediation (RV-002)

### R1 — test safety net before R2 (test-only; no production change)

- F-17: `scan-without-buffers` compares only corpus buffers (fails alone
  before: ` *code-conversion-work*`). New `just test-each [bin]` runs each ERT
  test in its own Emacs (not a gate). Run once: 143 tests, all pass alone on
  Emacs 31.1 and 30.2. It reports the pre-fix test as `FAIL alone`.
- F-18: ported probes as `org-iw-cmd-test-add-refuses-nonmember-shared-id-in-file`
  (A1), `-add-drawerless-before-drawer-heading` (B2),
  `-visit-next-narrowed-to-later-subtree` (B3),
  `-visit-next-reveals-nested-folded-entry` (D12). Each mutant killed by its
  test alone.
- F-19: `org-iw-discovery-test-fixture-snapshot-detects-change` and
  `-state-detects-change`; killed helper mutants: return nil, drop text, flag,
  disk, buffers.
- F-21: `org-iw-core-test-rank-limit-literal`; kills C4 (`(expt 2 53)`).
- F-22: `org-iw-cmd-test-visit-message` now goes through `org-iw-visit-next`
  (adds DRAFTS 1/1); kills a wrong-total mutant. Position is always 1 via
  Visit and Continue, so only total is pinned. `org-iw--visit` taking pos/total
  is an R2 concern.
- F-25: `org-iw-discovery-test-files-skip-fifo` with new helper
  `org-iw-test-make-fifo` (mkfifo; Emacs 30/31 have no `make-fifo`); kills D10.
- Gate: `just lint` clean; `just test-all` 143/143 on 31.1 and 30.2.

### R2a — POL-002 DRY and legibility

- F-7: core `org-iw-core-refuse FORMAT-STRING &rest ARGS` is the one
  `org-iw-refusal` constructor (`format`, not `format-message`).
  `org-iw--refuse` deleted, its 10 calls now go to core;
  `org-iw-write--refuse` and `org-iw-discovery--refuse` keep only their
  prefixes. Resolve's causes reworded to "duplicated, excluded from the
  queue", "not found", "ambiguous, more than one heading" (the message no
  longer says "ID" twice). No test edit needed.
- F-9: `org-iw-discovery-base-buffer &optional BUFFER` is the one base-buffer
  helper (replaces `org-iw-write--base`, `org-iw--buffer-truename`'s and
  `--id-positions`' hand-rolled forms). `org-iw-test-base` stays independent
  (docstring says so): an oracle must not call the code under test.
- F-10: `org-with-point-at` in write preflight, write apply (inside the
  outer `with-current-buffer`/`atomic-change-group`) and `--check-heading`.
- F-6: core `org-iw-core-rank-p`, the one limit test (`parse-rank`,
  `append-rank`, put-rank's `cl-check-type` on RANK). New tests
  `org-iw-core-test-rank-p`, `org-iw-write-test-rank-is-checked`.
  Red: 1.5 returned `saved` ("did not signal an error", corpus changed).
- F-8: core `org-iw-core-canonical-queue-id-p`; put-rank `cl-check-type`s
  QUEUE and no longer canonicalises or refuses. `invalid queue ID` has one
  owner, `org-iw--queue-id`. New `org-iw-core-test-canonical-queue-id-p`;
  `org-iw-write-test-refuses-invalid-queue` became
  `org-iw-write-test-queue-is-checked`. Red: "ESS_AYS" signalled
  `org-iw-refusal`, not `wrong-type-argument`. `saves-clean-buffer` passes
  "ESSAYS" now (the any-case contract is gone).
- F-12: `org-iw--session-start QUEUE ENTRY` / `org-iw--session-end` own the
  session variable and its `global-mode-string` item; `--visit` and
  `org-iw-end-session` call them (the IMP-001 seam; IMP-001 not done).
- F-13: `--check-heading` docstring self-contained. F-14: comment on `Add`'s
  interactive spec. F-16: `moved` -> `save-status`, `string-match` ->
  `string-match-p` in `classify-property`.
- Process note: the core predicates were written in the same edit as steps
  1-4, before their tests, so the two core tests were never seen red (they
  are one-line predicates; the write-level red proves the contract).
- Gate: `just lint` clean; `just test-all` 146/146 on 31.1 and 30.2;
  `just test-each` 146 pass alone.

### R2b — ADR-003 ownership

- F-15: core `org-iw-core-classify-property` returns `(accumulate . ID)` for
  `IW_<valid id>+` (clause after `reserved`, so `IW_AFTER_…+` stays
  `reserved`; `IW_+`, `IW_ess_ays+`, `IW_ESSAYS++` stay `invalid`).
  `org-iw-discovery--line-class` deleted; `--queue-lines` and
  `--classify-lines` call core. Test changed:
  `org-iw-core-test-classify-property` (accumulate cases added; `IW_ESSAYS+`
  left the invalid list). Red: `(equal invalid (accumulate . "ESSAYS"))`.
- G10 renames: `--entry-id` -> `org-iw-discovery-entry-id ()`,
  `--queue-lines` -> `org-iw-discovery-queue-lines QUEUE` (docstring names
  core as the classifier).
- F-11: discovery gains private `--id-problems SCAN ID` (the one
  problem-by-ID filter) and public `org-iw-discovery-excluded-id-p SCAN ID`
  (replaces `--excluded-id-p`), `-problem-types SCAN ID` (symbols; nil ID ->
  `(missing-id)`), `-shared-id-p SCAN ID FILE`, `-unrecognised-drawer-p ()`.
  org-iw.el loses `--problem-types`, `--shared-id-p`,
  `--unrecognised-drawer-p`; gains pure `org-iw--problem-types-text TYPES`
  (", " join, "unknown" fallback). No test changed.
- F-2: guard in `org-iw-write--preflight`, inside `org-with-point-at`, after
  the compare-and-set, ungated on EXPECTED: "FILE: entry has a property
  drawer Org doesn't recognise". `--check-heading` lost its drawer check and
  docstring clause; put-rank's docstring lists the refusal. New test
  `org-iw-write-test-refuses-unrecognised-drawer`. Red: put-rank with
  `:expected :absent` returned `saved` ("did not signal an error").
  Placement argument checked: integer EXPECTED passes the compare only with
  a member line, read from `org-get-property-block`, and
  `-unrecognised-drawer-p` is nil whenever that block exists. Probed before
  the guard: `:expected 1` on the drawer refused "IW_ESSAYS changed since
  scan", nothing changed; the new test keeps that case.
- Add's change: the message is now "/abs/a.org: entry has a property drawer
  Org doesn't recognise" (was "heading has …", no file), and it comes after
  the rank-limit check. Add tests unedited and green (malformed-drawer,
  ignores-drawer-text-in-block, drawerless-before-drawer-heading B2,
  refusal-order, nonmember-shared-id-in-file A1).
- Closure greps empty: `org-iw-discovery--` in org-iw.el/org-iw-write.el;
  `org-iw-write--` in org-iw.el; `org-property-start-re|outline-next-heading`
  there; `line-class` anywhere. The sheet's `org-iw--(problem-types|…)\b`
  grep matches `org-iw--problem-types-text` (`-` is a word boundary); with
  `([^-[:alnum:]]|$)` it is empty.
- Also re-indented `org-iw--refuse-absent` (R2a's misaligned continuation)
  and the touched defuns with Emacs `indent-region`.
- Gate: `just lint` clean; `just test-all` 147/147 on 31.1 and 30.2;
  `just test-each` 147 pass alone.

### R3 — two new refusals (user rulings 2026-10-01)

- F-1: `org-iw-write--preflight` refuses a read-only base buffer, after the
  `file-writable-p` check: "FILE: buffer is read-only". `org-entry-put` ran
  under `org-no-read-only`, so put-rank, Add and Continue wrote through
  `buffer-read-only`, `read-only-mode` and `view-mode`. Tests:
  `org-iw-write-test-refuses-read-only-buffer`,
  `org-iw-cmd-test-add-refuses-read-only-buffer` (both modes),
  `org-iw-cmd-test-continue-refuses-read-only-buffer`. Red: put-rank
  returned `saved` ("did not signal an error"); the command tests failed the
  same way. After the Continue refusal the session and visit state are
  unchanged (asserted by `--should-refuse-cleanly`), as for the other
  Continue refusals.
- F-3: `org-iw-discovery-resolve` refuses, inside the file's buffer and before
  the ID lookup, when `(derived-mode-p 'org-mode)` is nil: "ID ID in FILE:
  buffer not in Org mode". Tests:
  `org-iw-discovery-test-resolve-refuses-non-org-buffer`,
  `-resolve-accepts-derived-org-mode` (already green; guards the rule's
  breadth), `org-iw-cmd-test-visit-next-refuses-non-org-buffer`. Red: a
  `*Warnings*` buffer appeared (`org-element-at-point` in `text-mode`) and
  visit-next returned "IW ESSAYS 1/1: Member". `org-iw-sources` docstring
  gains the rule.
- Observed, NOT fixed (outside the ruling): Add at a `text-mode` buffer of a
  listed source file still runs Org calls there. It raises 13
  `org-element-at-point` warnings and then a raw
  `(error "Calling `org-fold-core-region' with missing SPEC")`, not a
  refusal. Escalate.

### R4 — mutation re-run gaps (test-only)

- Four tests kill the surviving mutants, each green at HEAD and red under its
  mutant: NF1b `org-iw-write-test-refuses-read-only-base-through-indirect`;
  NF2d `org-iw-write-test-refuses-lowercase-unrecognised-drawer` (Org only
  sees a drawer directly after the heading, so a lowercase one after body text
  is unrecognised: not equivalent); NID1
  `org-iw-discovery-test-duplicate-excludes-only-its-own-id`; NID2
  `org-iw-discovery-test-problem-types-nil-id-is-missing-id`. No production change.
- F-3 extension (user ruling 2026-10-01): `org-iw-add` refuses a source file whose buffer is not in Org mode (derived modes count), before the queue prompt and before any Org parsing (text-mode previously gave ~13 org-element warnings then a raw error). One owner: public `org-iw-discovery-require-org-mode FILE`, used by `org-iw-discovery-resolve` and `org-iw--add-target`. Test `org-iw-cmd-test-add-refuses-non-org-buffer` (red: it prompted; green after). Resolve's message is now "FILE: buffer not in Org mode" (the ID prefix dropped, one message shape for both).


## Design deltas for /reconcile

- § 5.2 `org-iw-core-append-rank` takes `(ORDERED QUEUE)`, not `(ORDERED)`
  (PHASE-02); the user accepted it in session 2026-10-01.
- § 5.2 discovery: the scan struct has constructor `org-iw-scan-create`; § 9:
  the fixture's FILES argument is an evaluated form (PHASE-03 entry).
- *Superseded by RV-002 F-11/F-15 (R2b, below).* § 5.2 says `org-iw-write.el` requires core, `org`, `org-id`, and § 5.1 draws
  no write -> discovery edge; § 5.4 has preflight use the scan's raw-line
  reader. Implemented: write requires `org-iw-discovery` (ADR-003 permits the
  direction) and calls `org-iw-discovery--iw-lines` and `--line-class`.
  Suggest making those two readers public discovery API, since three layers
  now share them.
- § 5.2 step 3 / § 9 / plan PHASE-05 VT-3: "a hook error" via
  `before-save-hook` cannot fail `save-buffer` (errors demoted, Emacs 30 and
  31). `save-failed` arises from `write-file-functions` /
  `write-contents-functions` errors, `write-region` failures (full disk,
  permissions) and the like. Suggest rewording to "a failing save (e.g. a
  `write-file-functions` error)".
- § 5.2: EXPECTED is required (integer or :absent); omitting it signals
  `wrong-type-argument`.
- § 5.2 / § 5.4 (PHASE-06, G3): the per-queue line filter lives in
  discovery as `org-iw-discovery--queue-lines` (moved from write);
  `org-iw-discovery--entry-id` and `--excluded-id-p` were extracted so the
  scan, resolve and Add share one ID read and one duplicate test.
- Plan PHASE-06 EX-3 (G5): with a same-file copy of a member's ID, the
  fresh scan already excludes the member (`duplicate-id`) before Add runs,
  so "the existing member stays in the queue" cannot hold literally.
  Tested instead: Add refuses, nothing changes, and the scan is identical
  before and after; the cross-file case also keeps the member at its rank.
  Suggest rewording EX-3's same-file half to "…and the member's IW_ line and
  the scan are unchanged".
- § 5.4 Add step 6 (G6): stricter than written; Add also refuses an ID the
  scan excluded as a `duplicate-id` (shared by two other files), which
  otherwise passes both written conditions and reports a membership the
  next scan drops. Same intent ("stops Add creating a duplicate").
- § 5.2 `org-iw-add` (G7): returns the message it shows (no-op included);
  the design left the return value open.
- *Superseded by RV-002 F-11/F-15 (R2b, below).* § 5.1 / ADR-003 (G10): the command layer now calls discovery privates
  (`--queue-lines`, `--entry-id`, `--in-block-p`, `--excluded-id-p`) and
  write calls `--queue-lines`. Suggest promoting a small public discovery
  reader API (entry ID, per-queue lines, block test, excluded-ID test).
- § 5.3 (PHASE-07): the session struct has constructor
  `org-iw--session-create`; `org-iw--mode-line-construct` names the
  `global-mode-string` item.
- § 5.2 `org-iw-visit-next` (G1): QUEUE stays required; the interactive
  spec supplies the session's queue (no session or prefix arg -> prompt).
  The design's "(QUEUE; a prefix argument forces the prompt)" read so.
- § 5.4 Continue diagram (G3): the "only entry" branch is a report (not a
  refusal), with no navigation and the session kept.
- § 5.4 Continue (G4, G8): Continue's message replaces the visit's echo
  and is the return value; T and NEXT are the scanned titles.
- § 5.4 Continue (G7): if the next entry's visit refuses after a
  successful write, the refusal propagates; the write stands and the
  session still names the moved entry (a second Continue reports "already
  at end" and retries the visit).
- § 5.4 Visit step 2: "outside the narrowing" includes a marker at
  `point-max` (the heading line is then hidden); visit widens unless
  point-min <= marker < point-max.
- § 5.4 / mode line (line ~390): the item renders `IW[NAME: TITLE] `
  with a trailing space, so it is separated from the next
  `global-mode-string` item (user request after the VH-1 trial,
  2026-10-01).
- Scope: README.md is not in the plan; added in PHASE-08 at the user's
  request (2026-10-01).
- § 5.1 / § 5.2 core (RV-002 F-7, user ruling 2026-10-01): core gains `org-iw-core-refuse FORMAT-STRING &rest ARGS`, the one `org-iw-refusal` constructor (uses `format`). Write keeps a "FILE: " prefix and discovery an "ID X in FILE: " prefix. The command layer calls it directly. Resolve's causes now read "duplicated, excluded from the queue", "not found" and "ambiguous, more than one heading".
- § 5.2 `org-iw-write-put-rank` (RV-002 F-8, user ruling 2026-10-01): QUEUE must be canonical (`org-iw-core-canonical-queue-id-p`), else `wrong-type-argument`, as for EXPECTED. The "invalid queue ID" refusal has one owner, `org-iw--queue-id` in org-iw.el, which § 5.2's private-helper list gains.
- § 5.2 core and put-rank (RV-002 F-6 fix-now disposition 2026-10-01): core gains `org-iw-core-rank-p`, the one limit test, used by `parse-rank`, `append-rank` and put-rank's `cl-check-type` on RANK. An out-of-limit or non-integer RANK is `wrong-type-argument`. This supersedes PHASE-05 gap 5's "RANK not range-checked".
- § 5.2 discovery, write preflight, `org-iw--source-file-p` (RV-002 F-9, user ruling 2026-10-01): `(or (buffer-base-buffer b) b)` is `org-iw-discovery-base-buffer &optional BUFFER`, the one base-buffer helper. `org-iw-write--base` is gone.
- § 5.3 Session (RV-002 F-12 fix-now disposition 2026-10-01): set only by `org-iw--session-start QUEUE ENTRY` (called by `org-iw--visit`) and cleared only by `org-iw--session-end` (called by `org-iw-end-session`). The pair owns the `global-mode-string` item.
- § 5.2 core classify table (RV-002 F-15, user ruling 2026-10-01): a new row `IW_<valid id>+` -> `(accumulate . ID)` before the `invalid` row. `IW_AFTER_…+` stays `reserved`, and `IW_<anything else>+` stays `invalid`. § 5.4 step 4's accumulate rule is now core's classification. `org-iw-discovery--line-class` is gone.
- § 4 / § 5.2 write preflight / § 5.4 Add step 4 (RV-002 F-2, user ruling 2026-10-01): the second-drawer guard is in write preflight, after the compare-and-set. put-rank refuses "FILE: entry has a property drawer Org doesn't recognise" for every caller, and step 4 leaves Add's list. Consequences: Add's message names the file and comes after the rank-limit refusal (step 7). Steps 5 and 6 cannot precede it.
- § 5.1 / § 5.2 discovery / § 5.4 Add (RV-002 F-11 and logged delta G10, user ruling 2026-10-01): discovery's public API gains `org-iw-discovery-entry-id`, `-queue-lines QUEUE`, `-excluded-id-p SCAN ID`, `-problem-types SCAN ID` (symbols), `-shared-id-p SCAN ID FILE` and `-unrecognised-drawer-p`. They share one problem-by-ID filter, `org-iw-discovery--id-problems`. Add steps 5 and 6 read through them, and § 5.4 step 4's "Write preflight and Add step 4 use it" now reads "use it through `org-iw-discovery-queue-lines`". G10 is closed: no file calls another file's `--` private. This supersedes the earlier deltas suggesting promotion (the PHASE-05 "§ 5.2 says `org-iw-write.el` requires …" bullet and the G10 bullet).

- § 5.2 write preflight (RV-002 F-1, user ruling 2026-10-01): gains "base buffer read-only" -> "FILE: buffer is read-only", after the writability check. It applies to every caller, so Add and Continue refuse in `read-only-mode` and `view-mode` too.
- § 5.2 / § 5.4 resolve (RV-002 F-3, user ruling 2026-10-01): `org-iw-discovery-resolve` refuses an entry whose visiting buffer is not `derived-mode-p` `org-mode`: "ID ID in FILE: buffer not in Org mode". The "a file is used as is" wording in design § 5.2 and in the `org-iw-sources` docstring needs the rule (the docstring is updated).

- § 5.2 discovery / § 5.4 Add (RV-002 F-3 extension, user ruling 2026-10-01): Add refuses a non-Org buffer ("FILE: buffer not in Org mode"; derived modes count) in its target check, so interactively it precedes the prompt. Discovery's public API gains `org-iw-discovery-require-org-mode FILE`, the single owner of the rule; resolve uses it too, so its refusal reads "FILE: buffer not in Org mode" (the earlier "ID ID in FILE:" prefix, recorded above, is superseded).

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-01 · reconcile (audit closed) · see HEAD

### Produced
- PHASE-01..08 completed (405af23..64b8e53); VH-1 held on the user's real corpus
- RV-002 audit: 27 findings; 20 fixed (5846207..31fdb54, 8ac1d0b); Synthesis + Reconciliation Brief in review-002.md
- README.md (user request, PHASE-08)
- minted: IMP-001 — public session string / display setting; IMP-002 — one scan per command (SL-004); IMP-003 — consolidate test state-capture helpers; IMP-004 — diagnose invalid org-iw-queues keys (SL-005); CHR-001 — `just mutate` recipe
- Draft standards: STD-001 test quality, STD-002 VT evidence, STD-003 pre-close review roster
- Review artefacts: research/raw/rv-002/ (test-strategy.md, governance-proposals.md, mutation harness and results, remediation sheets)

### Learned
- mem.fact.emacs.save-hook-errors-demoted — before-save-hook can't fail a save
- mem.fact.emacs.batch-test-gotchas — </dev/null, empty display, order-dependent buffer lists
- mem.fact.emacs.org-write-idioms — org-entry-put ignores read-only; atomic-change-group buffer; non-Org warnings
- mem.pattern.doctrine.vt-keywords-match-prose — verify-vt keyword matching traps
- mem.pattern.doctrine.capsule-driver-charter — what a good orchestrator charter carries
- EVD-001 — the vertical slice was usable on real notes (RFC-001)
- Org API sharp edges in design.md § 3

### Open
- /reconcile: RV-002 Reconciliation Brief (design deltas in this file, selectors F-26, POL-001 text F-27)
- QUE-001 — which RV-002 governance proposals to adopt (STD-001..003 drafts and more); settle before SL-002 planning
