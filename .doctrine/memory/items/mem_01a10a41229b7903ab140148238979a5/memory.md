Checked 2026-10-05 against Denote 4.2.3 (SL-004 design, RV-012 F-3):
- `denote-filename-is-note-p` and `denote-file-is-note-p` are obsolete aliases
  (since 4.1.0) of `denote-file-has-denoted-filename-p`, which checks only the
  file-naming scheme — not `denote-directory`, not the extension.
- `denote-file-is-in-denote-directory-p` calls `denote-directories`, which runs
  `make-directory`: a side effect, avoid in readers.
- `denote-retrieve-filename-identifier` handles both forms: a leading
  `YYYYMMDDTHHMMSS` and `@@ID` anywhere. Denote treats the file name, not
  `#+identifier:`, as the identifier's source of truth.
- None of these are autoloaded: `fboundp` depends on load order; soft-load with
  `(require 'denote nil t)` (catch load errors).
- In this repo's dev shell, `emacs` (31) finds Denote under `-Q` (its site-lisp
  carries it); `emacs-30` does not. Tests whose result depends on Denote must
  control for it, or they pass on one binary and fail on the other.
- With only `declare-function`, byte-compile won't warn about an obsolete Denote
  name; only a test with Denote loaded catches it.
