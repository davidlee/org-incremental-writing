# RV-002 verifier — proposed governance (2026-10-01)

1. STANDARD test quality (high, before SL-003): every test passes alone and in any order;
   every oracle helper has a self-test proving it detects change; every guard/refusal branch
   added in a phase is killed by some test. Enforce: `just test-isolated`, `just mutate`
   (curated mutant list per layer, end-of-phase gate; survivors need recorded justification),
   review checklist. Evidence: F-17, F-19, F-24, F-18, F-21, F-25.
2. STANDARD VT evidence (high): VT keywords name ert-deftest names or symbols in code forms,
   never comments/docstrings/strings; test_file must contain tests. Enforce: port
   vt_prose_check.py to a lint recipe; framework feedback to Doctrine. Evidence: F-20.
3. ADR-003 amendment via REV (or new ADR) write-safety and reader ownership (high, before
   SL-003/004): every write guard in write preflight; every Org/scan reader and diagnostic
   query in discovery, behind public (non `--`) functions; commands compose and let refusals
   surface. Enforce: design review + lint in 4. Evidence: F-1, F-2, F-11, logged G10.
4. STANDARD Elisp module conventions (medium): `--` symbols file-private; cross-file use
   must be public and documented; one refusal constructor (core); one owner per recurring
   idiom; pure functions don't clobber match data; prefer Org/Emacs primitives. Enforce: grep
   lint failing on org-iw-<layer>-- referenced outside its file (tests whitelisted).
   Evidence: F-7..F-10, F-16, G10.
5. POL-002 clarification (medium): define "concept" (rule / invariant / message contract two
   callers must agree on) vs incidental idiom; confirmed duplication resolved before close,
   never deferred. Evidence: reviewers rated F-7..F-9 follow-up despite POL-002 "blocking".
6. DEC-003 clarification (low, for SL-004): a command, including its interactive spec, scans
   exactly once. Enforce: scan-counter test per command. Evidence: F-5, F-14.

Not proposed: message/UX standard (SL-005's design should own refusal format).
Test strategy for future slices: test-strategy.md (same directory).
Mutation harness and probes: mutation/.
