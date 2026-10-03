# ISS-003: outline-text right-end cut assumes a one-column ellipsis

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-007 (test reviewer, out of scope). `org-iw--outline-text`
cuts the right end at `(- width 2)` for "…/", assuming "…" is one column.
Where ambiguous-width characters are two columns wide (CJK settings),
the result is WIDTH+1. The ancestor-drop loop measures correctly.
