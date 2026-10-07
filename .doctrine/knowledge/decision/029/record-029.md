# DEC-029: Redistribution refuses approval while an affected buffer is unsaved

<!-- Knowledge record body — context, detail, links. The structured, queried
     fields live in the sister `record-NNN.toml`; this prose is free-form and is
     never structurally parsed (the storage rule). -->


Amended 2026-10-07 in design review (RV-014 F-1, user 'yes.'). The original choice blocked approval while any affected buffer was modified. That stalled the common edit-then-Continue path, where the entry's own buffer is usually unsaved. The user also weighed exempting the pending entry's file and deferring to IMP-011, and chose consent inside the single approval prompt.