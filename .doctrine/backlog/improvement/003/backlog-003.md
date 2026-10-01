# IMP-003: Consolidate test state-capture helpers; move fixture self-tests

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-002 F-24. Three overlapping state captures: `org-iw-test-snapshot`,
`org-iw-test-state` (test/org-iw-test-helpers.el:238, :247) and
`org-iw-cmd-test--disks` (test/org-iw-test.el:762). Fixture self-tests live in
test/org-iw-discovery-test.el:81-137 rather than beside the fixture.
test/org-iw-test.el uses the `org-iw-cmd-test-` prefix, which doesn't match its
name. Do after F-19 (oracle self-tests). See
/home/scratch/sl-001-review/test-strategy.md for the proposed helper library split
(corpus / assertion / interaction).
