# IMP-004: Diagnose invalid org-iw-queues keys

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-002 F-4. org-iw.el:114-120 drops `org-iw-queues` entries whose key is
not a valid queue ID (e.g. "bad key", a symbol) silently: the queue never appears
in completion and its name is never shown. Diagnostics belong to SL-005 (design
§4).
