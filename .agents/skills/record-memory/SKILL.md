---
name: record-memory
description: Use when you discover or confirm a durable fact, constraint, invariant, convention, sharp edge, footgun, or reusable workflow that a future agent would otherwise rediscover — capture it before it is lost to conversation context. Triggers at phase/slice wrap-up too.
---

# Record Memory

Conversation context does not persist. When knowledge would save a future agent
meaningful time, write a memory record immediately. Phase and slice wrap-up are
mandatory prompts: scan `notes.md`, the active runtime phase sheet, audit findings, and
fresh gotchas for durable guidance worth keeping.

Promote only durable guidance — repeatable workflows, sharp edges, invariants,
subsystem facts. Not conversational state.

## 1. Choose the narrowest type that fits

See `doctrine memory record --help` for the `--type` values:
concept|fact|pattern|signpost|system|thread.

⚠ **A `thread` is hidden from `find`/`retrieve` until verified**.
If you want a working loop to resurface by scope, prefer a durable type
(`pattern`/`system`/`concept`) — or record the `thread` and `verify` it on a
clean tree. An unverified thread shows only in `list`/`show`, never in scope
ranking.

## 2. Record it

Record with `doctrine memory record` (ask `--help` for the flags; see
`lib:reference/using-doctrine.md` for the verb model). It scaffolds a TOML +
body under
`.doctrine/memory/items/`; the **born git anchor is captured automatically** —
do not hand-author it.

### After recording

**Suggested relations.** `record` emits suggested relations on stderr when it
detects high-confidence matches against existing memories. Review these and
run `doctrine link` for matches you confirm — this builds the durable graph
edges a future agent traverses.

**Graph vs body links.** Use `[[relation]]` edges for durable graph structure
(typed, machine-traversable); use `[[mem.…]]` wikilinks in body prose for
contextual "see also" pointers. Relations surface in `retrieve --expand`;
wikilinks don't — they are for human readers.

**`--lifespan` selection.** Pick the narrowest lifespan that fits the
knowledge, from most to least durable:

| Lifespan | Rule of thumb |
|---|---|
| `identity` | Never ages — subsystem identity, invariant, canonical name |
| `semantic` | 10:1 decay — design rationale, architecture constraints |
| `procedural` | 3:1 decay — command recipes, build steps, workflows |
| `episodic` | Baseline — one-off findings, bug notes, session context |
| `working` | Fast decay — transient todo, short-lived hypothesis |

Defaults to `episodic` when omitted. Narrow scope + narrow lifespan together
keep retrieval relevant.

## 3. Scope it so it will be found

Scope a memory along four axes (the flags are in `--help`):

- **path** — exact file(s); strongest match.
- **glob** — subsystem relevance (e.g. `src/auth/**`).
- **command** — tied to a command flow (token-prefix).
- **tag** — stable categorization; do **not** overload tags as scope.

## 4. Set the risk axes

`record` defaults `[trust] trust_level = "medium"`, `[ranking] severity =
"none"`, `weight = 0`. For risky or drift-prone memories, pass the flags at
record time or update later:

```
doctrine memory record ... --trust high --severity critical
```

Or adjust after the fact:

```
doctrine memory edit <REF> --trust low --severity medium
```

- **`--trust`** = confidence: `low` (inferred, unvalidated) · `medium`
  (derived from reasonable context — default) · `high` (verified against code /
  specs / direct observation).
- **`--severity`** = how much it matters if wrong or ignored:
  `critical` · `high` · `medium` · `low` · `none` (default).

Calibrate honestly: creating a memory is authoring, not verification.

## 5. Attest if you verified it

```
doctrine memory verify <UID|KEY>
```

Stamps `verified_sha` against the working tree (refuses a dirty tree — no false
attestation). Unattested memories read as lower trust.

**Threads require this to surface at all.** `thread_expiry` drops any `thread`
that is not `verified` AND `reviewed` within 14 days from `find`/`retrieve`.
`record` always writes `unverified`, so a fresh thread is invisible
to scope ranking until you `verify` it — and `verify` refuses a dirty tree, so
attest from a clean tree. Other types are never gated this way.

See `doctrine memory retrieve --help`: retrieve applies the non-bypassable trust
holdback (low-trust + high-severity suppressed).

## 6. Keep the body short and executable

Put "do X" steps in bullets with exact command snippets. Reference related
artifacts and memories inline with `[[uid]]` / `[[key]]` (cheaper than relations).
If the item would become an ADR or an evergreen spec, STOP — `doctrine adr new`
or author a spec or ADR instead. Memory is a pointer/recipe layer, not canon.

## 7. Sanity-check surfaceability

Run `doctrine memory search` scoped to the context a future agent will actually
query (see `--help`), and confirm the memory appears. Search returns one page,
so a scoped browse can page it out: confirm with a query that uses the memory's
own terms (free text finds it by evidence), or page on with `--page`.

Exception: an unverified `thread` will **not** appear here even when recorded
correctly (§1/§5) — `verify` it first, or check `memory show` instead.
