---
name: reviewing-memory
description: Structured audit for stability gates — before releases, migrations, large refactors, or when agent confusion is detected. Use to prune, correct, and re-anchor the memory corpus before it drifts past useful.
---

# Reviewing Memory

> **MCP shortcut:** If the doctrine MCP server is connected, use `memory_show`
> via MCP tool instead of `doctrine memory show` for machine-parseable JSON results with
> backlinks.

A stability-gate audit: systematically pull the highest-impact memories,
inspect their quality, and produce an auditable outcome for each. Run before a
release, a schema migration, an ADR that shifts subsystem boundaries, or when
`retrieve` returns contradictory or low-confidence results.

## Procedure

1. **Pull highest-impact memories.** Run `doctrine memory validate` corpus-wide
   (no REF) to surface dangling relations, stale verifications, and expiring
   drafts across the entire corpus. The output is your audit queue.

2. **Prioritize.** Order findings by impact:
   - Memories with **scoped paths** that have seen high commit churn since
     attestation (drift risk)
   - **Attested** (verified) memories — stale attestation on a moving target is
     worse than unattested
   - High **severity** × high **weight** — wrong here hurts

3. **Run the checklist on each.** For every memory in the audit queue, check:
   - **Provenance.** Is the source still traceable? Has the cited code/doc
     moved?
   - **Freshness.** Is the attestation recent? Has the scoped path churned
     past usefulness?
   - **Metadata efficiency.** Is the scope still accurate? Are tags stale?
     Is the lifespan appropriate?
   - **Scope accuracy.** Do the path/glob/command scopes still cover the
     right surface?
   - **Actionability.** Can a future agent act on this without further
     research?
   - **Duplication.** Does this memory overlap with another? Merge or
     supersede.

4. **Thread hygiene.** Scan for lingering unverified threads (`memory list
   --type thread`). For each:
   - If still relevant, verify it (`doctrine memory verify <REF>`)
   - If stale, archive it (`doctrine memory status <REF> archived`)
   - If superseded by newer knowledge, supersede it (`doctrine memory status
     <REF> superseded --by <SUCCESSOR>`)

5. **Produce outcomes.** Every reviewed item must land in exactly one
   terminal state:
   - `verified` — re-attested on current tree, metadata updated
   - `corrected` — edited (`doctrine memory edit`) with updated scope,
     trust, or content
   - `superseded` — pointed at its successor via `memory status superseded
     --by`
   - `archived` — no longer actionable but kept for history
   - `promoted` — converted to a durable artifact (ADR, spec, or doc) and
     archived from memory

   No memory leaves review without one of these outcomes recorded.
