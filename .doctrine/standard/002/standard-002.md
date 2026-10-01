# STD-002: VT evidence

## Statement

Rules for authoring a plan's VT (verified-by-test)
criteria:

1. A VT's `keywords` name `ert-deftest` test names or symbols used in test
   code. They never name text that appears only in comments, docstrings or
   string literals, or user-facing message text.
2. A VT's `test_file` contains tests. It never points at a helper library
   or fixture alone.
3. Tests and docstrings are never shaped to satisfy `verify-vt`. A test
   moved, renamed or reached through a helper is followed by re-keying
   the VT (via the plan's append rule), not by adding keyword "bait".
4. A worker checks its VT rows after committing; `verify-vt` reads
   committed files only.

## Rationale

RV-002 F-20: in SL-001, several VT keywords were met only by comments and
docstrings added when a helper moved out of the keyword's file. One
`test_file` was the helper library, so it proved the helpers existed, not
that a test did. One row passed before its test existed. Message-text
keywords tied `plan.toml` to UX wording. `verify-vt` matches keywords
literally anywhere in the committed file, so it rewards the wrong test
shape unless VTs are written this way.

## Scope

Every `plan.toml` VT authored from SL-002 on. SL-001's VTs stand
(tolerated at RV-002 F-20; criteria are immutable).

## Verification

- Plan review: `/plan` and design review check new VTs against items 1 and
  2.
- Mechanical check: `.doctrine/slice/001/research/raw/rv-002/mutation/vt_prose_check.py`
  flags keywords found only in prose. A candidate lint recipe.
- Framework feedback: the matching weakness is in Doctrine's `verify-vt`
  itself and is worth reporting upstream.

## References

- RV-002 F-20; mem.pattern.doctrine.vt-keywords-match-prose.
- STD-001 (test quality).
