---
name: retrieve-memory
description: Use before making non-trivial assumptions — before touching a subsystem you have not this session, before running or changing a command pipeline, when code and docs conflict, when asked "what is the right way here?", when debugging a recurring failure, or when about to answer with "probably/usually/likely".
---

# Retrieve Memory

Default rule: if you cannot cite a source-of-truth file/doc/ADR from the repo,
consult memories first, then proceed. The memory model is documented in
[[mem.concept.doctrine.memory-model]].

## Tool preference

If your harness supports MCP tools and doctrine's MCP server is connected
(you see `memory_search`, `memory_retrieve`, `memory_show`, `memory_list` in
your tool list), **prefer these MCP tools over the CLI**. They return
machine-parseable JSON text in the MCP content block without spawning a
shell, and `memory_show` enriches results with resolved backlinks.

### Progressive disclosure (MCP pattern)

1. **`memory_search`** — scope-constrained discovery first. Always supply at
   least one selector (path, glob, tag, type, or free-text query). Metadata
   only, no bodies. Rows include a `held_back_on_retrieve` flag — do not
   treat high-risk memories as consumable knowledge.
   - **Find vs browse.** Free text is floored: only memories with lexical or
     exact-key evidence for the query come back; selectors alone browse
     every scope match, severity first. Either way you get one page (20 by
     default); page on with `offset` = `next_offset` (CLI: `--page`).
   - **Empty is an answer.** An empty free-text result means "no match", not
     "empty corpus" — reword with the memory's likely terms, or drop the
     query and browse by scope.
2. **`memory_retrieve`** — safe context recall for candidates identified in
   step 1. Trust holdback enforced; low-trust high-severity memories are
   suppressed automatically.
3. **`memory_show`** — full inspection only when you need the complete
   picture. Use `view: summary` for token efficiency. Held-back memories
   carry a warning; do not consume them as knowledge.
4. **`memory_list`** — browse/index only. Prefer scoped `memory_search`.

When MCP tools are not available (e.g. in a plain shell environment),
fall back to the `doctrine memory` CLI commands described below.

## Two surfaces

- `doctrine memory retrieve` — see `doctrine memory retrieve --help` for the
  data-not-instruction framing and the non-bypassable trust holdback.
- `doctrine memory search` — ranked rows that keep risk visible
  (holdback-exempt). Use it to discover and triage, including the risky memories
  `retrieve` hides.
- `doctrine memory show <UID|KEY>` — read one memory's full body.

### Graph traversal

- `doctrine memory backlinks <REF>` — discover reverse edges: which memories
  point *to* this one. Use when you land on a memory and need to know what
  depends on it.
- `doctrine memory retrieve --expand N` — expand the result graph by N hops
  along `[[relation]]` edges. Each hop pulls in directly-connected memories.
  Use for context when a single memory is too narrow.
- `--lifespan` filter (on `retrieve` and `search`) — restrict to memories with a
  lifespan at or above the given threshold. `identity` returns everything;
  `semantic` filters out `episodic`/`working`; `procedural` excludes
  `working`. Use to suppress transient noise in a deep dive.

### When the question is not memory-shaped

`doctrine memory search` reaches only the memory corpus. For a "where does this
live / what is the right way here?" question whose answer may be an ADR, spec,
slice, RFC, or backlog item, use `doctrine search <query>` instead — one ranked
query over the entity corpus. It is entities-only, and its default kind set omits
policies and standards; `lib:reference/using-doctrine.md` gives the scope and
how to
widen it.

## Procedure (fast → thorough)

1. **Scoped query first.** Run `doctrine memory retrieve` scoped to the concrete
   files you expect to read or edit, plus the command context you are about to
   run (ask `--help` for flags; `lib:reference/using-doctrine.md` for the verb
   model).
   Glob-scoped memories still match path scopes — no separate flag needed. Scope
   probes are OR'd; type/status are AND hard filters, so do not over-filter
   unless certain.

2. **Tune the surface.** See `doctrine memory retrieve --help` for `--limit`
   and `--min-trust` (raises, never lowers, the default trust floor).

3. **Inspect risk.** If `search` shows risky or held-back memories relevant to the
   task, `show` them and judge — do not act blind to what `retrieve` withheld.

4. **Make connections.** After retrieving, check the relations on key memories
   and follow edges to related knowledge: `memory show <REF>` renders relation
   rows; `memory backlinks <REF>` surfaces reverse edges; `memory retrieve
   --expand 1` pulls the immediate graph neighbourhood. A memory in isolation
   is less useful than one with its edges visible.

5. **Validate before acting.** Before relying on an old or high-severity memory,
   run `doctrine memory validate <REF>` to check for dangling relations, stale
   verification, and draft expiry. A memory that looked definitive six months
   ago may have drifted. Validate, then act.

## What to trust

- Ranking already encodes severity, weight, scope specificity, and recency —
  prefer the top rows.
- A memory carries a verification state. Surface it qualitatively when you rely
  on one: never attested → say so; many commits since attestation → "treat with
  caution, its scope has churned"; recently attested → "scope is quiet".
- If memories disagree, do not average — escalate (`/consult`, or update/supersede
  the stale one) before a consequential change.

## Output discipline

When you act on a memory, cite its uid/key and the sources it points to. Run the
scoped query *before* deep reading or editing, so glob-scoped gotchas surface
while the change is still cheap.
