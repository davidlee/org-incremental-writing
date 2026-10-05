# IMP-009: Clearer refusal when a source command runs in the queue view

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From the SL-003 PHASE-08 trial (user, 2026-10-05): `M-x org-iw-move` with
point on a queue-view row refuses "*org-iw: NAME* is not under
org-iw-sources". Correct, but it reads as a configuration problem.

Source: `org-iw--target-at-point` (org-iw.el, the `org-iw--source-file-p`
check), shared by Add, Move and Remove. In an `org-iw-view-mode` buffer,
refuse with a pointer to the view's own keys instead, e.g. "in the queue
view, use M-<up>/M-<down>, m then b/a, or D". One owner for the text;
a test per command. (Alternative: act on the row's entry. Larger; it
would need a design.)
