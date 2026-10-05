# ISS-006: Stale Denote document identity resolves to the first heading in a file with no document slot

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found in the SL-004 audit (RV-013 F-16, 2026-10-06). It is a nit and
needs three coincidences.

In a file with no text before its first heading (no document slot),
`org-iw-discovery--id-positions` adds `point-min` for the document's
Denote identity (org-iw-discovery.el, design § 5.2 contract), and
`org-iw-discovery-resolve` backs up to the heading at `point-min`. The
failure needs all three of:
- a scan taken while the file still had its drawer;
- the user deleting the document drawer before the command;
- the first heading being in the same queue at the same rank.

Then Remove or Move writes to the heading (modelling probe m3,
/home/scratch/sl-004/review/modelling/probe/). Without the equal rank,
the preflight refuses with a misleading "changed since scan".

Fix direction: resolve treats a document identity without a slot as not
found, while the tally keeps counting it for duplicates. This changes
the design § 5.2 `--id-positions` contract.
