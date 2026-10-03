# QUE-002: Should Denote's identifier serve as entry identity instead of an Org ID?

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->

Raised by the user during SL-003 design (2026-10-03). Denote Org files carry
their identifier in the filename and a `#+identifier:` keyword, not an `:ID:`
drawer. Today, enrolling one as a document entry (SL-004) works: Add gives it
an Org ID alongside the identifier, which is redundant but harmless. The
membership lives in a file-level property drawer anyway (ADR-001).

Using the Denote identifier as identity would change four discovery/write
sites, and REQ-002 / REQ-007 ("identified by their Org ID"):
- `org-iw-discovery-entry-id`, the single ID reader;
- the `:ID:` line tally (`--id-line-regexp`, `--id-lines`, `--id-values`);
- `--id-positions` / `org-iw-discovery-resolve`;
- `org-id-get-create` in `org-iw-write-put-rank`;
plus the test fixtures.

Nothing assumes numeric IDs: they are opaque strings (`string=`, `string<`
tie-break, hash tally). SL-003 adds no identity reader, so deferral costs
nothing extra as long as identity stays behind discovery (ADR-003).

Decide before SL-004 builds document enrolment. Options: keep Org ID only;
accept `#+identifier:` as an alternative identity for document entries;
leave it to an optional adapter (PRD-001 excludes required Denote support).

Refinement (user, 2026-10-03, SL-003 inq-6): properties before the first
heading belong to the document — uncontroversial. Open: must a document's
properties always include an explicit ID; if missing, is one inserted on
write (and with what scheme, e.g. Denote identifier, org-id-method), or is
identity inferred from `#+identifier:` / the filename when absent? SL-003's
Move/Remove act only on members discovery admitted (which today requires
`:ID:`) and never insert an ID, so they inherit whatever this settles.
