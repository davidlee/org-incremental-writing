# IMP-011: Redistribution preview mode with approve/cancel keys

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

SL-006 inq-7 chose a synchronous preview: a special-mode buffer, then a
`y-or-n-p` (DEC-037). When something blocks (unsaved or unwritable targets,
DEC-029/DEC-030), the user resolves it and re-runs the triggering command.

Improvement: a preview mode with approve/cancel keys (`C-c C-c` / `C-c C-k`)
holding the plan and pending operation buffer-locally, so the user can
browse, resolve and approve in place. The approve-time recheck (DEC-033)
already makes deferred approval safe. Cost: a stored continuation (incl.
Continue's head visit), buffer-local state, key-driven tests.

Consider if the SL-006 VH trial finds re-running after resolution tiresome.
