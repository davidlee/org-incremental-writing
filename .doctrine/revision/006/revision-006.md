# REV REV-006 — reconcile SL-004

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

Reconciles SL-004 against REQ-002, REQ-007 and REQ-011 (RV-013 F-20,
carried in from RV-012 F-11). DEC-021 settled document identity: the
file-level `:ID:`, else Denote's filename identifier when Denote is
available, else none, in which case Add inserts an `:ID:`. A Denote note
gains no `:ID:`. All three requirements still say entries are
identified by their Org ID; SL-004 implements DEC-021.

Three rows, each a modify.

**REQ-002, description.**

- Before: "Both a whole Org document (file-level property drawer
  preceding the title) and an Org heading are valid entries, identified
  by their Org ID, and memberships are read locally without property
  inheritance."
- After: "Both a whole Org document (file-level property drawer
  preceding the title) and an Org heading are valid entries, and
  memberships are read locally without property inheritance. A heading
  is identified by its Org ID; a document by its file-level Org ID,
  else, when Denote is available, the identifier in its Denote file
  name (DEC-021)."

**REQ-007, description and acceptance criterion 3.**

- Description before: "Entries are resolved by Org ID so refiled
  entries remain members, and missing targets, invalid rank values and
  duplicate IDs produce actionable diagnostics rather than arbitrary
  writes."
- Description after: "Entries are resolved by their identity (REQ-002)
  so refiled entries remain members, and missing targets, invalid rank
  values and duplicate identities produce actionable diagnostics rather
  than arbitrary writes."
- AC3 before: "Two entries sharing an Org ID are reported as an
  ambiguity; no operation writes to either until resolved."
- AC3 after: "Two entries sharing an identity are reported as an
  ambiguity; no operation writes to either until resolved. A document's
  identity counts once, at the document, so a heading that copies it is
  a duplicate."

**REQ-011, description and acceptance criterion 3.**

- Description before: "… appending by default or at another chosen
  placement, ensuring the target has an Org ID."
- Description after: "… appending by default or at another chosen
  placement, ensuring the target has an identity: an Org ID is inserted
  only when it has none (DEC-021)."
- AC3 before: "An entry lacking an ID receives one on enrolment."
- AC3 after: "An entry with no identity receives an Org ID on
  enrolment; a document identified by its Denote file name gains no
  :ID:."

## Reconcile narrative

- [RV-013 F-20]: the identity wording of REQ-002, REQ-007 and REQ-011 now
  states DEC-021, which SL-004 implements (design § 5.2, I2). The user
  assented to the RV-013 reconciliation brief on 2026-10-06 ("handover
  to … 2. reconcile", with no items named for change).
