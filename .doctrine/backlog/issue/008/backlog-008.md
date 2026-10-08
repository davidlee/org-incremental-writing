# ISS-008: Write reports saved when a save hook leaves the buffer modified

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found 2026-10-08 investigating a live batch add to LEARN-EMACS: "Added
16, 10 unsaved". The report listed the 10 files the batch had opened
itself as `(saved); buffer left open, modified`. Their ranks were on
disk, and the buffers were clean afterwards (super-save likely saved
them later). `*Messages*` shows each was freshly visited (an
Undo-Fu-Session find-file line), so they were not already open. otpp's
kill-buffer advice did not fire (its "burying it instead" message is absent).

`org-iw-write--save` (`org-iw-write.el:152`) returns `saved` once
`save-buffer` returns, without checking the buffer afterwards.
`org-iw-write-save-file` (`org-iw-write.el:319`) already does that
check and returns `(save-failed . still-modified)` when a save hook
re-dirtied the buffer. Two save paths for one concept (POL-002), and
the weaker one feeds `org-iw-write-put-rank(s)`. So under DEC-026 a
buffer a hook re-dirtied is correctly kept, but its status still says
`(saved)`, contradicting "modified" on the same line.

Fix: one save helper that reports `still-modified`, used by both
paths. That also gives the diagnostic for the unexplained trigger: the
next interactive run would say which files a hook dirtied after save.
Not reproduced in `emacs -Q` or through `emacsclient` on copies of the
affected notes; the trigger was only present in the interactive run.
