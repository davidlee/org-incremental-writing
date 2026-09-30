---
name: execute
description: Use to implement one planned, approved phase of a slice — once its design and plan exist and its runtime phase sheet is ready. Move the phase to in_progress, build it TDD red/green/refactor, keep notes current, end green, and surface blockers early.
---

# Execute

You are executing one phase of planned work.

Inputs:

- the active runtime phase sheet (`state/.../phases/phase-NN.md`)
- `plan.toml` / `plan.md`
- `design.md` (canonical design reference)
- `slice-nnn.md` (scope)

## Process

1. Confirm the phase's entrance criteria (`EN-`) are met for the active phase.
2. Read `design.md` + `plan.toml` + the runtime phase sheet before coding. If the sheet
   is not yet filled, run `/phase-plan` first; use `/preflight` if confirmed
   inputs, assumptions, and tensions are not yet surfaced.
3. Identify the concrete files or components you expect to touch first and run
   `/retrieve-memory` against those paths before deep reading or editing, so any
   scope-bound gotchas or patterns surface early.
4. Ensure status matches reality before implementation proceeds:
   - first phase starting → move the slice: `doctrine slice status <id> started`
     (bare number), if not already there.
   - flip the phase to `in_progress` with `doctrine slice phase` (see
     `lib:reference/using-doctrine.md`). **This auto-records the conformance
     boundary** — the
     handler stamps `code_start_oid = HEAD` into the phase sheet. No extra call;
     the binding rides the transition you already issue. (It self-skips
     in a dispatch coordination context, where the funnel beat is the recorder
     instead.)
5. Implement phase tasks in small coherent units, **TDD red/green/refactor**
   write a failing test, make it pass, then refactor. Test behaviour, not
   trivial implementation. Build and improve test helpers and fixtures as you go.
6. After each meaningful unit, run `/harvest`.
7. If that unit produced a durable gotcha, pattern, or subsystem fact worth
   future retrieval, run `/record-memory` before moving on.
8. Lint as you go (`cargo clippy`, zero warnings) and keep the tree buildable.
9. Follow the repo's commit policy: frequent, small conventional commits scoped
   with the slice id (e.g. `feat(SL-NNN): …`). Bias toward a clean tree; don't
   let `.doctrine/**` workflow edits drift in a stale uncommitted pile.
10. If `/preflight` or implementation reveals unresolved design ambiguity,
    unexpected obstacles, tradeoffs, or policy ambiguity, stop and `/consult`
    before improvising past it.
11. Keep the runtime phase sheet current as work progresses — never record progress in
    authored `plan.toml` / `plan.md` (the storage rule).
12. Before declaring the phase ready, run the verification gate — `doctrine
    check gate` (lint + test + format) — and review the touched subsystems and
    notes once
    more for missed memory-capture candidates. At phase wrap, weigh a
    **per-phase review** per the code-review skill's `## Cadence` — default on
    below the adherence bar, mandatory on any tripwire.
13. When exit criteria (`EX-`) and verification (`VT-`, plus any agent/human
    `VA-`/`VH-` modes) are satisfied, flip the
    phase to `completed` with `doctrine slice phase`. **This closes the conformance
    boundary** — the handler captures `code_end_oid = HEAD`, applies the
    ancestor/non-merge guard, and upserts the phase's row into the slice's
    arm-neutral registry. Deterministic, on the critical path — **not** a
    "remember to also record" step; `slice record-delta` is only the manual
    fallback (correct a range, or bootstrap a pre-binding phase). Then hand off:
    `/phase-plan` for the next phase, or — when the slice's phases are all done —
    `doctrine slice status <id> audit` and `/audit`.

## Optional: solo isolation (opt-in)

Default execution runs **in-tree** — the path above is unchanged unless isolation
is requested.

**Opt-in only — never automatic.** Run the phase on its own worktree fork *only*
when the user or the plan explicitly asks for isolation. Absent that annotation,
implement in-tree.

When isolation is requested, before implementing (i.e. before step 5) invoke
`/worktree` with:

- `mode = solo`, `allow_work_in_place = true` (solo MAY degrade to in-tree on
  sandbox denial);
- `branch = slice/SL-NNN-slug` (the slice id is in scope — e.g.
  `slice/SL-NNN-<slug>`), worktree dir keyed by the durable id
  (`.worktrees/SL-NNN`).

`/worktree` handles detection, the creation ladder (`doctrine worktree fork`),
provisioning, the spawn guards, and the green baseline; the **fork branch it
returns is the deliverable**.

**Assert a clean direct-writer entry.** Solo `/execute` is its own orchestrator —
worker mode is **never** used here (that is `/dispatch`'s path). Worker-ness is a
property of the *process*: if `DOCTRINE_WORKER` is set in this shell, every
doctrine-mediated authored write refuses mid-work. Confirm it is unset before the
TDD loop (`doctrine worktree status` prints the resolved mode); if it is set,
unset it — there is no stale on-disk state to clear.

Carry out the TDD loop (steps 5–12) inside the fork. When green, **land the fork
onto the coordination branch** — `/execute` is the sole caller of `land`:

```bash
doctrine worktree land --fork slice/SL-NNN-slug   # merge --no-ff, ancestry preserved (NEVER squash)
doctrine worktree gc   --fork slice/SL-NNN-slug   # reap the spent fork once the oracle proves it landed
```

See `lib:reference/dispatch-mechanics.md` §§ "The import severs ancestry — so
"did it land?" needs a patch-id oracle" and "The squash blind spot", for why
`land`/`gc` behave as they do.

## Outcomes

- Phase objectives are implemented with traceable evidence, ending green.
- Phase status matches reality during implementation, not only at closure.
- Notes and durable memory stay current throughout execution.
