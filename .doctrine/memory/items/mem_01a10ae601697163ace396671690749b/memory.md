- In lexical-binding code (test files included), `features` is not a special
  variable (it is made non-special in C), so `(let ((features (remq 'denote
  features))) ...)` binds it lexically. `featurep` still reads the global
  value and still sees Denote: the test does not hide Denote and passes
  vacuously.
- Bind it dynamically instead: `(cl-progv '(features) (list (remq 'denote
  features)) BODY...)`. `dlet` trips byte-compile's prefix warning.
- Working form: `org-iw-test-without-feature` in
  `test/org-iw-test-helpers.el` (SL-004 PHASE-02).
