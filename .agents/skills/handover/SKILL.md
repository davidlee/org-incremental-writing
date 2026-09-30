---
name: handover
description: Use when handing work to a fresh context — first bring the durable harvest current, then emit a continuation at one of two weights — a printed continuation prompt (light) or a handover.md context packet (full). Use whenever a fresh agent would more efficiently continue.
---

# Handover

First capture, then continue: ensure the durable harvest is current, then emit
the transient continuation the next agent starts from.

Guiding principle: existing durable artifacts should already provide suitable
context for handover. This skill is to **improve token efficiency** with
transient guidance those durable artifacts elide — and to confirm they are in
good condition.

## Harvest first — always, both branches

Before emitting anything, confirm the capture pass is current:

- **Governing slice:** its `## Harvest` must be fresh — the `fresh-as-of` stamp
  matches the current lifecycle position (phase / stage + head commit). If
  stale, run `/harvest` first — do not re-survey what the harvest already swept.
- **Another governing artifact (RFC, spec, review …):** the capture pass still
  runs — route produced / learned / open to their sinks per
  `lib:reference/harvest.md` §5;
  orientation falls back to entity queries.

Phase status accurate and work committed (or its uncommitted state noted)
remain adjacent truth checks.

## Design work short-circuits

A slice design under a managed run already holds its own continuation. Before
reaching for the dial, ask whether one is live:

```
doctrine design show <SLICE> --format status
```

**A run prints** — short-circuit. Do not compose a packet or a continuation
prompt; either would restate what the run already carries.

1. The harvest above is what makes the durable records current. Then land
   anything you settled this session that the run does not yet hold — status
   reports the outstanding obligation and the changes since the declared
   baseline, so check both against what is in your hands, not your memory.
2. Emit the resume command as the continuation:

   ```
   doctrine design resume <SLICE>
   ```

   It keys on the slice, not on a run id, so it stays true across runs. Add
   `--run <uid>` to have a mismatch refused rather than silently resumed
   against a different run.
3. Add residual prose **only** for context you can name that neither the run
   nor the durable records can represent. Stage, cursor, open questions,
   decisions and section review state are in the run; a copy of them starts
   ageing the moment you write it.

**No run — the command errors, and the error says which of two cases you are
in.** Nothing was ever started: there is nothing to short-circuit onto, so
continue with the dial. Or `design.md` is present and the snapshot is gone, and
the error names `doctrine design start <SLICE> --from-design`. **Do not run it
to manufacture something to hand over.** It builds a new run from the authored
prose — no attestation, receipt or gate clearance carries across — so handing
over its reference would promise more than it holds. Report the loss and hand
over with the dial.

This is for managed design runs. Nothing else has a run to short-circuit onto.

## The dial

One skill, two weights:

- **light** — print a continuation prompt; nothing written.
- **full** — write the `handover.md` context packet and print instructions
  pointing at it.

Default by context: phase boundary, dispatch conclude, or complex in-flight
state → full; a simple "continue this in a fresh context" → light. The user's
explicit ask overrides.

## Light: the continuation prompt

Print:

```
/route
(path to the governing artifact and the next obvious task)
```

If the next task is implementation-bound, include the specific artefacts to read
(`design.md`, `plan.toml`, the active runtime phase sheet) and name any
unresolved assumptions or design questions the next agent must assess before
declaring readiness. Have the continuation prompt **cite the open ids** from the
governing slice's `## Harvest` — the open DEC / QUE / ASM (decisions / questions
/ assumptions) — so the next agent inherits the live open items, not a stale
story.

## Full: the context packet

Write `.doctrine/*/<nnn>/handover.md` — the disposable, gitignored "start
here" for the agent picking up the next Phase or otherwise continuing the work.

It is scaffolding for the next session, not a durable record: durable facts
live in persisted artifacts, `notes.md` or the memory store (`doctrine
memory`); the handover only points at them and frames the immediate work.

For a phase:

- [ ] Read the just-completed `state/.../phases/phase-NN.md` (findings,
      hand-forward) and the slice `notes.md` `## Harvest` section for the
      produced / learned / open ids.
- [ ] Confirm the next phase's scope from `plan.toml` (EX/VT are authoritative).
- [ ] **At a dispatch conclude:** embed the `slice verify-vt <id>` VT
      summary block **and** a one-line regression status (from the verify
      beat's `check regression diff`) in the packet — surfacing any
      `UNCHECKABLE` / `WAIVED` / `Fail` gap at handover, not at audit.
- [ ] Emit the sections below into `handover.md`
- [ ] Print instructions (with path to `handover.md`) addressed to the next agent

For another artifact:

- [ ] adapt as appropriate — the harvest-first step above still applies
- [ ] author or replace `handover.md` in the most relevant artifact's folder
- [ ] Print instructions (with path to `handover.md`) addressed to the next agent

You must include a clear startup instruction (eg /route) with path to `handover.md`.

Then: STOP

### Shape (sections to emit) for a phase packet

- **Where this is** — phase status ladder + commit refs; what is DONE, what is
  now.
- **Reading List** — pointers to design/plan/notes, relevant other artifacts /
  code, key source `file:line`s. What the next agent should ingest to build
  context efficiently.
- **Artifacts / pointers** — scope / design / plan / notes / specs. Optional /
  reference material.
- **Terrain** — the surface to ride, not refork; e.g. what the last phase
  built. Point to it described elsewhere, or summarise if it is not.
- **Next actions** — the literal `doctrine slice phase <ID> PHASE-NN --status in_progress`
  (status is the `--status` flag, not a trailing positional) / other obvious and
  immediate next step(s).
- **Procedure & Caveats** — risks, unknowns and open decisions. Process
  guardrails (command, fill the sheet, TDD, commit, flip status, etc).
- **Environment notes** — build/gate/lint specifics; pre-existing dirty files
  to leave.

## Rules

- handover is gitignored + will be deleted — never put the only copy of a
  durable fact here.
- Link to durable artifacts, don't repeat their contents.
- Supersede stale notes explicitly; do not leave contradictory guidance.
- Don't summarize commands or procedures from skills. 
  The skill gets skipped. Accidents happen.
  Do reference the skill; describe relevant state. 
- Terse. Fragments fine. Reader is an agent, not human reviewer.
