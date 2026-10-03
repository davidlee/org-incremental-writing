# ISS-002: Continue writes, then a refused head visit hides the save status

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-007 (architecture reviewer, out of scope). `--continue-place` and
`--continue-remove` (org-iw.el) write first, then visit the new head. If
resolving the head refuses, the write stands but the user sees only the
refusal, not the save status. The same shape has existed since SL-002.
