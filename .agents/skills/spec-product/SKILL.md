---
name: spec-product
description: Use when authoring, revising, normalising, or reviewing a doctrine product specification/PRD - the durable product intent, requirements, success measures, behaviours, and verification basis for an evergreen capability. use before creating or scoping slices that descend from shared product intent. use when a request asks for product requirements, functional requirements, non-functional requirements, product scope, acceptance gates, out-of-scope boundaries, success measures, or agent-readable product context. do not use for one-off change planning, implementation design, technical architecture, or phase execution.
---

# Spec Product

Author the product spec: the durable **what**, **why**, and **proof obligations** for an evergreen capability.

A product spec is upstream of slices and design. It defines the product contract that later agents use to scope changes, derive implementation design, verify correctness, and avoid inventing missing intent.

## Boundary

Use a product spec when the subject is an enduring capability, product surface, user/system need, or behaviour family.

Do not use a product spec when the subject is a single bounded change. Use `/slice` for the change scope instead.

Do not include implementation design, architecture, code structure, algorithms, storage layout, or phase plans. Put technical solution material in `/spec-tech` or `/design`.

## Canonical structure

Use this shape unless the user explicitly supplies a different canonical template:

```md
# {{ref}}: {{title}}

## 1. Intent
Problem, value, and desired outcome.

## 2. Scope
In scope, out of scope, and boundaries.

## 3. Principles
Non-negotiable product/domain stances.

## 4. Requirements
Framing sentence plus constraints and invariants only. Functional/quality
requirements live as entities (synthesized below), never as prose rows.

## 5. Success Measures
Expected outcomes, metrics, signals, and acceptance gates.

## 6. Behaviour
Primary flows, alternate flows, edge cases, guards, and failure modes.

## 7. Verification
Verification approach in prose; no coverage table; cite durable REQ-NNN, not labels.

## 8. Open Questions
Unresolved decisions requiring exploration, judgement or further information.
```

## Authoring rules

### 1. Intent

Capture:

* the problem being solved
* the user, operator, agent, or system need
* why the capability matters
* the desired end state

Keep this product-level. Do not describe how the system will be built.

Good intent names the need and consequence. Weak intent only names a feature.

### 2. Scope

Separate what the spec governs from what it deliberately does not.

Include:

* in-scope behaviours or surfaces
* out-of-scope behaviours or surfaces
* boundary conditions
* assumptions that limit interpretation

Make boundaries explicit enough that a downstream agent can reject accidental expansion.

### 3. Principles

State non-negotiable product or domain stances.

Principles should constrain interpretation. Do not include generic virtues such as “make it simple” unless they have a concrete consequence.

Prefer:

* “Requirements are peer entities, not embedded prose.”
* “A missing canonical requirement is a stop condition, not permission to infer.”
* “Validation failures must be surfaced, not silently repaired.”

Avoid:

* “Be user-friendly.”
* “Keep it maintainable.”
* “Use best practices.”

### 4. Requirements

Requirements are the mechanically important core of the product spec — and they
live as **entities, never as prose rows**. This is the whole point of the model.

The §4 prose body carries exactly three things and nothing else:

1. a short framing sentence stating that the functional and quality requirements
   are recorded as requirement entities and appear under the synthesized
   Requirements section that `spec show` renders;
2. a `Constraints:` bullet list;
3. an `Invariants:` bullet list.

```md
The functional and quality requirements this capability must satisfy are recorded
as requirement entities and appear under the synthesized Requirements section
below. This section carries only the constraints and invariants that bound every
valid implementation.

Constraints:

- The capability must respect ...
- The implementation must not require ...

Invariants:

- ... must always remain true.
- ... must never occur.
```

**Do not write a "Functional Requirements" sub-heading, `- FR-001 — …` rows, or
any quality-requirement rows in §4 prose.** Functional and quality requirements
are peer entities created with `spec req add` (see Structural Doctrine); they
surface under the synthesized `## Requirements` block. Listing them as prose rows
is the heresy this skill exists to prevent — it duplicates queryable structured
data into prose and lets the two drift. (The label is `NF-`, not the legacy
"NFR" form.)

