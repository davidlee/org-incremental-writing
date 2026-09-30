---
name: route
description: Use at the very start of ANY substantive work in a Doctrine repo — before inspecting files, running commands, or writing code. The mandatory gate that chooses the governing skill. Skip it only when the user has explicitly told you to.
---

# Route

The mandatory routing layer for Doctrine. The routing gate concept is
documented in [[mem.concept.doctrine.routing-gate]]. Follow it rigorously *unless* the user
has instructed otherwise. If the user explicitly invoked a skill, use that 
now; if the routing layer indicates a subsequent action in a chain, go on 
with it afterwards.

Do not respond, explore, inspect files, run commands, or start implementation
until you have chosen the skill that governs the task. If there is a reasonable
chance another Doctrine skill governs it, route through that skill first.

Do not rationalize around this. If you skip routing because the task feels
familiar, simple, urgent, or "probably fine", you are doing it wrong:

- "I'll just inspect files first." → No. Routing decides *how* you inspect.
- "I already know the command shape." → No. Use the CLI, don't guess.
- "Small enough to skip routing." → Small tasks still need the right skill.
- "I'll gather context first and decide later." → Decide first.

When unsure, route to the stricter skill, not the looser one.

## The table rides the boot snapshot

The routing table, mid-flight rules (consult / record-memory / backlog / notes /
next / conduct postures), and core guardrails are already inlined in this
session's prefix (`@.doctrine/state/boot.md`). Apply them from there — this
skill does not restate them. What follows is route-unique.

## Route-unique rules

The core loop (slice→design→plan→execute→audit→close) is documented in
[[mem.pattern.doctrine.core-loop]].

- **Consult the backlog before choosing**: `backlog list` — is this intent
  already captured, and do open items bear on it?
- **Search before assuming**: when the owning artifact is not obvious, `doctrine
  search "<keywords>"` reaches every numbered entity in one query — `backlog
  list` alone covers only latent work. Scope, and the corpora it misses:
  `lib:reference/using-doctrine.md`.
- Authoring tech specs → `/spec-tech`; product specs → `/spec-product`;
  spec target or boundary unclear → `/spec-coverage-assessment` first.
- "There is a slice" does **not** route to `/execute` — the design, plan, and
  runtime phase sheet must exist first (the no-code-without-approved-plan gate).
- Do not import stricter ceremony than the project has adopted; surface a
  conflict between local doctrine and a routing default rather than improvising.

## CLI

`doctrine --help` (dev: `./target/debug/doctrine --help`) is the source of
truth. If `doctrine` is unavailable, STOP and alert the user.

## Governance edited this session?

The inlined prefix is written by a prior session's hook, so it can lag a
just-made edit. Freshen-now ritual: run `doctrine boot`, **then** `/clear` or
restart — regenerate THEN clear; `doctrine boot` alone cannot refresh the
already-inlined prefix. (Disk sentry, separate check: `doctrine boot --check`.)
