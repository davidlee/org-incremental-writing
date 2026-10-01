# CHR-002: Lint: no cross-file use of org-iw-<layer>-- privates

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Verification for STD-004 item 2 and ADR-003's ownership amendment (REV-002).
A `just` recipe (folded into `just lint`) that fails when a source file
references `org-iw-<layer>--` symbols defined in another source file.
Tests (`test/`) are exempt. Source passes today (checked 2026-10-01). Until
it lands, pre-close review checks the rule.
