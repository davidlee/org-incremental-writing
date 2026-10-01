- `org-entry-put` wraps its edit in `org-no-read-only`, so it writes
  read-only buffers (view-mode, read-only-mode). Check `buffer-read-only`
  on the base buffer yourself if writes must respect it (RV-002 F-1).
- `atomic-change-group` sets up its change group in the CURRENT buffer:
  keep `(with-current-buffer B (atomic-change-group ...))` outside
  `org-with-point-at`.
- `org-with-point-at M` expands to save-excursion + set-buffer +
  `org-with-wide-buffer` + goto-char (Org 9.7.11 and 9.8.10). Use it
  instead of hand-rolling that sequence.
- Org element/property calls in a buffer not in org-mode "work" through
  fallbacks but emit `org-element-at-point' cannot be used in non-Org
  buffer warnings into *Warnings*. Check `(derived-mode-p 'org-mode)`
  first (RV-002 F-3).
- `string-match` clobbers match data. Use `string-match-p` in pure
  predicates.
