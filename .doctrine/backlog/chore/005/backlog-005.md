# CHR-005: PRD-001 prose still says documents are identified by Org ID (DEC-021)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found at SL-004 reconcile (2026-10-06); outside the RV-013 brief, so not
edited there. REV-006 brought REQ-002, REQ-007 and REQ-011 in line with
DEC-021: a document's identity is its file-level `:ID:`, else its Denote
filename identifier. PRD-001's prose still says Org ID only:

- `spec-001.md:32`: "Queues whose members are Org documents or Org
  headings with Org IDs."
- `spec-001.md:97`: "A membership is identified by (entry Org ID,
  canonical queue ID)".

Fix: a REV with a prose row against PRD-001.
