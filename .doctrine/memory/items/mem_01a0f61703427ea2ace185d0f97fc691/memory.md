- With a non-nil string DEF and no input, icomplete (and fido) bubble DEF
  to the top of the candidates (`icomplete--sorted-completions`, Emacs
  31.1). Vertico does the same (RV-003 F-1).
- A completion table whose metadata sets `display-sort-function` to
  `identity` keeps the *other* candidates in order, but not DEF's place.
- Dropping DEF to keep strict order breaks "RET = default" in those UIs:
  RET then picks the first candidate.
- org-iw accepts "default first, rest in configured order" (DEC-011).
