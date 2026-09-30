---
name: canon
description: Use before making architectural or workflow choices, when correctness depends on project governance, or when entering an unfamiliar subsystem — to load the project's authoritative rules before you act on assumptions.
---

# Canon

Understand project governance before you act, so you do not spread heresy.

## Articles of truth

Identify the authorities that bear on your task, then read the ones that carry
meaning for it — not all of them, every time. The CLI is the source of truth —
see [[mem.fact.doctrine.cli-source-of-truth]].

- `CLAUDE.md`, `AGENTS.md` — standing instructions and conventions. Project
  conventions are documented in [[mem.pattern.doctrine.conventions]].
- project governance - list each of these; read any which are potentially relevant 
  in full, with `doctrine <kind> show <id>`:
  - `doctrine spec list` - specs describing product intent / technical architecture
  - `doctrine adr list` - architecture decision records 
  - `doctrine policy list` - policies 
  - `doctrine standard list` - standards of practice
  - or jump straight to the ones bearing on your task: `doctrine search
    "<keywords>" -k governance`. Policies and standards sit *outside* the
    default kind scope, so a bare search misses exactly the rules you came for —
    `lib:reference/using-doctrine.md` has the scope and the widening flags.
- the governing slice's `design.md` — canon for *this* change's design intent.

For implementation truth (gotchas, patterns, invariants tied to files or
commands), `/retrieve-memory` rather than rediscovering it.

**Read entities tier-aware — via `show`, never a single raw file.** The storage
rule + read-via-`show` discipline are resident in the boot digest and detailed in
`lib:reference/using-doctrine.md`. The storage model and storage rule are
documented in
[[mem.concept.doctrine.storage-model]]; storage tiers: authored, runtime,
derived — see [[mem.fact.doctrine.storage-tiers]]. Reading one tier and
concluding "empty" is false witness.

## The mortal sins

Beware — and refuse to commit:

- **assumption** — acting on what you guessed instead of what you confirmed.
- **guesswork** — inventing ids, command shapes, or file locations.
- **duplication** — a parallel implementation where a seam already exists.
- **architectural infidelity** — violating the design or an ADR.
- **heretical coupling** — new imports or dependencies that breach boundaries.

If governance is missing, contradictory, or ambiguous on a choice that matters,
stop and `/consult` rather than normalizing around a guess.
