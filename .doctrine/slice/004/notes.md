# Notes SL-004: Documents and batch add

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-05 · design locked → plan · f5bd251

### Produced
- design locked (run dr-01a10a0a…, rev 40); design.md 14 sections, human-attested
- DEC-021..DEC-028 (DEC-021/022/026 amended per RV-012, user "yes")
- RV-012 — design review, 14 findings verified (F-13 tolerated → IMP-010), concluded
- research/research.md — Org document-level probes; 3,000-file scale benchmarks
- QUE-002 answered (DEC-021); minted IDE-002, IMP-010
- 10 design-target selectors (section 10)
- no code changed; gate not run this stage

### Learned
- mem.fact.emacs.denote-api-and-test-emacsen — obsolete Denote predicate; 31 has Denote under -Q, 30 not

### Open
- REV pending at reconcile: REQ-002, REQ-007, REQ-011 identity wording (DEC-021 consequences)
- IMP-010 / IMP-002 — scan cost at thousands of members (DEC-027 constraints bind the plan)
- IDE-002 — CUSTOM_ID heading identity
- ASM-001 — unique source file names (still held)
- CHR-003 — README per slice (design § 10 includes README.md)

## PHASE-01 (2026-10-05, execute)

- flake.nix derives the Denote dir from nixpkgs-unstable
  `emacsPackages.elpaPackages.denote` via a `runCommand` that `find`s
  `denote.el` (no store hash or version literal) and exports
  `ORG_IW_DENOTE_DIR` to the devshell and all jails.
- **Unevaluated in the jail (no nix).** The human must check with
  `nix develop` / a jail restart: `printenv ORG_IW_DENOTE_DIR`;
  `emacs-30 -Q --batch -L "$ORG_IW_DENOTE_DIR" --eval "(require 'denote)"`.
  `just --evaluate denote_load` shows the flag.
- justfile `denote_load` (`-L DIR` when set and non-empty) is used by
  `test`, `test-each` and `coverage` only.
- Gate 327/327 on 31 and 30, with the variable unset and set by hand
  (commit f8d72bf).

## PHASE-02 (2026-10-05, execute)

- Discovery owns document identity: `org-iw-discovery-document-slot-p`,
  `org-iw-discovery-document-id` (file-level `:ID:` when slotted ▸ Denote
  identifier ▸ nil), private `--denote-identifier` / `--denote-available-p`
  (soft load once, `--denote-tried` set first, load error → one
  `display-warning` of type `org-iw`). `entry-id`, `--id-positions`,
  `id-count` take FILE; `--title` → public `org-iw-discovery-title`.
- One enumerator: `--identities (file)` → `(ID . POS)`, document identity
  at `point-min` then `:ID:` lines outside the file-level drawer (drawer
  consulted only when slotted). It is the sole reader of `--id-lines`;
  the scan tally and `--id-positions` both read it. `--id-values` deleted.
  `--at-document-start` macro owns "base buffer, widened, at point-min".
- Test helpers (`test/org-iw-test-helpers.el`):
  `org-iw-test-denote-file IDENTIFIER CONTENT &optional TITLE` → corpus
  pair `IDENTIFIER--TITLE.org`, skips unless Denote loads, asserts Denote
  accepts the name; `org-iw-test-without-denote` (BODY with `denote` out
  of `features` and `--denote-tried` t); `org-iw-test-without-feature`.
