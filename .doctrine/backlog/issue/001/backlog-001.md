# ISS-001: put-rank and continue docstrings omit preflight refusals

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found during SL-001 /reconcile (2026-10-01); outside RV-002's findings, so
not fixed there.

- `org-iw-write-put-rank` (org-iw-write.el) docstring lists the refusals
  as changed-on-disk, not writable, EXPECTED mismatch and unrecognised
  drawer. It omits "buffer is read-only" (RV-002 F-1), which preflight
  enforces.
- `org-iw-continue` (org-iw.el) docstring's write-refusal list omits
  read-only and the unrecognised drawer.

Design § 5.2 (write preflight) is the reference. Fix: bring both
docstrings in line; checkdoc/lint stay green.

Resolved by SL-003 (DEC-014), verified at audit RV-011 (2026-10-05):
put-rank's docstring lists "buffer is read-only"; Continue's lists
every write refusal (fixed in SL-002, RV-004 F-5); the new view
commands meet the same standard (RV-011 F-4).
