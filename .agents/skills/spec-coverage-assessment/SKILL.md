---
name: spec-coverage-assessment
description: Use when a named subsystem, capability, or code surface needs governance coverage assessed before authoring a spec — deciding what is already governed by an existing PRD / tech spec / ADR, what is dark, and where new spec boundaries should fall by product altitude and C4 level. Use before creating or scoping a product or technical spec for an unfamiliar or partially-governed surface. Use when a request asks to "assess coverage", "find governance gaps", "what's already specified", "where should this spec's boundary sit", "one spec or several", "what needs a PRD vs a tech spec", or "is this subsystem properly documented". Produces a reviewable coverage-map artifact that feeds `/spec-product` and `/spec-tech`. Do not use when the target spec and its boundary are already known and unambiguous — go straight to `/spec-product` or `/spec-tech`. Do not confuse with `doctrine coverage` — unrelated CLI verb for requirement verification.
---

# Spec Coverage Assessment

Bounded census of a named surface's governance extent, upstream of authoring.
Answers three questions an agent otherwise answers by unguided judgement: what
is already covered, what is dark, and where should new spec boundaries fall.
Output is a reviewable coverage-map artifact — it is not itself a spec, an
ADR, or a doctrine-tracked entity.

## Name collision — read before writing anything down

`doctrine coverage` (`coverage record | verify | forget`) is
**requirement-verification evidence** — whether a `REQ-NNN` has been observed
to hold. It has nothing to do with this skill. Never call this skill's output
bare "coverage" in prose, a commit, or a doctrine entity — always qualify it:
"spec coverage", "governance coverage", or "the coverage map". Never invoke
`doctrine coverage` verbs expecting this skill's semantics, and never let a
reviewer conflate the two — they are different axes (requirement-proof vs.
surface-vs-spec extent) that happen to share a word.

## Boundary

Use this skill when the surface is a subsystem, crate, capability, or code
area whose existing governance is unclear — you don't yet know which specs
touch it, whether they're current, or how a new spec should be carved.

Do not use it when:

- the target spec and its boundary are already known and unambiguous — go
  straight to `/spec-product` or `/spec-tech`.
- the task is authoring or revising one already-scoped spec — that's
  `/spec-product` / `/spec-tech` directly; this skill's output is an input to
  those, not a replacement.
- the task is proving a requirement is met — that's `doctrine coverage`
  (verification evidence), a different kind entirely.
- the task is a full corpus audit or exhaustive line-by-line review — this is
  a bounded census (see Stopping conditions), not `/inquisition` or `/audit`.

## Stopping conditions

Decide these **before** starting, out loud, per `/preflight` discipline:

- Census depth: which specs/ADRs/policies you'll check for surface-touching
  claims (by tag, title, or keyword match) — not the whole corpus unless the
  surface is genuinely corpus-wide.
- Inventory depth: module/crate-level line counts and file lists, not a
  read of every file. Sample suspicious modules; don't read them end to end.
- Stop once the top-ranked gaps and a boundary recommendation are legible and
  reviewable. Do not chase every anchor, every unattributed module, or every
  tangential ADR to exhaustion — that's an audit, not this.
- If the surface turns out to be small and already well-anchored, say so
  early and stop; don't manufacture gaps to fill the method's shape.

## Method

### 1. Governance census

Enumerate what already claims to touch the surface:

- `doctrine spec list` (filter by tag/title/keyword substring matching the
  surface) plus `doctrine search "<surface keyword>"` (BM25) to catch specs
  that mention it without an obvious tag.
- **Anchor harvest**: grep the raw TOML for `[[source]]` blocks across
  candidate spec files (`rg -A2 '\[\[source\]\]' <spec-dir>/**/spec-*.toml`) —
  faster and more complete than paging through rendered `spec show` output one
  spec at a time. Spot-check the rendered view with `doctrine spec show <ID>`
  once candidates are short-listed.
- **Tag/title mapping**: cross-reference each candidate spec's `tags` and
  `responsibilities[]` (TOML) against the surface's real module names — a
  spec's prose can *claim* a surface ("this owns the X crate") with zero
  anchor backing it; that claim still counts as a coverage signal, but a
  weaker one than a live anchor.
- **ADR/policy/standard sweep**: `doctrine adr list`, `doctrine policy list`,
  `doctrine standard list` (substring/tag filtered) for governance that
  touches the surface without being a spec — a policy or ADR can be the only
  governance a component has.
- Optionally `doctrine relation census` / `doctrine concept-map` to see how
  the candidate specs already relate to each other —
  useful for the descent/parent decision in step 5.

### 2. Surface inventory

Enumerate the surface's real extent, independent of what governance claims:

- List modules/crates/scripts/web directories under the named surface
  (`rg --files <path>`, standard directory listing).
- Size each with a line count (`tokei`, `wc -l`, or equivalent) — this feeds
  the size factor in step 4. Precision doesn't matter; order of magnitude
  does.
