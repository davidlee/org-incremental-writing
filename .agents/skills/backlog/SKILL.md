---
name: backlog
description: Use when the user wants to create, survey, triage, tag, or transition a doctrine backlog item (issue / improvement / chore / risk / idea) — `doctrine backlog` is the CLI surface; use this skill to drive the correct verb for the intent.
---

# Backlog

The backlog is the **work-intake home** — latent work intent captured as
`issue`, `improvement`, `chore`, `risk`, or `idea` items, triaged and
promoted into slices. 

`needs` = hard dependency. `after` = soft ordering (suggestion).

The CLI is the source of truth for exact flags: `doctrine backlog --help`

## Creating new backlog items:

- [ ] Determine kind membership / validity
- [ ] Survey backlog for potential duplicates / neighbors
- [ ] Prefer expanding / improving an appropriate existing item
- [ ] Choose a clear, concise title
- [ ] Create the new backlog item 
- [ ] Read & fill its template
- [ ] Tag it appropriately and consistently
- [ ] Record any dependencies and appropriate sequencing priorities

## Verbs


See `doctrine backlog --help` for the full verb list and flags.


## Kind membership

See `lib:reference/using-doctrine.md` § Which home for which record for the
backlog kinds and the work-intake membership test.

## Status lifecycle

See `doctrine backlog edit --help` for the status/resolution values and their
coupling.

## Tags

See `doctrine backlog tag --help` for the tag syntax and the `--remove` flag.

## Dependencies

See `doctrine backlog needs --help` and `doctrine backlog after --help` for the
hard/soft dependency semantics.

## Rules

- See `doctrine backlog --help` — the id prefix auto-selects the kind.
- See `lib:reference/using-doctrine.md` § Which home for which record — a risk
  is admitted only as unresolved work-risk.
- Don't hand-edit backlog TOML (`lib:reference/using-doctrine.md` § storage
  tiers) — use the verb; prose (`*.md`) is hand-edited.
- See `doctrine backlog list --help` — terminal items are hidden by default;
  `--all` or an explicit `--status` reveals them.
