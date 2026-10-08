# ISS-009: Left-open outcome reads modified and unsaved from buffer liveness alone

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found alongside ISS-008 (2026-10-08). `org-iw--file-outcome`
(`org-iw.el:843`) appends `left-open` whenever a buffer the batch
opened is still live after the unwind, not when it is modified.
`org-iw--outcome-text` then prints "buffer left open, modified", and
`org-iw--batch-unsaved-p` counts it as unsaved. Anything that keeps a
clean buffer alive misreports it: a `kill-buffer-query-functions`
refusal, or `kill-buffer` advice that buries instead (otpp's
`otpp-bury-on-kill-buffer-when-multiple-tabs`, present in the user's
config).

Reproduced in `emacs -Q --batch`: with a kill-refusing query function,
three clean saved files report `(saved); buffer left open, modified`
and "3 unsaved".

Fix direction: record why the buffer stayed (modified vs. kill refused)
from `buffer-modified-p` at unwind, and word and count each truthfully.
DEC-026's rule (keep a modified buffer, report it) is unchanged. Shared
with redistribution (SL-006), so its report has the same flaw.