Functional requirements (the `FR-` label) define observable behaviours. Quality
requirements (the `NF-` label) define quality bars: reliability, performance,
safety, security, privacy, accessibility, compatibility, operability,
maintainability, or agent-readability. Both are entities — `--kind functional`
and `--kind quality` respectively.

Constraints and invariants have **no requirement kind** and stay as §4 prose
bullets. Constraints limit valid solutions; invariants are truths that must hold
across all valid implementations and future slices. There is no `CON-`/`INV-`
entity — do not try to `spec req add` them.

Do not bury a functional or quality obligation in a narrative paragraph either: if
something must be implemented, tested, or enforced as behaviour or a quality bar,
promote it to a requirement entity, not a prose sentence. Mirror the canonical
shape of **your own repo's** product spec (`spec show <PRD-ID>`).

### 5. Success Measures

Define how success will be recognised at product level.

Include whichever apply:

* expected outcomes
* acceptance gates
* behavioural signals
* operational signals
* qualitative validation
* quantitative metrics

Success measures may be aspirational, but acceptance gates must be concrete enough for review.

Avoid making tests the only success measure. Tests prove conformance; they do not always prove product value.

### 6. Behaviour

Describe product behaviour without committing to implementation design.

Include:

* primary flows
* alternate flows
* edge cases
* failure modes
* guards
* permission or policy boundaries
* user-visible or agent-visible outcomes

For each flow, identify the triggering condition, expected behaviour, and resulting state.

If behaviour depends on unresolved policy or product judgement, record the gap in Open Questions instead of inventing an answer.

### 7. Verification

Describe the verification approach in prose: how the capability is proven to carry
its contract, hold its invariants, and satisfy its quality bars, without binding
the spec to a particular implementation.

**Do not write a per-requirement coverage table.** A table keyed on the mobile
`FR-`/`NF-` membership labels duplicates queryable data into prose and rots the
moment a requirement is re-labelled or reordered. Where a check must cite a
specific obligation, reference the **durable requirement entity (`REQ-NNN`)**,
never the membership label. Coverage of the functional and quality requirements is
tracked against those entities, not restated here.

Verification prose should still address:

* how the behaviours and invariants are proven
* acceptance gates and the signals that satisfy them
* observability and validation/review obligations

If an obligation cannot be verified, rewrite the requirement entity or record an
open question. Mirror the canonical prose shape of your own repo's product spec.

### 8. Open Questions

Record unresolved decisions that require exploration, judgement, or further information.

Use open questions for genuine unknowns, not as a dumping ground for deferred work.

Each question should explain why it matters or what it blocks.

Prefer:

* “OQ-1 — Should archived specs remain visible in default listings? Blocks list semantics and acceptance tests.”

Avoid:

* “Need to think about UX.”

## Structural Doctrine

Doctrine manages specs as first-class entities. A product spec is **three
coordinated writes** — see your own repo's product spec (`spec show <PRD-ID>`) for
the canonical shape:

1. **Identity TOML** (`spec-NNN.toml`): `schema`, `version`, `id`, `slug`,
   `title`, `status = "draft"`, `kind = "product"`, an open-vocabulary `category`,
   a `tags` array, and a `responsibilities[]` array of capability-level
   statements. `spec new product` scaffolds it.
2. **Prose MD body** (`spec-NNN.md`): the eight canonical sections. §4 carries
   only the framing sentence plus `Constraints:` and `Invariants:` bullets — zero
   `FR-`/`NF-` rows; §7 is prose with no coverage table.
3. **Requirement entities** via `spec req add`: each functional or quality
   requirement is a peer `REQ-NNN` entity, surfaced by `spec show` under a
   synthesized `## Requirements` section with its `FR-`/`NF-` label.

