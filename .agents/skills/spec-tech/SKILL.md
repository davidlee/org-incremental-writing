---
name: spec-tech
description: Use when authoring or revising the technical specification — the how of a capability, downstream of the product spec and upstream of per-slice design. Use to record durable architecture and mechanism, not a single change's design.
---

# Spec Tech

You are authoring the technical spec — the *how*, downstream of the product spec
(`/spec-product`) and upstream of per-slice design (`/design`). The entity
engine (TOML+MD tiers, relations, `show` command) is documented in
[[mem.concept.doctrine.entity-engine]].

> **Structural.** Doctrine manages specs as first-class entities — a tech spec is
> the same **three coordinated writes** as a product spec: scaffold with `spec new`
> (subtype/title/slug only), hand-edit the spine and flat fields into
> `spec-NNN.toml`, then `spec req add` its requirements. Use `show` to read the
> reassembled whole, `validate` for FK integrity, `list` for the corpus (flags in
> `--help`; verb model in `lib:reference/using-doctrine.md`). Identity, the relational spine, and
> flat fields (incl. `c4_level`, `[[source]]` anchors) live in `spec-NNN.toml`, the
> narrative in `spec-NNN.md`; requirements are **peer entities** (`REQ-NNN`) membered
> via `members.toml`; tech-only spec→spec edges are written with `doctrine spec
> interactions add`/`remove` (not hand-authored). **There is no CLI flag for the
> spine — it is authored TOML, and
> `spec validate` is the integrity gate.**

Capture the durable architecture and mechanism:

- the shape of the solution — components, boundaries, data flow, invariants
- the key technical decisions and their rationale (link relevant ADRs)
- interfaces and contracts that outlive any single change
- constraints the implementation must honour

**The relational spine** places every spec in the corpus tree (all hand-edited
TOML, gated by `spec validate`):

- `descends_from` — tech→PRD, single-valued, a validated FK to the product intent
  this capability realises.
- `parent` — a single parent, acyclic containment (the C4 decomposition).
- **Containment is never a peer edge.** `parent` is never expressed as an
  `interactions` edge, and an `interactions` edge is never containment as a
  matter of principle — decomposition and peer `uses`/`calls` are distinct axes.

**C4 altitude.** Hand-authored specs normally stop at the container/component
level; code-level (C4 level 4) specs are exceptional, authored only when a unit of
mechanism genuinely needs that resolution.

**Posture is dual.** A tech spec may be **retrospective** (the shipped *how*) or
**forward-intent** (describing an unbuilt engine) — both
are legal, provided *planned* stays distinguishable from *verified*. Requirements
are `REQ-NNN` entities at status `pending`; there are no coverage tables and no
status derivation — observed coverage is reconciled, never inferred from the spec.

**Three canonical shapes.** The `context`/`container`/`component` kinds each have
one locked shape — read a spec of that kind with `spec show` before authoring:

- **`context`** — the whole-system synthesis: anchor-free, no `parent`,
  no `descends_from`; names the containers and their composition, never restating
  any one container's mechanism.
- **`container`** — `parent` only, no descent: a mechanism container
  whose children carry the per-capability descent.
- **`component`** — `parent` + `descends_from`: the thin (not anaemic)
  capability shape — kind-specific contracts only, shared mechanism cited via the
  parent, never restated.

Keep it evergreen. A single change's concrete design — current vs target
behaviour, code-impact, verification — belongs in that slice's `/design`, not
here. If a decision is project-global and load-bearing, it may be an ADR
(`doctrine adr new`) rather than spec prose.
