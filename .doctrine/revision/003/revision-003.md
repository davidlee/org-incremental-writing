# REV REV-003 — reconcile SL-002

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

PRD-001 § 8 still lists OQ-3 (standard placement depths) as open; DEC-009
settled it and SL-002 implemented it. One `modify` row on PRD-001: annotate
OQ-3 as settled. No requirement changes.

Before:

> - OQ-3 — Default placement depths for the standard Soon / Later / End
>   vocabulary (brief suggests after-2, halfway, tail). Confirm before the
>   session slice.

After: the same, followed by

> **Settled** by DEC-009 (2026-10-01), implemented by SL-002: Soon
> `(after 2)`, Later `(fraction 1 2)`, End `end`, in that chooser order;
> default End. Revisit the default once SL-006 lands.

## Reconcile narrative

- [RV-004 F-19]: PRD-001 OQ-3 still read as open after DEC-009 settled it.
  Annotated as settled, citing DEC-009 and SL-002. User agreed in session
  (2026-10-01, "agreed").