Real CLI surface: `doctrine spec --help` (scaffold a product spec, `req add` a
requirement member, `show` the reassembled whole, `validate` corpus FK integrity,
`list` the specs). See `lib:reference/using-doctrine.md` for the verb model —
do not guess flags.

`spec req add` reserves a `REQ-NNN` member with bare fields. **To make it render
richly under `spec show`, hand-enrich the requirement entity TOML**
(`requirement-NNN.toml`): add a one-line `description` (the queryable statement)
and an `acceptance_criteria` array — there is no flag for these, they are
authored TOML.

Structural rules:

* Identity and flat fields live in `spec-NNN.toml`; narrative lives in
  `spec-NNN.md`.
* Functional and quality requirements are peer `REQ-NNN` entities — never prose.
* `FR-`/`NF-` are sticky **membership labels** recorded in `members.toml`
  (`FR-` functional, `NF-` quality); they are mobile, so cite the durable
  `REQ-NNN` in prose, not the label.
* Constraints and invariants have no entity kind — they stay as §4 prose bullets.
* Read the reassembled whole with `doctrine spec show <PRD-ref>` before reviewing
  or revising; run `doctrine spec validate` after structural edits (expect
  "corpus clean").

Never duplicate a functional or quality requirement into narrative prose — it
belongs as a requirement entity. This is the single hard rule the entity model
exists to enforce.

## Working procedure

When authoring a product spec:

1. Determine whether the subject is an evergreen capability or a single change.
2. If it is a single change, redirect to `/slice`.
3. Identify the product intent, scope boundary, and non-negotiable principles.
4. Extract every mechanically binding behaviour or quality bar into a requirement
   entity (`spec req add`); keep only constraints and invariants in §4 prose.
5. Separate functional (`--kind functional`) from quality (`--kind quality`)
   requirements; keep constraints and invariants as §4 prose bullets.
6. Define success measures and acceptance gates.
7. Describe behaviour at product level.
8. Describe the verification approach in prose §7 — no coverage table.
9. Record unresolved decisions as Open Questions.
10. Remove design, implementation, and phase-planning material.

When revising a product spec:

1. Preserve existing canonical requirements unless explicitly superseded.
2. Promote hidden obligations from prose into requirements.
3. Demote implementation details out of the product spec.
4. Tighten vague success measures into observable signals or gates.
5. Ensure every requirement has a verification path.
6. Add open questions rather than guessing missing product intent.

When reviewing a product spec:

Check for these defects:

* missing or vague Intent
* scope expansion hidden in Behaviour
* functional or quality requirements written as §4 prose rows instead of entities
* a per-requirement coverage table in §7, or prose citing mobile `FR-`/`NF-`
  labels instead of durable `REQ-NNN`
* `FR-` / `NF-` (functional vs quality) confusion
* constraints or invariants mistakenly promoted to requirement entities
* constraints written as preferences
* principles that do not constrain decisions
* success measures with no observable signal
* acceptance gates duplicated inconsistently between Success Measures and Verification
* behaviour that commits to implementation design
* requirements with no verification path
* open questions that should block downstream work
* unresolved questions silently answered by assumption

## Output expectations

When drafting from scratch, produce the complete product spec using the canonical structure.

When improving an existing spec, preserve the user’s canonical headings unless asked to remodel the document.

When giving review feedback, group findings by severity:

```md
## Blocking
## Material
## Minor
## Suggested rewrite
```

When information is missing, do not fabricate product intent. Either:

* write a clearly marked placeholder, or
* add an Open Question, or
* state the assumption explicitly if the user asked for a best-effort draft.

## Handoff

A settled product spec should enable downstream work.

After settlement:

* use `/slice` to scope a coherent change descending from the product spec
* use `/design` for per-change technical design
* use `/spec-tech` for durable technical specification

The product spec remains the source of truth for product intent, requirements, success measures, behaviour, and verification obligations.
