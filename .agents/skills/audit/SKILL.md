---
name: audit
description: Use after a slice's phases are implemented, when the task is now evidence, conformance, and reconciliation against the design — disposition every finding on a reconciliation review ledger (the RV kind) before closure.
---

# Audit

You are running the reconciliation loop: does the work match its design and
governance, and is every gap consciously dispositioned before reconciliation?

The audit stage runs on a **review ledger** — the RV kind (`RV-NNN`). The
shared ledger mechanics (open + prime, raise, dispose + resolve, the severity and
disposition vocab, synthesis, the close-gate, where reviews run) live in
`lib:reference/review-ledger.md` — **read it; this skill does not repeat the
verbs.**
What follows is the audit *lens*: the facet, the modes, the scope, the evidence 
the reconciliation loop demands, and the audit-specific harvest and closure tail.

Findings are append-only to the ledger and field-owned. An unresolved **blocker**
refuses the audit→reconcile and reconcile→done crossings (the close-gate teeth);
carrying every other finding to a terminal state is this skill's discipline, not
the binary's. The audit prose becomes the review's `## Synthesis`.

> **Dispatched slice — review the candidate surface, not the raw evidence.** When
> the slice was driven by `/dispatch`, `review/*` and `phase/*` are immutable
> evidence refs (R2); audit/repair runs against the **candidate interaction
> branch** published by `doctrine dispatch candidate create` (see `doctrine
> dispatch candidate status`). Record which surface you reviewed in the ledger
> `## Brief`, and link the admitting RV via `doctrine dispatch candidate
> admit --review RV-NNN`.

Inputs:

- the slice's implemented phases and their verification evidence
- `design.md` (canonical), `slice-nnn.md`, `plan.toml`
- relevant ADRs and tech specs (see `/canon`)

## Tool preference

Prefer the MCP review tools over the CLI when your harness has them
(`lib:reference/review-ledger.md` § Passing prose); `review unlock` and
`review paths` stay CLI-only.

## Audit lens

