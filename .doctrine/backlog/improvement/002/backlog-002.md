# IMP-002: One scan per command, including the interactive spec

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

From RV-002 F-5 (and F-14). Interactive `org-iw-add` scans twice and walks the
source tree four times (org-iw.el:307-311); `org-iw-visit-next` without a session
scans twice (:368-373). DEC-003 says every operation rescans, not "once"; this
doubles the journal-scale cost (~1 s → ~2 s). Surviving mutant A16 (extra scan).
Fix: pass the interactive scan into the body, or prompt from a scan the body reuses;
add a scan-counter test per command. Fold into SL-004's scan re-measure; clarify
DEC-003 as "a command, including its interactive spec, scans exactly once".