- Surprise: `features` is made non-special in C, so `let` binds it
  lexically in lexical-binding code and `featurep` ignores it. Bind it with
  `cl-progv` (`dlet` trips byte-compile's prefix warning). Also: Emacs 31
  warns on loading a .el without a lexical-binding cookie.
- Tests 327 → 340. Gate green unset and set (31 and 30); test-each 340
  all alone on emacs and emacs-30, unset and set. Zero skips on both with
  `ORG_IW_DENOTE_DIR` set by hand; unset, emacs-30 skips exactly the 8
  Denote-route tests.
- Mutation: 22 mutants, 20 killed, 2 equivalent (slot-p without base
  switch: indirect buffers share text; `--check-heading` nil FILE: heading
  branch only until PHASE-03). Table in the phase sheet.

## PHASE-03 (2026-10-05, execute)

- `org-iw-write-put-rank` gains `:document`: guard (plain `error`) that
  MARKER is at its buffer's widened `point-min`; with no document slot,
  EXPECTED must be `:absent` (plain `error`), only the file/buffer
  checks run, and `--apply` inserts `:PROPERTIES:\n:END:\n` at
  `point-min` (save-excursion) before ensure-id and the put — one change
  group, one undo. With a slot, `:document` is a no-op.
- `org-iw-write-delete-rank`: a document entry (`--document-entry-p`:
  widened start AND `org-iw-discovery-document-slot-p`) may lose its
  emptied drawer; classified *before* `--apply`, since a drawer that is
  the only pre-heading text leaves the file slotless once deleted.
  Heading rule unchanged; nothing deleted is an error either way.
- Write internals: `--preflight` = `--check-file` + `--check-entry`;
  `--document-start-p`, `--document-entry-p`. No change to `org-iw.el`
  or discovery: Remove / Continue → Remove of a Denote document worked
  through the PHASE-02 resolve path once the delete rule landed.
- Org facts (both Org 9.8.10/Emacs 31 and 9.7.11/Emacs 30): deleting a
  drawer's last property removes both drawer lines and nothing else;
  `org-id-get-create` at point-min after an inserted empty drawer writes
  into it, aligned (`:ID:       <uuid>`); it signals in a non-file
  buffer.
- PHASE-04 carry: the document marker must have insertion-type nil, or
  it advances past the inserted drawer (sheet R3).
- Tests 340 → 348. Gate green set and unset; test-each 348 all alone on
  emacs and emacs-30, set and unset. Set: 0 skipped on both; unset,
  emacs-30 skips 9 (PHASE-02's 8 + `remove-denote-document`).
- Mutation: 14 targets (M8 split a/b), all killed, 0 equivalent. Table in
  the phase sheet.

## PHASE-04 (2026-10-05, execute)

- One add step (POL-002): `org-iw--add-entry (scan order marker queue
  placement document &optional where)` → `(existing POS)` |
  `(added DEPTH STATUS ENTRY)`, STATUS raw from put-rank. Identity:
  `document-id` for a document, else `entry-id`; IW-line exclusion check
  only for a heading or a slotted document (a slotless file's point-min
  lines are the first heading's); `:ensure-id` only without identity.
  `--check-heading`, `--heading-or-refuse` deleted. Add and Add-document
  share `--add-at` (validate, scan, order, add step, message) and
  `--read-add-args`.
- `--require-source` (source + Org mode, first) and `--document-marker`
  (base buffer, widened, `copy-marker` type nil). `--target-at-point` =
  both + heading marker; a document target is now a base-buffer marker.
- S1 ruling: `org-iw-discovery-entry (file)` public reader at point over
  the private one constructor `org-iw-discovery--entry (file id
  memberships)`, shared with `--read-entry`. ENTRY is read after the
  write, `equal` to the rescanned member (other queues, outline). No
  rescan.
- Replaced `org-iw-cmd-test-add-refuses-document-target` with
  `org-iw-cmd-test-add-before-first-heading-enrols-document`.
  **SL-001 VT-2** keyword "document targets are not yet supported" no
  longer exists in `test/org-iw-test.el` (DEC-023); its verify-vt row
  needs a waiver or annotation.
- VA-1 greps: no `heading-or-refuse` / `check-heading` in org-iw.el;
  `:expected :absent` only at org-iw.el:486 (in `--add-entry`,
  448–489); `org-iw-core-place` calls at 480 (`--add-entry`) and 678
  (`--move`), line 272 is `org-iw-core-placement-p`; "not yet
  supported" absent from org-iw.el and tests.
- Tests 348 → 370 (+22 new, 1 replaced). Gate green set and unset;
  test-each 370 all alone on emacs and emacs-30, set and unset. Set: 0
  skipped. Unset, emacs-30 skips 13: PHASE-02/03's 9 +
  `add-denote-note-no-id`, `add-denote-name-without-denote-gets-id`,
  `add-denote-refuses-heading-sharing-identifier`,
  `add-denote-refuses-identifier-shared-across-files`.
- Mutation: 25 mutants, 23 killed, 2 equivalent (M17b → redundant
  `goto-char` deleted; M18 Add's DOCUMENT flag before the first heading,
  kept as the write's start guard). Two unplanned survivors closed by
  `add-document-refuses-outside-sources`, `target-at-point-heading`.
- Gotcha: a file-level drawer after `#+title:` is not the document's
  drawer; fixtures put it first.
- PHASE-05 carries: the batch bypasses `--require-source` and must pass
  a `--document-marker`-style marker (type nil, base, widened) with
  DOCUMENT t; WHERE nil gives "at the end".

## PHASE-05 (2026-10-05, execute)

- Batch add in `org-iw.el` § Batch add: `org-iw-add-files (queue
  files)` (autoloaded; Dired marks else one `read-file-name`), the fold
  `org-iw--batch-add (scan queue files sources progress)`, the per-file
  step `org-iw--batch-add-file` (non-source, Org mode, F-5 and the
  `--add-entry` call; every "fail" is a refusal), the buffer rule
  `org-iw--call-in-file-buffer (file fn)` (kill in the unwind form
  unless pre-existing or modified), `--batch-summary`,
  `--batch-report`, predicates `--batch-unsaved-p` / `--batch-trouble-p`.
  Per file the fold catches only `org-iw-refusal` (`cadr`) and
  `file-error` (`error-message-string`).
- O1 ruled option E: PROGRESS gets `(FILE . OUTCOME)` after each file;
  the command collects through it and summarises in its
  `unwind-protect` cleanup. Adaptation of design § 5.2's "PROGRESS ...
  (files done)" — reconcile.
- Order: validate → selection → empty refuses → one `org-iw--files` →
  `(org-iw-discovery-scan sources)` (not `org-iw--scan`, which walks
  again). Order extended in memory with each added ENTRY; no rescan.
- Report: canonical order, one line per failed/unsaved file (sheet A8
  grouped them; simplified). Summary through `org-iw--report`.
- Gotchas: `org-iw-discovery-files` keeps an explicitly named non-.org
  file (only directories filter), so it fails as a non-source rather
  than counting as "no Org files"; an uncaught `org-iw-refusal` prints
  as `org-iw refused: "..."` (pre-existing; backlog candidate).
- Tests 370 → 397 (+27, `;;;; Batch add` sections in
  `test/org-iw-test.el`; helpers `--batch`, `--ranks`, `--counting`
  (advice-add), `--diverting`, `--should-fail`, `--last-message`).
  Gate green set and unset; test-each 397 all alone on emacs and
  emacs-30, set and unset. Set: 0 skipped. Unset, emacs-30 skips 15:
  PHASE-04's 13 + `batch-denote-notes-gain-no-id`,
  `batch-second-denote-copy-fails`.
- Mutation: 57 mutants, 55 killed, 2 equivalent (progress-reporter
  done/update: display only). Five unplanned survivors closed by new or
  tightened tests (M3, M37, M43, M44, M51). Table in the phase sheet.
- Timing (T11, -Q, 74 Denote-named files, not committed): first batch
  0.61 s Emacs 31.1 / 0.24 s Emacs 30.2; rerun (all existing) 0.08 /
  0.10 s; walk+scan 5 ms; fold ≈ all (visiting + Org mode). 74 drawers,
  ranks 1024…75776, no `:ID:`, no buffers left.
- Carries: PHASE-06 README — Dired/prompt, canonical order, append only,
  non-sources and excluded fail, not atomic, report buffer, opened
  buffers closed unless modified. PHASE-07 — time under the user's Org
  hooks; watch for prompts from `find-file-noselect` (file-local
  variables are not bound off); progress display unverified in batch.
