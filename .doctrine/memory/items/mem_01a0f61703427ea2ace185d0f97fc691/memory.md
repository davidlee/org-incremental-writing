- With a non-nil string DEF and no input, icomplete (and fido) bubble DEF
  to the top of the candidates (`icomplete--sorted-completions`, Emacs
  31.1). Vertico does the same (RV-003 F-1).
- Two sort keys, two UIs: `completion-all-sorted-completions` (icomplete,
  fido, cycling) sorts by `cycle-sort-function`, falling back to its own
  length/history sort; `*Completions*` uses `display-sort-function`. A
  table that must keep its order sets BOTH to `identity` (checked in
  minibuffer.el, Emacs 31.1, SL-002 PHASE-03). Either one alone keeps
  configured order in only some UIs.
- Dropping DEF to keep strict order breaks "RET = default" in those UIs:
  RET then picks the first candidate.
- org-iw accepts "default first, rest in configured order" (DEC-011).
