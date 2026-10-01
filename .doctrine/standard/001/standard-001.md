# STD-001: Test quality

## Statement

Applies on top of POL-001.

1. **Independent tests.** Every test passes alone and in any order. No test
   relies on buffers, files, options or global state another test left
   behind.
2. **Tested oracles.** Any helper that decides pass/fail for many tests
   (state capture, "changes nothing", diff-style assertions, fixture
   cleanup checks) has a self-test showing it detects the change it claims
   to detect.
3. **Guards are killed.** Each guard, refusal branch or invariant check a
   phase adds is pinned by at least one test that fails when the guard is
   removed or inverted. Show this at phase end by mutation, or record why
   a surviving mutant is equivalent.
4. **Constants a design fixes are pinned literally.** A limit or format the
   design decides (e.g. 2^53−1, spacing 1024) is asserted as a literal at
   least once, not only derived from the constant under test.
5. **Context fixtures.** Code that reads a buffer is tested in the contexts
   where it can differ: neighbouring headings before and after, nesting,
   folding, narrowing on either side of the target, indirect buffers, dirty
   buffers, non-Org buffers.
6. **Behaviour first.** Prefer public entry points. A test that reaches a
   private (`--`) function or supplies values the code should compute
   needs a reason. A stub or advice standing in for real code asserts that
   it was called, or that it was not.
7. **One helper per concept.** POL-002 applies to test helpers. Shared
   setup lives in the helper library, not repeated per file.

## Rationale

RV-002 (SL-001's pre-close review) found a strong suite (135 tests, 99–100%
line coverage, every write-path mutant killed) that still let these through:
- F-17: one test failed when run alone.
- F-19: replacing either state-capture oracle with a constant left every
  "changes nothing" assertion green.
- F-18: four plausible bugs passed the whole suite. Each lived in a buffer
  context the fixtures never built.
- F-21: a limit was checked only against itself.
- F-22: a test asserted numbers it had supplied.

Line coverage reported 100% on lines whose behaviour no test pinned.
Mutation was the instrument that found the gaps. Re-anchored after the
fixes, 71 of 79 mutants were killed, against 63 of 80 before.

## Scope

All ERT tests and test helpers in this repository, from SL-002 on. It does
not apply retroactively to SL-001, whose gaps RV-002 fixed or recorded.

## Verification

- `just test-each` (each test in its own Emacs) passes at phase end
  (items 1 and 6).
- A curated mutation recipe (`just mutate`, CHR-001) runs at phase end;
  survivors are killed or justified in the phase sheet (items 3 and 4).
  Until CHR-001 lands, use the RV-002 harness in
  `.doctrine/slice/001/research/raw/rv-002/mutation/`.
- Review checklist for items 2, 5, 6 and 7: the pre-close review's test
  lens (STD-003).

## References

- POL-001 (lint and test gate), POL-002 (one implementation per concept).
- RV-002 findings F-17..F-19, F-21, F-22, F-24, F-25.
- `.doctrine/slice/001/research/raw/rv-002/test-strategy.md`: prioritised
  plan for fixture DSLs, assertion helpers, ert-x command simulation,
  property-based tests for placement, and which libraries are and aren't
  worth adopting.
- mem.fact.emacs.batch-test-gotchas.
