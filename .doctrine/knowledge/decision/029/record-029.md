# DEC-029: Redistribution saves unsaved affected buffers only on the approval prompt's explicit yes

Amended 2026-10-07 in design review (RV-014 F-1, user 'yes.'). The original choice blocked approval while any affected buffer was modified. That stalled the common edit-then-Continue path, where the entry's own buffer is usually unsaved. The user also weighed exempting the pending entry's file and deferring to IMP-011, and chose consent inside the single approval prompt.

The consented save departs from ADR-002's save policy and REQ-021 AC2 as written; REV-007 amends both (RV-014 F-3, user chose to amend, 2026-10-07). The slug still carries the original wording; the CLI offers no slug edit.
