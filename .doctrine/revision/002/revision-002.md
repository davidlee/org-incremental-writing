# REV REV-002 — adopt RV-002 governance (QUE-001)

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

Settles QUE-001 (RV-002 § Proposed governance). Two prose amendments; user assent "agreed" (session 2026-10-01).

## Reconcile narrative

- ADR-003 gains "Ownership at the boundaries" and a lint verification line (RV-002 F-1, F-2, F-11, G10).
- POL-002 defines a concept and forbids deferring confirmed duplication (RV-002 F-7..F-9).

## ADR-003 after-excerpt

(inserted in ## Decision, after "Each layer has one owner per concept …")

**Ownership at the boundaries** (amended 2026-10-01, REV-002):

- Every guard on a write, including file, buffer, stale-value and
  drawer-shape checks, lives in the mutation layer's preflight, so every
  caller gets it.
- Every reader of Org structure and every scan query lives in discovery,
  behind public (non-`--`) functions. Mutation and commands read the
  entry only through them; the mutation layer may depend on discovery.
- Commands compose the layers and let their refusals surface. They own
  only their own preconditions (session, point, typed input).

(appended to ## Verification)

- No source file uses another file's `--` symbols (STD-004 lint).

## POL-002 after-excerpt

(## Statement, new first bullet)

- A **concept** is a rule, invariant or message contract that two callers
  must agree on: a validity test, a limit, a refusal and its wording, a
  reader of source state. An incidental idiom becomes a concept once it
  recurs (STD-004).

(## Statement, the "blocking review finding" bullet gains)

  Confirmed duplication is fixed before the slice closes. It is never
  deferred to the backlog unless the user waives it explicitly.

(## References gains) RV-002 F-7..F-9 (reviewers proposed deferral; user ruled fix-now, 2026-10-01).
