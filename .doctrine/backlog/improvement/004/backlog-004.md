# IMP-004: Diagnose invalid org-iw-queues keys

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-002 F-4. org-iw.el:114-120 drops `org-iw-queues` entries whose key is
not a valid queue ID (e.g. "bad key", a symbol) silently: the queue never appears
in completion and its name is never shown. Diagnostics belong to SL-005 (design
§4).

From RV-004 F-15 (SL-002 audit). Two entries whose keys differ only in case
(`("A" …)` and `("a" …)`) canonicalise to one queue ID, and `alist-get` makes
the first win silently: since SL-002 that drops the second entry's
`:placements` and `:default`, not only its `:name`. Diagnose (or refuse) a
duplicate canonical key alongside the invalid-key case.
