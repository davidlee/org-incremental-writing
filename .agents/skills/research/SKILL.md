---
name: research
description: Use when a slice is scoped but not yet designed — run the pre-design research round and persist its evidence artefact — or when a consuming skill's staleness advisory reports drift. Produces a cited, verification-legended research.md that design and plan load-bear instead of recall.
---

# Research

The pre-design research round produces a persisted evidence artefact —
`research.md` — that later stages cite instead of re-deriving. Two read-only
threads (governance applicability; code map) plus cross-thread synthesis,
assembled by the orchestrating agent into one document.

The artefact lives at `.doctrine/slice/NNN/research/` — directly in the slice
folder, gitignored in place. Runtime tier: disposable working evidence;
durable findings are harvested at slice close.

**The verb:** `doctrine slice research <id>` — run it when the round starts
(it mints the research folder and stamps the staleness baseline,
`baseline.toml`), and again whenever you consume the artefact, to check
freshness. It is advisory, never a gate:
drift output is a prompt to refresh, and the command always succeeds. Flags
and mechanics: the CLI's help.

## The artefact — `research.md`

Mandated skeleton; refresh rounds revise sections **in place**, extra sections
are free-form:

- **Header** — producers (who/what ran each thread), baseline pointer.
- **Verification legend** — the ✓ discipline below.
- **Thread 1 — governance applicability** — binding constraints;
  checked-not-applicable *with stated reasons*; revision candidates.
- **Thread 2 — code map** — hotspots (files likely to change), cited facts,
  naming precedents.
- **Cross-thread findings** — where the threads intersect or conflict; often
  the highest-value section.
- **Design-input deltas** — what this research changes about the intended
  design.

Alongside it: `raw/<thread>.md` (verbatim thread output) and `baseline.toml`
(stamped by the verb).

## Citation forms

- Governance claims cite durable entity ids.
- Code claims cite `file:line`.
- An uncited claim is unverifiable by definition.

## Verification discipline

- ✓ = the claim was independently verified by the **consuming** agent (a grep
  or read of the cited site). Unmarked = researcher claim: cited, not checked.
- Design and plan may only load-bear ✓ rows, or rows they verify at point of
  use.
- Verification is asymmetric — verify what you lean on (about one grep per
  load-bearing claim), not everything.

## Running the round

- Spawn the project's research agents, one per thread, **read-only**; capture
  each thread's stdout to `research/raw/<thread>.md` — never inline bulk
  output into the conversation.
- What a research agent *is* (command, model, expectations) is
  project-defined — see the project governance doc's *Research agents*
  section. Doctrine ships no runner.
- **Graceful degradation:** if the project defines no research agents, run
  the threads yourself, or skip the round and say so in the artefact header.
- Researchers never write files or memories. The orchestrating agent distills
  `raw/` into the curated artefact — the doc points at raw for bulk.

## Prompt duties

Every thread prompt must demand:

- the citation forms above;
- the structured not-applicable form (each dismissed authority named, with a
  stated reason);
- output already in the artefact's section shape;
- no preamble (cheap models add it; the assembler strips it).

## Who invokes this

Single-sourced here; the invoking skills carry only short advisory pointers:

- `/slice` — after scoping, run the round before `/design`.
- `/design` — consumes the artefact; Thread 1 stands in for the bulk of the
  governance sweep; design assertions cite `research.md`.
- `/plan` — checks the staleness advisory; drafts selectors from the Thread 2
  hotspot map.
- `/phase-plan` — checks the advisory; on drift, refreshes only the affected
  sections, then re-stamps the baseline.