- Note structural seams that matter for boundary-setting later: is there a
  separable frontend/backend split, a crate boundary, a clearly distinct
  script family?

### 3. Coverage mapping — with the anchor-liveness caveat

Join the census (1) against the inventory (2) per module/crate/area:

- **Covered** — has a live anchor into a current spec.
- **Partial** — referenced by tag/title/prose but not anchored, *or* anchored
  but the anchor is stale (see caveat).
- **Dark** — zero governance touch of any kind.

**Anchors are not a trustworthy substrate on their own — verify liveness
before counting an anchor as coverage.** They are descriptive, not enforced:
nothing currently checks that an anchored path still exists. Empirically,
live specs have been found anchoring a file path long after the code moved
elsewhere — the spec looked "covered" and was actually rotted. For every
anchor you rely on to call something "covered", confirm the path still
exists (`test -e`, or equivalent) before trusting it. Also watch for: anchor
density inversely correlating with subsystem size (big subsystems are often
*less* anchored, not more — don't assume large means covered), and slug
symlinks beside numeric spec dirs double-counting a naive recursive grep.

### 4. Rank gaps

Score dark and partial areas by **size × centrality**, not by discovery
order:

- Size: the step-2 line/file count.
- Centrality: how load-bearing the area is — how many other components
  depend on it, how core it is to the product line, whether it's on a path
  other specs already describe as a dependency.

Surface the top few gaps, not an exhaustive ranked list of everything dark —
this is where the stopping condition bites.

### 5. Propose spec boundaries

For each top-ranked gap, work out — don't just flag the gap, propose a shape:

- **Product altitude** (domain | capability | feature — `feature` is the floor
  and may parent another feature) — does this need new product intent (a PRD)
  at all, or does an existing PRD already cover the *why* and only the tech
  spec is missing? The product ladder is shorter than C4's by design; don't
  reach for a fourth rung to make the two line up.
- **C4 level** (context | container | component | code) for any new tech
  spec — component/container is the normal stopping altitude; code-level is
  exceptional (`/spec-tech`'s own guidance) and should be justified, not
  defaulted to.
- **PRD-vs-SPEC split** — is the fix "add anchors to an existing spec that
  already claims this" (no new entity), a new tech spec under an existing
  PRD, or both a new PRD and a new tech spec (no product intent exists at
  all)?
- **One spec or several** — does the gap hang together as one cohesive
  component, or does it split along a structural seam noticed in step 2 (e.g.
  a backend engine and its separately-shipped web frontend are usually two
  containers, not one)?
- **Descent and parent placement** — where does the proposed spec sit in the
  `parent`/`descends_from` spine? Sibling to an existing component, child of
  an existing container, new container under the system context spec?
- **Drafting sources** — which existing RFCs, design docs, or slice history
  should the eventual `/spec-product` / `/spec-tech` pass draft from, so
  authoring isn't starting from a blank page.

### 6. Emit the coverage-map artifact

Write up the findings as a single reviewable markdown artifact (see shape
below) and stop. This skill does not author the spec itself — it hands off.

## Coverage-map artifact shape

```md
# Coverage census — <surface name>

## Governance census
Specs / ADRs / policies / standards found touching the surface, with anchor
status per claim (live / stale / prose-only-no-anchor).

## Surface inventory
Modules/crates/areas with approximate size (loc/file count).

## Coverage map
Covered / partial / dark per area, with the anchor-liveness check applied —
not assumed.

## Ranked gaps
Top gaps by size × centrality, each with a one-line rationale for its rank.

## Boundary proposal
Per ranked gap: product altitude, C4 level, PRD-vs-SPEC split, one-or-several,
descent/parent placement, drafting sources.

## Out of scope / not assessed
What the bounded census deliberately did not chase down, so a reviewer knows
the edges of what was checked.
```

Store it wherever the project's runtime-state convention puts working
artifacts (e.g. `.doctrine/state/`) — it is provisional input to authoring,
not an authored entity in its own right, unless/until a durable kind is
built for it.

## Guardrails

- Do not trust an anchor without checking the path exists — see step 3.
- Do not treat this as a full audit; a bounded, stated-up-front census beats
  an exhaustive one that never finishes. Say what you didn't check.
- Do not invent a spec boundary the census doesn't support — an ambiguous
  boundary is an Open Question for `/spec-product`/`/spec-tech`, not a
  guess made here.
- Do not call the output "coverage" unqualified — see the name-collision
  warning.
- Do not let this skill's output silently become the spec — it is reviewed
  input, handed off explicitly.

## Handoff

The coverage-map artifact is input to:

- `/spec-product` — for any proposed PRD-level gap (missing product intent).
- `/spec-tech` — for any proposed tech-spec-level gap or anchor-repair.
- the backlog, if a proposed boundary is worth capturing before someone acts
  on it (`backlog new`).

This skill's job ends at a reviewed coverage map; it does not draft spec
prose or requirement entities itself.
