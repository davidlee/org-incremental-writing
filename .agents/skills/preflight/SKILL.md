---
name: preflight
description: Use after routing has chosen this path, when the next step is bounded up-front research to understand a substantive task, surface unknowns and tensions, and assess readiness — without drifting into implementation or open-ended exploration.
---

# Preflight

`/route` routes into `/preflight`; it does not replace `/route`. Use this only
after routing has established that the immediate need is bounded up-front
research. If you have not chosen the governing skill path yet, stop — use
`/route` first.

You're about to begin work on something: $ARGUMENTS

First: you need to understand what it entails. Your immediate task is to
correctly decide how much effort to spend on this preliminary research.

Too little is as bad as too much. You must estimate where the goldilocks zone is,
and arrive with maximum tokens intact.

You may be expected to:

- clarify a vague task
- methodically diagnose a fault
- write or critique a thorough and considered design doc which fits the
  implementation surface
- execute a thoroughly prepared plan with efficiency
- preserve your own context by delegating to sub-agents

Do not use this skill to decide whether the task belongs to `/slice`,
`/design`, `/execute`, or another governing skill. That decision must already be
made.

If you can't tell whether `/preflight` is appropriate, you probably need
`/route`, not this skill.

Learn **just enough to ask the user the right clarifying questions**. These
might include: how deeply should you research? what remains ambiguous? which
assumptions are safe enough to carry forward?

If you chase the questions which arise as you go, you'll disappear like a
helium balloon into the open sky.

Instead:

1. Read the material in front of you
2. Take stock of relevant `/retrieve-memory` and `/canon`
3. Confirm your stopping conditions before you expand the search
4. Decide **up front**, out loud:

- what, concretely, you need to know.
- when, concretely, you will stop even if you don't have all the answers.

5. Remain curious and collect further questions, but don't run off after them.
6. Stop when you reach your stopping conditions.
7. Before declaring readiness, produce a critical assessment with these headings:

- confirmed inputs
- assumptions you would carry into the next step
- unresolved questions, risks, or dependencies
- tensions or ambiguities (including any apparent contradictions between artifacts, or design & implementation surface)

8. If the task is implementation-bound, do not conclude "ready to proceed", "no blockers", or equivalent unless you explicitly state one of:

- no open questions remain after reading the governing artefacts
- open questions remain, but they are consciously accepted as implementation assumptions

9. Treat scope-shaping uncertainty as important even when it is not a hard blocker.
   Call out things like interaction semantics, ownership of mappings/constants, phase-boundary ambiguity, widget/API choice, or design-vs-discretion gaps.
10. Present any significant discoveries, open questions, unresolved tradeoffs to the user.
11. Indicate the next governing step; suggest the next skill or workflow transition, or further investigation required.

Repeat this process to clarify further, if the user indicates to.

## Guidance

Breadth first: start broad and high level, drill down as necessary.

Search order:

- provided artifact(s)
- related / linked files, documents, artifacts
- `doctrine search "<query>"` — the cheapest way to locate a thing whose owning
  artifact you cannot name: one ranked query over the entity corpus. It reaches
  neither memories nor the reference docs, and its default kind set excludes
  policies and standards — `lib:reference/using-doctrine.md` gives the scope
  and how
  to widen it.
- related governance (ADRs, standards, policies) — see `/canon`
- related tech specs under `.doctrine/spec/tech/`
- `/retrieve-memory`
- the backlog (`backlog list` / `backlog show <ID>`) — is this work already
  captured, and which open items bear on it?
- knowledge records (`doctrine knowledge list`) — do unsettled records gate or
  shape this surface? Assumptions you choose to carry → capture as ASM via `/knowledge`.
- related artifacts (provisional: may be out of date)
- code

## Guardrails

- Do not let `/preflight` steal the job of `/route`.
- Do not treat bounded research as permission to start implementation.
- Do not widen scope just because new curiosities appear.
- Do not confuse "I can start coding" with "the materials are ready". Readiness
  means you have surfaced the remaining unknowns and either resolved them or
  named them as conscious assumptions.

Do not begin implementation without acknowledgement from the user.
