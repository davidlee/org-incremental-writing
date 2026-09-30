---
name: design
description: Use when a slice needs architectural shaping before implementation — decision triage, critical analysis of tradeoffs and solutions, and section-by-section validation of design.md until the decisions lock. Routed to from /route once a slice exists.
---

# Design

You are translating scoped intent into implementable design.

**This skill is an adapter, not the workflow.** The stages, their order, and the
obligations on each live in the design run — a deterministic machine in
Doctrine. Every `doctrine design` command prints the guidance for the turn you
are on, and that output is your instruction: read it and do what it says. Do
not decide the order here, and do not reconstruct it from this file.

## Activation

1. **Establish or resume the run.** `doctrine design start <slice>` when none
   exists, `doctrine design resume` when one does.
2. **Surface the envelope and do what it says.** It carries the stage and
   `forward`: what the next advance still needs, in order.

## Recovery

No run exists — start one. There is nothing to recover.

A stale one exists — `doctrine design resume --run <id> --known-revision <rev>
--known-fragment <frag>`, the compact re-entry projection.

There is no per-state recovery logic, deliberately: the run reports where it
stands and its outstanding obligations return with it. Recover through
`doctrine design resume`, never by replaying the conversation. If evidence is
absent, it is absent, and saying so is the correct answer.

## Degradation

**Detect and surface. Do not self-heal, and do not improvise a design workflow
of your own.** A skill and its binary can desync in both directions. If
`doctrine design` is missing or refuses, report what it said — a refusal names
what it objected to — and stop.

## Residue

One obligation the machine does not carry:

| item | why it is not delivered at a moment |
|---|---|
| **The Locked exit.** Record the lifecycle move — `doctrine slice status <id> plan`, bare number — then invoke `/plan`. | Deferred, not ambient. `Stage::Locked` has no outbound forward edge to key a runbook to, so neither asset kind can hold it. Awaiting a second case to shape the handoff against. |

## Pointers

- `/consult` — meaningful tradeoffs or uncertainty left unresolved. Do not
  improvise past them.
- `/knowledge` — an open question → QUE, a locked choice → DEC, an assumption
  the design carries → ASM.
- `lib:reference/using-doctrine.md` — relations move via
  `doctrine link` and lifecycle via `doctrine slice status`, never by hand-edit.
