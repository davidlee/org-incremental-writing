---
name: dreaming
description: >-
  Unified memory corpus maintenance — covers both reactive (change-triggered)
  and proactive (periodic/idle-time improvement) paths. One skill, two entries.
---

# Dreaming

Memory decays. Files move, commands change, invariants shift, duplicates
accumulate. This skill is the maintenance loop that keeps the corpus
trustworthy — one procedure, entered from either direction.

**Reactive entry.** Something changed: a file was renamed, a command flag was
removed, an ADR shifted a subsystem boundary, a code review found stale
memories referencing old paths. Run the procedure scoped to the affected area.

**Proactive entry.** Idle time, end-of-slice wrap-up, or a scheduled
maintenance window. Run the procedure corpus-wide.

## Procedure

1. **Validate.** Run `doctrine memory validate` corpus-wide (reactive: scope
   with `--path-scope`/`--glob` to the changed area). Triage each finding:
   - Fix immediately if trivial (update a path, refresh a scope)
   - Capture as a backlog item if non-trivial (risk, chore, or improvement)
   - Note and defer if low-impact and not time-sensitive

2. **Prune.** Identify stale memories:
   - Past `review_by` date → flag for review or archive
   - Unverified threads past expiry → archive (`memory status <REF>
     archived`)
   - `working`-lifespan memories older than a few days → retract or promote
     to a durable type
   - Run `doctrine memory status <REF> archived` for stale items; use
     `retracted` for memories that were simply wrong.

3. **Link.** Strengthen the graph:
   - Review suggested relations on recently-recorded or recently-edited
     memories (check `memory show <REF>` for relation rows)
   - Check for orphans — memories with no inbound and no outbound relations
     `memory list --orphans`
   - If there are orphans, focus on these - linking 20-30 records this run
   - If there aren't, explore the corpus and strengthen / prune connections 
     between existing memories
     * use `memory search <keyword>` to find candidate memories for linking;
       it returns one page, so sweep with `--limit` / `--page`
   - Run `doctrine link` for high-confidence matches

4. **Backlog grooming.** Findings that can't be fixed in this pass become
   backlog items:
   - **Risks** for not-yet-surfaced issues (e.g., a memory pointing at a
     deprecated API)
   - **Chores** for cleanup work (e.g., merging duplicate memories)
   - **Improvements** for enhancements (e.g., promoting a pattern memory to
     a spec)

5. **Fact-check.** Spot-check the top-N memories by severity × staleness
   (days since `updated`). For each:
   - Check the cited source (code path, doc, ADR) against the current tree
   - If correct, no action
   - If drifted, correct with `doctrine memory edit <REF>`
   - If obsolete, supersede (`memory status <REF> superseded --by
     <SUCCESSOR>`) or quarantine (`memory status <REF> quarantined`)
   - If unverifiable, lower trust (`memory edit <REF> --trust low`)

6. **Report.** Produce a brief handoff summary:
   - Actions taken (validated N, pruned M, linked L, fact-checked F)
   - Findings deferred to backlog (with ids if filed)
   - Items flagged for human attention (high-severity, ambiguous, needs
     decision)
   - Write this to `notes.md` or the active handover so the next agent
     doesn't re-do the same checks.
