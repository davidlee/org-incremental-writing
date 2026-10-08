# ISS-010: Stale *org-iw batch* report survives a clean batch run

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found alongside ISS-008 (2026-10-08). `org-iw--outcome-report`
(`org-iw.el:819`) makes no buffer when every group is empty, and
leaves any existing `*org-iw batch*` untouched. After a run with
trouble, a later clean run says "0 unsaved (not atomic)", yet the old
report buffer still lists the earlier run's files. In the live session
that misled the user's agent into reading the earlier report as
current.

Fix direction: a clean run kills (or empties) the stale report buffer.
Same helper serves redistribution's report (SL-006). Check DEC-028's
"report buffer on trouble" wording covers it.
