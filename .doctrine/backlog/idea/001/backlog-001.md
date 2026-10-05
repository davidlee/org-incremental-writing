# IDE-001: Refresh open queue views after org-iw writes

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Asked by the user during the SL-003 PHASE-08 trial (2026-10-05): when a
command in an Org buffer changes a queue, could open views of that queue
refresh themselves?

Today SL-003's design says the view never refreshes itself (§ 5.4,
Refresh); the user presses `g`.

Assessment:
- After org-iw's own writes (Add, Continue, Move, Remove from the
  source) it is small: one helper that redraws each live view of the
  written queue, called from the write path (`--move`, `--delete-rank`,
  `--put-rank`). `--view-redraw` already keeps window point and the mark.
  It must not replace the command's message with the view's count.
  Costs one extra scan per write when a view is open.
- Hand edits and undo in the source don't go through org-iw, so views
  would still go stale after them, notably after undoing a Remove
  (DEC-015's recovery path). Covering those needs a hook (e.g. on save,
  or a timer), which is a design question, not trivial.
- Pairs naturally with IMP-008 (view undo): both are about the view
  tracking its sources.

User clarification (2026-10-05): scope is org-iw's own commands only, not
hand edits. So this is the small case above.
