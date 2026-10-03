# REV REV-004 — ADR-003 post-edit checks; ADR-004 write-path wording (RV-006 F-3)

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

Settles RV-006 F-3: drift between ADR-003 (as amended by REV-002: every
reader of Org structure lives in discovery) and SL-003 design § 5.2, whose
`org-iw-write-delete-rank` calls `org-get-property-block` after
`org-entry-delete` to confirm the drawer survived. The user ruled to amend
the ADR (session 2026-10-03, "update the ADR"). The same reply settles the
stale ADR-004 wording "the one write path": there are now two write verbs
(put-rank, delete-rank) sharing one preflight and apply.

## Reconcile narrative

- ADR-003: the discovery-reader bullet gains a narrow exception for
  post-edit invariant checks in the mutation layer.
- ADR-004: decision item 5 names the mutation layer's shared write path.

## ADR-003 after-excerpt

(## Decision, "Ownership at the boundaries", second bullet gains)

  One exception: after its own edit, the mutation layer may read the
  structure it just changed to check an invariant (for example, that the
  property drawer survived a delete). The check only decides whether to
  roll back; it never feeds a decision about the entry.

(## References gains) REV-004 (post-edit check exception, from RV-006 F-3).

## ADR-004 after-excerpt

(## Decision, item 5, last sentence)

Before: It goes through the one write path (ADR-002, ADR-003).
After:  It writes through the mutation layer's shared preflight and
        apply, as every rank write and delete does (ADR-002, ADR-003).
