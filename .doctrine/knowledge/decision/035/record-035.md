# DEC-035: Redistribution ranks are k*1024 from k=1; members already at target are skipped

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->


Spacing value reviewed 2026-10-06 (user: "keep 1024 for now"). Exhaustion frequency depends on same-gap placements (~log2 s), not queue size (EVD-002), so per-queue spacing was rejected; a larger single constant (2^16, 2^20) was weighed against rank readability. ADR-004 rule 2 leaves the value to design; revisit only if the VH trial shows redistribution is frequent.