# CHR-004: SL-001 PHASE-02 VT-3 keys org-iw-core-append-rank, deleted by SL-002

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found during the SL-003 audit (RV-011, 2026-10-05). `doctrine slice
verify-vt SL-001` fails PHASE-02 VT-3: the keyword
`org-iw-core-append-rank` is absent from `test/org-iw-core-test.el`.
SL-002 deleted `append-rank` (POL-002, RV-004), so the row has been
stale since SL-002 closed. Fix: re-key the row by the append rule
(STD-002 item 3), naming the tests that now cover its expectation, and
waive the old row.

Also (SL-004 audit, RV-013, 2026-10-06): SL-001 PHASE-07 VT-2 fails on
keyword `already at end`, a message SL-002 removed in 126e91f (Continue
at a placement). Same fix: re-key by the append rule, waive the old row.
