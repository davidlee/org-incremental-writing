# POL-002: One implementation per concept

## Statement

- A **concept** is a rule, invariant or message contract that two callers
  must agree on: a validity test, a limit, a refusal and its wording, a
  reader of source state. An incidental idiom becomes a concept once it
  recurs (STD-004).
- Each concept (queue ordering, entry resolution, property writes,
  placement, save policy, and so on) has exactly one implementation.
- Before writing new code, search for an existing owner and adapt or
  extend it. Don't write a parallel version.
- Duplicated or parallel logic is a blocking review finding, even when the
  duplication is small. Confirmed duplication is fixed before the slice
  closes. It is never deferred to the backlog unless the user waives it
  explicitly.
- When code is replaced, the old path is deleted in the same change. No
  dead paths or "legacy" branches.
- No speculative abstraction: no wrappers, options or extension points
  without a current caller.
- Write less code: the smallest change that satisfies the requirement.

## Rationale

Generative development makes new code cheap and reading existing code
comparatively expensive, so the natural failure mode is a growing set of
near-duplicates that drift. In this library that would mean two notions
of "the current queue" or two rank writers disagreeing about the user's
files. Keeping one owner per concept keeps behaviour coherent and the
codebase small enough to hold in mind.

## Scope

All source and test code, including test helpers and fixtures. It applies
to agents and humans alike.

## Verification

- Design names the existing owner that each change extends.
- Code review and audit flag duplication as blocking.
- ADR-003's layering makes owners locatable.

## References

- ADR-003.
- RFC-001 governance candidate P2.
- REV-002; RV-002 F-7..F-9 (reviewers proposed deferral; user ruled
  fix-now, 2026-10-01).