**Subject is always the slice — target-ladder rung 1.** An audit targets its slice
(the `--target`) and never degrades to prose; the closure-grade trigger is
satisfied by definition (it gates the slice's `audit→reconcile→done`). Do not
re-derive the subject — open the RV against the slice.

**Facet is `reconciliation`.** That is the lifecycle aspect this stage
interrogates. Posture, if any, rides `--raiser`, never a new facet
(`lib:reference/review-ledger.md`
§2).

**Audit mode** — pick one:

- **conformance** — post-implementation audit tied to a slice (the usual case).
- **discovery** — backfill or existing-code investigation.

**Self-audit (the usual case).** When you are both reviewer and author, drive both
roles with `--as <role>` — the raiser raises, verifies, contests, reopens,
withdraws and concludes; the responder disposes and amends. Roles belong to
acts, not agents; `--as` is cooperative role assertion, not a security boundary
(`lib:reference/review-ledger.md`, "Acts and roles").

**Disposition convention (audit-specific).** See the closed disposition vocab,
`lib:reference/review-ledger.md` §4. Audit must **never** use `follow-up` for
spec/governance items — those belong to the reconcile write surface, not the
backlog. Every finding ends `verified` (the observation is confirmed; a
delegated one once its brief entry exists); the *remediation* is reconcile's job
and is recorded separately — do not mutate a finding to `fixed`/`remediated`.

## Process

1. **Open the ledger for the slice** (replaces authoring `audit.md`): open a
   `reconciliation`-facet RV targeting the slice, then fill the ledger's `## Brief`
   with the lines of attack (what this audit probes and the invariants it holds the
   slice to). Verbs and flags: `lib:reference/review-ledger.md` §1–§2. Loose
   notes are
   insufficient for closure-grade work — findings belong in the ledger.

   Then prime it (`lib:reference/review-ledger.md` §2): `review prime` derives
   the path-set
   from the slice's selectors, and the ledger's staleness signal hashes it. What
   is **gone** is the old hand-curated `domain_map` (a dead authoring tax), not
   the `prime` verb. The mechanical drift signal from `slice conformance` (step
   2), computed from recorded source-deltas, complements prime rather than
   replacing it.
2. **Gather evidence** (the audit's divergent work):
   - prepare subject: do NOT switch the primary checkout's branch. An audit
     runs where the code is — the primary tree, a dispatch coordination tree, a
     linked worktree, or an adopted capsule tree; audit and close there, then
     land. Only a dispatch worker process is refused review writes; one writer
     per RV at a time (`lib:reference/review-ledger.md` §6, "Where reviews
     run").
   - **Run `doctrine slice conformance <id>` and read the algebra** — the
     mechanical path-conformance delta between what `design.md` declared
     (`design-target` selectors) and what git actually touched (recorded
     source-deltas). It reports three cells:
     - **undeclared** (highest signal) — paths edited but not in any
       `design-target` selector. Each is a finding candidate: scope creep, a
       missed design update, or an undocumented touch.
     - **undelivered** — `design-target` selectors that matched no actual edit.
       Declared-but-not-delivered: dropped work or a stale design.
     - **conformant** — count of paths that matched (each with its selector).

     Conformance is **necessary, not sufficient**: it says *where to look*, never
     *whether it passes*. Treat undeclared/undelivered as leads to disposition, not
     auto-findings. If it reports `unavailable` (empty registry) or `incomplete`
     (a completed phase carries no row), that gap is itself a
     finding: the registry was not recorded as phases landed; bootstrap with
     `doctrine slice record-delta <id> PHASE-NN --start <oid> --end <oid>` or note
     the partial coverage — never read a partial registry as clean.
   - run the tests/checks the design and plan require, **plus `doctrine check gate`**;
   - inspect observed behaviour against `design.md` and the phase `VT-` criteria;
   - note where behaviour and design diverge — each divergence is a finding.
3. **Raise + dispose every finding** on the ledger per
   `lib:reference/review-ledger.md` §3–§4.
   Hold the audit line on the **anti-escape pressure**: do not pick **follow-up**
   for spec/governance findings — dispose them `design-wrong` with the
   reconciliation-brief link, and the raiser verifies once the brief entry exists; for code findings, do not pick **follow-up** merely because the fix
   is large; do not normalise **tolerated** without a real rationale; and do not
   downgrade a true **blocker** to dodge the close-gate. If the right route is
   ambiguous after reading `design.md` and governance, stop and `/consult`.
4. **Synthesize.** Write the audit's reasoning as the review's `## Synthesis`
   (append it to `review-NNN.md`) — the closure story, the standing risks, the
   tradeoffs consciously accepted (the prose the old `audit.md` carried).
5. **Write the reconciliation brief.** Append a dedicated `## Reconciliation Brief`
   section to `review-NNN.md` — separate from `## Synthesis`. This is the
   structured handoff from audit to `/reconcile`, mapping every spec/governance
   finding to its target and the intended write surface:

   ```markdown
   ## Reconciliation Brief

   ### Per-slice (direct edit)
   - design.md §3: the eviction model changed from edge-at-a-time to per-SCC —
     update prose to match implementation.

   ### Governance/spec (REV)
   - ADR-NNN: branch-point staleness description is wrong → REV modify
   - REQ-NNN: cordage scale target verified at 50k nodes → REV status active
   ```

   Build the brief from every non-aligned, non-tolerated finding that touches
   design or governance. Group by write surface (per-slice direct edit vs.
   governance/spec REV). Each entry cites the finding id and describes the exact
   change needed.

   **Brief-surface guardrails.** `/reconcile` writes exactly two surfaces —
   per-slice artefacts (`design.md`, `slice-NNN.md`) by direct edit, and
   governance/spec by REV. Name a surface the writer skill will actually touch, or
   the brief stalls at reconcile:
   - **Plan criteria are off-surface.** `plan.toml` `EN-/EX-/VT-` (and `PHASE-NN`)
     ids are immutable-append (boot rule) — never a reconcile direct-edit surface.
     A divergence that would require *changing* a plan criterion is a design/plan
     escalation, not a "Per-slice (direct edit)" brief item. Do not write a brief
     item that edits `plan.toml`.
   - **Conformance findings name the registry verb, not the prose.** A "spurious
     undelivered / scope-creep" conformance finding is fixed by the **selector
     registry** (`doctrine slice selector rm`/`add`), which is what `slice
     conformance` reads (`slice-NNN.toml`). `design.md §6` is only the human
     mirror — a prose-only brief item leaves conformance red. Name the `slice
     selector` verb as the load-bearing change; cite the §6 edit as its mirror.

   **Human-facing synthesis.** When the audit has consequential material, give
   the human a short route through the participating systems, one important
   behaviour and its implementation, the tests that bear on it, and a remaining
   risk. For consequential Doctrine sources cited in a decision, name why each
   matters and give its exact `doctrine <kind> show <ID>` command. If deeper
   inspection would help, offer `/walkthrough` or `/pair` without requiring it.
   A focused question about which risk concerns the human may improve the
   synthesis; use the answer if asked, and do not turn it into a comprehension
   check. When a real finding supports it, an optional short mock peer challenge
   can help rehearse a decision or test its rationale. Keep the source and
   whether the objection is historical or simulated clear. A new substantive
   defect belongs on the RV ledger; the human's ability to answer is neither a
   finding nor an acceptance condition. Respect the project's engagement
   default and the human's verbal changes.
6. **Harvest (audit tail).** Sweep durable risks, decisions, and gotchas from the
   disposable runtime **phase sheets** into `notes.md` — the audit-specific lens —
   then drive the rest of the harvest (legs and sinks) per
   `lib:reference/harvest.md`.
7. **Hand off to reconcile.** Once the reconciliation brief is written and every
   finding is terminal, conclude the pass as raiser —
   `doctrine review conclude RV-NNN --basis …` (or `review_conclude`), stating
   what the audit examined — so `review status` reads `done · await=none`. A
   later raise or reopen clears the conclusion; conclude again after it. Then
   hand off to `/reconcile`. Do NOT
   hand off directly to `/close` — reconcile is the sole writer of reconciled
   truth; close only confirms the outcome. Record the lifecycle move:
   `doctrine slice status <id> reconcile` (bare number) — the binary refuses it
   while a blocker is unresolved.

## Outcomes

- Audit evidence is a structured RV ledger (`review-NNN.toml` + the review's
  `## Synthesis` + `## Reconciliation Brief`), not a hand-made `audit.md`.
- Every finding ends terminal with an explicit disposition (or is withdrawn), and
  the pass is concluded with a `--basis`.
- No unresolved `blocker` remains — the close-gate would refuse it.
- The reconciliation brief maps every spec/governance finding to its target and
  write surface.
- `/reconcile` receives a complete, actionable brief — not raw findings.
