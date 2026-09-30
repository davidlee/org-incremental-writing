---
name: capsule-driver
description: Use to drive a slice's phases to completion through in-session capsule subagents in the MAIN worktree — you are the super-orchestrator seat, spawning capsule-orchestrators that each charter ~3 phases and spawn their own planners and workers. No worktrees, no dispatch, no confinement. Use when you want a whole slice implemented under a tight context budget without handing the tree to confined workers. Not for confined or parallel-worktree execution — that is /dispatch.
---
# Capsule driver (the super-orchestrator seat)

Drive a slice's phases to completion through a tier of subagents in the **main
worktree**. You hold the human's attention; everything below you is disposable
context.

**Announce at start:** "Using the capsule-driver skill to drive SL-NNN through
capsule orchestrators."

## Why this exists

A slice's implementation costs far more context than one agent should hold. The
tiering exists so that no single context exceeds ~250k tokens, where both cost
and output quality degrade:

    you (interactive, human attached)
      └── capsule-orchestrator     charters ~3 phases, verifies, commits
            ├── capsule-phase-planner   one phase → runtime sheet
            └── capsule-worker          one phase → source delta

Your own discipline is to spend as little context as possible. You are not a
reviewer of diffs; you are a spawner of orchestrators and a reader of their
hand-backs.

## Preconditions — check these before spawning anything

1. **Session permission posture.** Subagents inherit your mode, and a parent on
   `bypassPermissions` / `acceptEdits` cannot be overridden by a child. In
   `default` mode every background subagent's permission prompt surfaces in
   *your* session naming the asker — it will not deadlock, but it will pepper
   you and defeat the point. Confirm the operator is running a posture they are
   happy to have inherited by the whole tree.
2. **Spawn depth.** The tree needs 2 layers below you. The default is 3, but it
   was 1 in some releases, and at the limit `Agent` is silently withheld — an
   orchestrator that cannot spawn will quietly do the work itself. Pin it:
   `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH: "2"` in settings.
3. **No competing writers.** Everything runs in the main worktree with no
   confinement. Confirm no other agent is active in this tree before you start.
4. **The slice is planned.** Design locked, `plan.toml` authored, phases exist.
   This skill implements a plan; it does not make one.
5. **Background tasks off.** Export `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`
   into the session env before you start. The whole tree is strictly serial —
   `TaskOutput` is withheld from every subagent, so no agent here can even read
   a running child — and the harness backgrounds by default, so every spawn
   becomes a completion notification that re-invokes its parent at that parent's
   full context. Without the switch the tiers below fall back to *asking* for
   foreground, which is model-mediated, not guaranteed.

   **Set it out of band — per session, never in `settings.json`.** It is scoped
   to this seat's run, not to the repo: it also disables `run_in_background` on
   Bash, which other work in this tree legitimately uses. Do not make it a
   project setting to save a step.

## The loop

1. Charter an orchestrator: a named slice and a contiguous run of phases,
   typically 3. Spawn `capsule-orchestrator` with that charter, the slice id,
   and any standing constraint the human has set.
2. Read its hand-back. Check the per-worker model choices carry real arguments —
   "the default" is not one. Check what it adapted in the plan.
3. **Reap it.** `TaskStop` the orchestrator the moment you hold its hand-back.
   It is discharged; left standing it can be woken by a stray notification and
   pay a full turn at its accumulated context to report nothing. Confirm it is
   gone from `/tasks` before you charter the next one.
4. Charter the next orchestrator for the next run of phases. Always spawn a
   fresh one rather than resuming a tired one.
5. Record friction as it is reported to you (`doctrine observation record`).
6. **Halt when phase implementation is complete. Do not begin audit.**

## What you escalate to the human

Subagents cannot ask — `AskUserQuestion` is withheld from every subagent, so an
orchestrator's only channel is its return value. You are the entire escalation
path. Bring the human in for high-impact decisions and governance conflicts
where correct intent cannot be determined; decide the rest yourself.

## Boundaries

- **Not `/dispatch`.** No worktrees, no forks, no confinement, no import step.
  Workers edit the real tree and orchestrators commit directly. If you need
  isolation or parallel file-disjoint phases, you want `/dispatch` instead.
- **Do not implement.** If you are editing files, the tiering has failed and you
  are burning the context it exists to protect.
- **Do not audit.** `/audit` is a separate stage with its own skill; route there
  after this skill halts.

## Related

`/plan` and `/phase-plan` produce what this consumes. `/audit` is what comes
after. `/dispatch` is the confined-worktree alternative to this skill.
