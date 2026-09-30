# POL-001: Lint and test gate

## Statement

- Lint after every change to an Elisp file. Byte-compile with warnings as
  errors, checkdoc and package-lint must all report zero warnings.
- The ERT suite passes in batch on every supported Emacs (currently 30
  and 31).
- Work is test-first: red, green, refactor. The refactor step is
  mandatory.
- Tests check observable behaviour, not trivial implementation. Fixtures
  and helpers are improved in preference to repeated setup code.
- No phase or slice closes red or with lint warnings.

## Rationale

The library edits the user's writing. Regressions in ordering or
preservation are costly and quiet. A tight, always-green gate catches them
while the change is still small. Generated code in particular needs a
mechanical check that doesn't depend on a reviewer's attention.

## Scope

All Elisp in this repository, source and tests. Excludes doctrine
metadata and prose docs.

## Verification

`make lint` and `make test` (with every supported Emacs) run before a
phase is marked completed. The audit checks the evidence. The Makefile
targets are established in SL-001.

## References

- PRD-001 § 7; REQ-024.
- RFC-001 governance candidate P1.
