- A batch test that reaches a minibuffer prompt with stdin open blocks for
  minutes instead of failing: run `just test`/`test-all` with `</dev/null`.
- Under `--batch`, `current-message` is always nil and `format-mode-line`
  returns "": assert on return values and `*Messages*`, and leave display to
  the human trial.
- The first `insert-file-contents` in a fresh Emacs creates the internal
  buffer ` *code-conversion-work*`; a test comparing `(buffer-list)` passes
  in-suite but fails alone. Compare only non-space-prefixed or
  fixture-owned buffers (RV-002 F-17). Use `just test-each` to catch order
  dependence.
- Clearing a buffer's modified flag releases its lock file; a dangling `.#`
  lock symlink is already dropped by a regular-file check.
- Advising an inlined cl-defstruct accessor silently does nothing.
