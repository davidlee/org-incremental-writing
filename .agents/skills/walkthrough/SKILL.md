---
name: walkthrough
description: Guided walkthrough of code, a diff/PR, architecture, tests, or docs — build the reader's mental model, explain the choices made and their tradeoffs, and critically evaluate the artifact. Use when the user wants to understand or audit something rather than change it. Adapts to expert vs learner; companion to the pair skill.
---

# Walkthrough

Lead the user through an artifact so they genuinely understand it — and pressure-
test it as you go. You are a presenter-reviewer, not a narrator: surface the
choices, the tradeoffs, the risks, and where you'd push back. A walkthrough that
only describes is a worse `cat`.

> **Calibrate to expertise or you actively harm.** Detailed remedial explanation
> *helps* a novice and *hinders* an expert (the expertise-reversal effect). Match
> the audience dial: scaffold the learner, skip straight to deltas and risk for
> the expert. Over-explaining to an expert is a failure, not thoroughness.

Covers any artifact: source, diff/PR, architecture, API, data model, tests,
docs, build, deploy/ops flow, or a design doc.

Walkthrough has a dual identity: when understanding is the *whole task*, it is
the governing activity itself; layered onto change work, it is a conduct
posture over whatever stage governs. Same loop either way — but layered use
never replaces the governing stage or its process.

## Dials

Set by the user, else inferred, else defaults:

```
/walkthrough audience=expert depth=deep
```

- **audience** — `expert` · `mixed` (default) · `learner` — the governing dial.
  - *expert*: start from architecture, invariants, risk, deltas. Highlight non-
    obvious coupling, edge cases, operational consequences, alternatives. Compact.
    Assume they resolve local syntax/framework details themselves. Lead with
    "here's where I'd push back."
  - *learner*: make tacit reasoning visible. Explain idioms at first use. Show a
    worked example before asking them to reason. Small checkpoints over lectures.
    **Fade** scaffolding as they demonstrate understanding.
  - *mixed*: explain the system map, not every syntax detail; offer optional
    deeper dives; watch for signals to add rigor or scaffolding and re-calibrate.
- **depth** — `skim` · `guided` (default) · `deep`: how far down the important
  path you trace — headline map only, the main path, or every branch and invariant.

## Loop

1. **Orient** — artifact, the user's goal, audience, what they already know.
   Agree the budget: which paths get traced, what is out of scope, and when
   the walkthrough stops. A deep dive into a large system balloons without a
   stated stopping condition.
2. **Map** — compact structure: entry points, components, data + control flow,
   dependencies, boundaries. The mental model before the details.
3. **Trace** — walk the important path at the chosen depth. Prefer *causal*
   explanation: what happens, why, what depends on it, what breaks if it changes.
4. **Explain the choices** — name the decisions the author/system made; give the
   likely motivation, the alternatives, the tradeoffs accepted.
5. **Challenge** — see below.
6. **Check understanding** — *only when learning is a goal* (see below).
7. **Record** — close with: what's sound, what's questionable, what should
   change, what's still uncertain. Then route what must outlive the session:
   changes worth making re-enter the change loop (below); everything else
   harvests per `lib:reference/harvest.md`. A closing summary that lives only in
   chat
   evaporates — harvesting nothing is valid, but make it a decision, not a
   default.

## Challenge

Always on, calibrated — the same posture as the `pair` skill. Raise a *credible*
concern on correctness, maintainability, security, performance, observability,
testability, scope, architectural fit, migration risk, brittle abstraction, or
misleading docs. When you do: name it, state the consequence, offer an
alternative, mark blocker vs preference. Don't litigate trivia.

## Check understanding (learner / mixed only)

When the goal includes learning, use comprehension checks instead of just
telling — they're how the model transfers, not a quiz:

- predict before reveal ("what must this variable hold before you read on?")
- compare-and-contrast two approaches
- "what breaks if this changes?"
- ask them to name an invariant, or why an alternative was rejected

Never gratuitous. A check that doesn't improve comprehension just slows the
session — cut it. For an `expert` audience, skip checks entirely.

## Handoff to pair

When a walkthrough surfaces a concrete change worth making, hand off to the
`pair` skill to make it — preserving the current audience/depth as pairing
dials. Inverse too: `pair` hands back here when the user needs to understand what
changed, why a design was chosen, or how a subsystem behaves.

In a Doctrine repo the handoff target for a discovered change is **`/route`**, not
free pair edits — route picks the governing stage (slice/preflight/…), then you
pair *within* the resulting phase. A walkthrough must not become a governance bypass.

## In a Doctrine repo (optional)

Portable; ignore elsewhere. Inside Doctrine, read entities via
`doctrine <kind> show <ID>` (both TOML and prose tiers) rather than raw files,
and treat `/canon` + memory as the authority on *why* a thing is the way it is.
Walking through to make a change still routes through the change loop, not free
edits. Harvest per `lib:reference/harvest.md`; the walkthrough-specific route:
closure-grade
findings on a reviewable artifact → `/code-review` and its RV ledger.
