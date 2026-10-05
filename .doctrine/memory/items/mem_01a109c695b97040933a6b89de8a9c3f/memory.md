`tabulated-list-put-tag` writes into the padding of the printed row. Any
reprint (`tabulated-list-print`) rewrites the rows and drops the tag. The
reprint paths include not just your own `g`/revert, but also the inherited
`tabulated-list-mode-map` keys `{` and `}` (narrow/widen column) and
sorting. A tag re-applied only after your own redraw goes missing on
those paths while the state behind it stays set (RV-009 F-1, SL-003).

Pattern: set a buffer-local `tabulated-list-printer` that calls
`tabulated-list-print-entry` and then tags the row from the state, so
every reprint draws it. `org-iw--view-print-row` / `--view-tag-row` in
org-iw.el.

Related: in `emacs --batch`, `tabulated-list-print` on a buffer shown in
an unselected window resets that window's point to 1 (SL-003 plan notes;
`--view-redraw` sets every window's point).
