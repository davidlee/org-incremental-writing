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
