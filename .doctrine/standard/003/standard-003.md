# STD-003: Pre-close review roster

## Statement

Proposed (draft). The default pre-close code review of a slice (the audit's
code-review lens) runs:

1. **Modelling and architecture reviewer** (opus): domain model,
   invariants, layering and ownership (ADR-003), the write path (ADR-002),
   error handling, and conformance to the letter and spirit of the design.
   It proves behavioural claims by execution.
2. **Test reviewer** (opus): runs a mutation pass over high-risk logic and
   the test oracles, checks every test in isolation, and assesses fixtures
   against STD-001. It reports surviving mutants with ready probe tests.
3. **Verifier** (sonnet by default): re-checks every candidate against the
   cited lines or by execution, corrects severity, and flags fixes that
   would touch a locked design or public API. Opus when findings are
   majors/blockers or behavioural claims are contested.

A legibility/DRY reviewer is added only when the mechanical checks below
aren't in place, or the slice is refactor-heavy. Every reviewer is
read-only; the seat is the sole ledger writer. POL-002 duplication is
disposed fix-now unless the user waives it explicitly.

## Rationale

Calibrated on RV-002 (SL-001: ~1,135 lines of source, ~2,560 of tests).
Tokens are each agent's own end-of-run context, as reported.

| Agent | Tokens | Wall-clock | Yield |
|---|---|---|---|
| Modelling reviewer | 111k | 6 min | Only user-visible defects (F-1, F-3); SL-004/SL-002 hazards (F-2, F-6); layering (F-11) |
| Test reviewer | 217k | 12 min | Highest yield per finding: four green-shipping bugs (F-18), vacuous oracles (F-19), order dependence (F-17), plus the forward test strategy |
| Legibility/DRY reviewer | 80k | 3 min | Real but mostly mechanical: three POL-002 duplications (F-7..F-9), idiom and naming nits |
| Opus verifier | 141k | 8 min | Confirmed 24 of 25; value was calibration (POL-002 drift, F-19 worse than reported), not filtering |

There were no blockers or majors. The value was mostly in future hazards
and test infrastructure. Review plus fixes cost several times the
orchestrator-level cost of building the slice. That buys much less on a
slice with smaller stakes, hence a two-reviewer default.

## Scope

Pre-close review of every slice that changes Elisp. A per-phase review
(code-review cadence) may use a single reviewer. Scale up for
high-stakes slices (write path, redistribution): add the legibility
reviewer and an opus verifier.

## Verification

- The audit's RV `## Brief` names the roster used and why it departs from
  this default.
- Mechanical substitutes for the legibility reviewer:
  - a lint failing on an `org-iw-<layer>--` symbol referenced outside its
    file (RV-002 governance proposal 4);
  - POL-002 grep checks;
  - `just mutate` (CHR-001).

## References

- RV-002 (synthesis; `.doctrine/slice/001/research/raw/rv-002/governance-proposals.md`).
- STD-001, STD-002, POL-002.
