# REV REV-005 — reconcile SL-003

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

Reconciles SL-003 against REQ-013 (RV-011 F-3, carried in from RV-005
F-11). DEC-017 accepted a gap: two entries with the same title, the same
parent heading and the same file show the same context, and only the
ordinal tells them apart. Same-named files in different directories look
alike (ASM-001). AC2 promised more than the slice delivers, and the
design (§ 5.5) records the disagreement.

One row: modify REQ-013, acceptance criterion 2.

- Before: "Two entries with the same title are distinguishable by
  file/outline context."
- After: "Two entries with the same title are distinguishable by
  file/outline context, or by ordinal when they share a file and parent
  heading (DEC-017). Same-named files in different directories are not
  told apart (ASM-001)."

## Reconcile narrative

- [RV-011 F-3]: AC2 qualified to match DEC-017's accepted gap, which
  SL-003 implements. Agreed by the user ("agreed", 2026-10-05).
