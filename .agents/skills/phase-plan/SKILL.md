---
name: phase-plan
description: Use just before executing a specific phase — expand its authored plan entry (objective + EN/EX/VT) into the disposable runtime phase sheet with a concrete task breakdown, assumptions, and verification steps. Routed to from /plan or /execute.
---

# Phase Plan

You are expanding one authored phase into its runtime phase sheet, immediately before
executing it. The authored plan (`plan.toml`) says *what* the phase must achieve;
this skill works out *how*, in the disposable state tree.

Plan each phase in detail **just prior to execution** — not all phases up front.

Inputs:

- the phase's `plan.toml` entry — its `objective`, `exit_criteria` (`EX-`), and
  `verification` (`VT-`/`VA-`/`VH-`)
- `design.md` (canonical design reference) and `slice-nnn.md` (scope)
- the materialised runtime phase sheet `state/.../phases/phase-NN.{toml,md}`

## Process

1. Confirm the phase's `entrance_criteria` (`EN-`) are met before planning the
   detail. If they are not, resolve that first (an earlier phase, a design gap).
2. Re-read `design.md` and the phase's `plan.toml` entry — objective, exit
   criteria, verification expectations.
3. Run `/retrieve-memory` against the concrete files and subsystems you expect to
   touch, so scope-bound gotchas and patterns surface before you commit to a
   task breakdown.
4. Check the research advisory — `doctrine slice research <id>`. Where it reports
   drift, refresh only the affected thread sections, then re-stamp the baseline;
   plan the phase against the refreshed artefact, not the stale one.
5. Fill the runtime phase sheet `phase-NN.md` (under `.doctrine/state/`, GITIGNORED and
   disposable) with:
   - a concrete task breakdown — small, coherent units of work
   - assumptions and constraints carried into execution
   - the verification steps that will satisfy each `VT-`/`VA-`/`VH-` expectation
   - the files / components each task is expected to touch
6. This is runtime state (`lib:reference/using-doctrine.md` § Storage tiers) —
   never write task detail or progress back into the authored `plan.toml` /
   `plan.md`.
7. If detailing the phase surfaces new design problems, unresolved tradeoffs, or
   policy ambiguity, stop — `/consult`, or return to `/design` if the design
   itself is the gap. Do not invent your way past it.
8. When the sheet tells a coherent story, flip the phase to `in_progress` with
   `doctrine slice phase` (see `lib:reference/using-doctrine.md`), then
   `/execute`.

## Outcomes

- The phase has a concrete, executable task breakdown grounded in the design.
- Verification steps map to the phase's `VT-` criteria.
- Authored plan and runtime state stay on their correct sides of the storage rule.
