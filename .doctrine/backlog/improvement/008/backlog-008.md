# IMP-008: Queue view undo; D without confirmation

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Raised by the user during the SL-003 PHASE-08 trial (2026-10-05). Deferred
to its own slice; SL-003 keeps D's confirmation.

Idea: D removes without asking, and the view gets an undo (remap `undo`,
so `C-/` / `C-x u` in the view undo the view's last write; `u` is taken
by unmark). This reverses DEC-019, whose reason for confirming D is that
the view has no undo.

Design questions:
- The view's writes land in several files, so it keeps its own stack of
  (buffer, state after write); undo pops it.
- The user may have edited that buffer since. Plain `undo` there would
  revert their edit, not ours. Record the buffer's state after the write
  (e.g. `buffer-modified-tick`, undo-list head) and refuse if it has
  moved on.
- Undo is a write: it belongs in the write layer (ADR-002, ADR-003),
  with the same preflight (changed on disk, read-only, ...). Save
  policy: if our write saved the file, the undo must save again, or the
  file on disk keeps the deleted line.
- Scope: only the view's own writes, or source Move/Remove too?

Estimate: ~60-80 lines plus tests, a write-layer verb, README.
