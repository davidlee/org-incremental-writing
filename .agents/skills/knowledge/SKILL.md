---
name: knowledge
description: Use when work surfaces something epistemic worth keeping — "we're assuming / proceeding as if X", "we decided X over Y", "open question worth outliving this session", "we're bound by X", "evidence for/against X", "testable hypothesis", or a stable concept worth naming — and when settling, relating, or surveying such records. Routes capture, settle, and survey intent to the correct `doctrine knowledge` verb.
---

# Knowledge

Knowledge records are the **epistemic home** — typed, citable entities for
what the project believes, chose, wonders about, observes, or is bound by.
Records *shape* work; they are never work items themselves.

Four homes, one line: work intent → backlog; epistemic state → knowledge
record; architectural decision → ADR; agent guidance → memory. See
`lib:reference/using-doctrine.md` § Which home for which record.

The CLI is the source of truth for exact flags and each kind's status
vocabulary: `doctrine knowledge --help`.

## Which kind

| phrase shape | kind |
|---|---|
| "proceeding as if X" (unvalidated premise) | assumption (ASM) |
| "we chose X over Y" (scoped/operational) | decision (DEC) |
| "unresolved — X?" (needs an answer) | question (QUE) |
| "bound by X" (externally imposed limit) | constraint (CON) |
| "observed — X" (citable observation) | evidence (EVD) |
| "testable claim X" (awaiting evidence) | hypothesis (HYP) |
| "stable mental model / term X" | concept (CPT) |

**DEC or ADR?** Project-global with architectural consequences →
`doctrine adr new`; scoped or operational → DEC.

## Verbs

See `doctrine knowledge --help` (and `doctrine link --help` / `doctrine
supersede --help`) for the verb list and flags. Link a record to the work it
shapes with `shapes` (`spawns` for work it caused); an evidentiary edge is
`supports` or `disputes`.

## Wrong home?

- Work intent (bug / improvement / chore / risk / idea) → `/backlog`.
- Reusable agent guidance, recipe, or gotcha → `/record-memory`.

Discriminator: a knowledge record is a citable epistemic *entity* in the
relation graph — relatable, gateable, supersedable; a memory is
retrieval-layer guidance for agents. The same line splits CPT from a memory
`concept`: a CPT names a stable project concept other entities will cite; a
memory explains how to think or work.

## Gating — association is not gating

See `lib:reference/using-doctrine.md` § Which home for which record for the
knowledge-record gating mechanic (`needs`, settle-to-unblock).

## Rules

- See `doctrine knowledge show --help` — the id prefix resolves the kind on read
  and transition.
- Capture seeds the kind's default state (held, proposed, open, active, …).
- Don't hand-edit record TOML (`lib:reference/using-doctrine.md` § storage
  tiers) — use the verbs; the prose body (`*.md`) is hand-edited.
