# STD-004: Elisp module conventions

## Statement

Applies on top of POL-001 and ADR-003. Written from SL-001 practice (RFC-001
candidate S1).

1. **Files and headers.** One file per ADR-003 layer (`org-iw-core.el`,
   `org-iw-discovery.el`, `org-iw-write.el`, `org-iw.el`); tests mirror
   them under `test/`. Every file has `lexical-binding: t`.
2. **Names.** Public symbols are `org-iw-<layer>-…` (`org-iw-…` in the
   command layer); private symbols are `org-iw-<layer>--…`. A `--` symbol
   is file-private: no other source file calls or reads it. A function
   another layer needs is made public, with a docstring that stands alone.
3. **Docstrings.** Every function, macro, variable and option has one;
   checkdoc-clean. A docstring never cites design steps or ids that exist
   only outside the code.
4. **Refusals.** Every refusal is `org-iw-core-refuse`; no other
   `signal`/`user-error` for an expected user-facing condition. Each layer
   keeps one prefix helper at most.
5. **One owner per idiom.** A recurring expression (base buffer, ID read,
   queue-ID canonicalisation) gets one named helper (POL-002).
6. **Primitives first.** Prefer an Org or Emacs primitive
   (`org-with-point-at`, `org-with-wide-buffer`, `derived-mode-p`) to a
   hand-rolled equivalent.
7. **Pure means pure.** Core functions don't touch buffers, Org, or match
   data (`string-match-p`, not `string-match`).
8. **Tests.** Tests run against real temporary Org files and buffers
   through the shared fixture (`test/org-iw-test-helpers.el`), never mocks
   of Org. Indentation is Emacs's standard `lisp-indent`.

## Rationale

RV-002 found the duplication and layering drift these rules prevent:
three refusal constructors (F-7), two queue-ID owners (F-8), three
base-buffer expressions (F-9), a hand-rolled `org-with-point-at` (F-10),
match-data and naming slips (F-16), and the command layer calling
discovery privates (F-11, G10). All were fixed in SL-001; this standard
keeps them fixed.

## Scope

All Elisp in this repository from SL-002 on. Item 2's cross-file rule
exempts tests, which may reach privates under STD-001 item 6.

## Verification

- `just lint` (checkdoc, byte-compile) for items 1 and 3.
- A grep lint failing on `org-iw-<layer>--` referenced outside its own
  source file, tests exempt (CHR-002). Until it lands, review checks it.
- Pre-close review (STD-003) for items 4 to 8.

## References

- ADR-003, POL-002, STD-001.
- RV-002 F-7..F-11, F-16; RFC-001 candidate S1.
