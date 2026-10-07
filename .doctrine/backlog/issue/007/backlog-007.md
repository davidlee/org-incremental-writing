# ISS-007: Batch add reports a file quit mid-save as stopped (not added) though its edits may stand

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found in SL-006 design review (RV-014 F-14). `org-iw--batch-add-files`'s
`unwind-protect` (`org-iw.el:765-776`) marks every file without an outcome
`stopped` ("not added: the batch stopped"). A quit during the in-flight
file's save, or its save hooks, leaves its edits in place and possibly
saved, so the report understates what changed. SL-006 classifies its
own in-flight file as `interrupted` when its buffer is modified or its
modtime changed, else `stopped`. Batch add could adopt that rule, but
`org-iw-cmd-test-batch-summary-after-error` (`test/org-iw-test.el:1610`,
RV-012 F-7) pins today's text, so it was left out of SL-006's scope.
