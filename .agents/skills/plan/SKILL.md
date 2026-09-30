---
name: plan
description: Use when a slice's design is locked and it needs an executable phase plan — refine each phase's objective and entry/exit/verification criteria, author plan.toml + plan.md, and materialise the runtime phase sheets. Routed to from /design.
---

# Plan

You are turning design intent into an executable phase plan.

Inputs:

- `slice-nnn.md` (scope)
- `design.md` (canonical design reference)
- existing `plan.toml` / `plan.md` (when present)

## Process

1.  Read the slice scope and `design.md` together.
2.  Confirm planning is not getting ahead of design:
    - if `design.md` is missing or blank, stop and run `/design` unless you have
      been **explicitly instructed** otherwise.
    - if `design.md` exists but is stale relative to the current ask or slice
      scope, reconcile the design first. Clarify with the user if ambiguous.
    - you MUST NOT treat plan or phase creation as a substitute for unresolved
      design.
    - if planning surfaces substantive new design problems, run `/design` to
      revise or append to the design before continuing.
    - **re-grep before you trust the design's premises.** The design was locked
      at author-time; the tree has moved since. Scan `design.md` for concrete,
      grep-pable references — file paths, function/type names, constants, config
      keys — and resolve each against the *current* tree (`grep`, `ls`,
      `git show`). A missing path, moved file, or renamed symbol means the design
      rests on a stale premise: STOP and run `/design` to reconcile it before
      scaffolding phase sheets against wrong paths. (A design that names nothing
      concrete has nothing to check — this costs only what the design asserts.)
    - **check the research advisory** (`doctrine slice research <id>`), then draft
      the slice's selectors from its Thread 2 hotspot map rather than from recall
      — the design-time selector dry-run is only the checking half.
3.  Scaffold the plan: `doctrine slice plan <ID>` writes `plan.toml` + `plan.md`
    (refuses to clobber existing files). The tool reads these but never rewrites
    them — hand-edit freely.

    **Routed findings from the design review (provisional).**
    Before authoring phases, open the slice's design-review RV and read every
    finding whose `route` is `demonstrate`, `probe` or `control`. The table view
    of `review show` does not render the route — see
    `lib:reference/review-ledger.md` § Route axis for how to read it: JSON
    `.review.finding[].route`, MCP `findings[].route`, or an older ledger's
    `route:` disposition prefix (`route:probe fix-now`, say). Each is an
    obligation deliberately not repaired in prose. Its response carries a
    criterion sketch and a placement constraint: transcribe the sketch into an
    entry or exit criterion citing `RV-NNN F-n` inline in the criterion text, on
    the earliest phase that satisfies the constraint. An untranscribed routed
    blocker cannot honestly be verified, and an unverified blocker refuses the
    slice close. Nothing validates the transcription.

4.  Author `plan.toml` — one `[[phase]]` per ordered phase:
    - `id` is `PHASE-NN` (zero-padded), **immutable** and never reused — edits
      append, they never renumber.
    - `name` and `objective` for the phase.
    - `entrance_criteria` (`EN-n`), `exit_criteria` (`EX-n`), and `verification`.
      Verification ids carry their mode: `VT-n` verified by test, `VA-n` by
      agent, `VH-n` by human — use `VA`/`VH` when a test cannot judge the
      criterion, so it is still checked downstream rather than silently skipped.
      These ids are local to the phase and equally immutable.
    - **Structured VT mandate (NON-NEGOTIABLE).** Every `VT-n` row MUST carry
      at minimum `test_file` + `keywords` so the VT gate has signal. Without
      them `verify-vt` reports `UNCHECKABLE` — the gate is inert project-wide.
      Write the mandate in the TOML row, not prose:

      ```toml
      { id = "VT-1",
        expects = "round-trip unit: the new fn parses, renders, and re-parses",
        test_file = "src/your_test.rs",
        keywords = ["your_fn", "your_struct"],
        patterns = ["^\\s*pub fn"],   # optional: stronger line-anchored shape
        waived = false }
      ```

      - `test_file` — the ONE file where the keywords will actually appear
        (the production source or a test file the phase touches). The mandate
        carries a single `test_file`; all keywords must live in that one file.
        Pick the file that the phase changes, or the test file that exercises
        it — not both. This must be a path that will exist after the phase
        lands, not a future file.
      - `keywords` — raw substrings that MUST appear in that file after the
        phase lands. They are the proportionate floor: plain substring match
        over the raw source (no comment/string stripping).
      - `patterns` (optional) — line-anchored regex for a stronger
        language-agnostic shape assertion. The author owns the regex.
      - `waived` — escape valve with a mandatory `waived_reason`.

      `doctrine slice verify-vt <id>` gates every VT mandate at dispatch
      conclude/handover, not at audit. A `test_file` with no keywords
      passes vacuously — the keyword floor is what gives the gate teeth, not
      the file alone.
    - `specs` / `requirements` stay empty in v1 (no registry yet). When a slice
      does carry relations, they are written with `doctrine link` (not typed keys
      here) — see `lib:reference/using-doctrine.md` § Relating entities.
5.  Author `plan.md` — the rationale and sequencing prose: why these phases, in
    this order, with these boundaries. Honour the storage rule
    (`lib:reference/using-doctrine.md` § Storage tiers): no queried or derived
    data in `plan.md`.
6.  Commit.
7.  Consider plan critically: what's under-specified, assumed, ambiguous,
    oversized, optimistic, requires verification, or presents implementation risk?
    For each of these, decide what new information is needed, or what mitigations
    to put in place. Ground the plan in known details of the implementation.
8.  Plan the revision; print a summary of it for the user. Then work through it.
9.  Revise the plan; commit again. Summarise what changed.
10.  Materialise phase tracking: `doctrine slice phases <ID>` creates the per-phase
    sheets in the state tree from `plan.toml`. `--prune` removes orphan tracking
    whose plan phase is gone (destructive — only when you meant to drop a phase).
11. Hand off to `/phase-plan` to expand the next phase's runtime phase sheet
    just before execution — then `/execute`. Do this only after slice scope, `design.md`, and
    the plan tell the same story. Record the lifecycle move on handoff:
   `doctrine slice status <id> ready` (bare number).

## Outcomes

- `plan.toml` is execution-ready: every phase has an objective and EN/EX
  criteria plus verification in an explicit mode (VT/VA/VH).
- `plan.md` explains the rationale and sequencing.
- A runtime phase sheet exists per phase with clear done criteria.
- If plan complexity or policy ambiguity emerges, STOP and `/consult`.
