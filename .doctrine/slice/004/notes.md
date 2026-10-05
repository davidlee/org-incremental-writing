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
