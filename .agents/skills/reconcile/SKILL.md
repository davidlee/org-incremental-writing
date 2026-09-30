---
name: reconcile
description: Use after /audit resolved the RV ledger and wrote the reconciliation brief — you are the sole explicit writer of reconciled truth. Consume the RV + brief, write changes through two surfaces (direct edit for per-slice artefacts, REV for governance/spec), and hand off a resolved outcome to /close. Routed to from /audit.
---

# Reconcile

You are the **sole explicit writer** of reconciled truth — the writer half of the
`audit → reconcile → close` seam. Audit identifies what
changed and assembles the reconciliation brief; you consume it, write the changes,
and record what was done. Close confirms the outcome before the terminal transition.

You write to **two surfaces** with different mechanisms:

| Surface | Mechanism |
|---|---|
| **Per-slice artefacts** (`design.md`, `slice-NNN.md`) | Direct edit with user agreement |
| **Governance/spec truth** (ADRs, specs, requirements, policies, standards) | REV kind (`doctrine revision`) — typed `[[change]]` rows, approval checkpoint, apply path |

Project-local documentation outside `.doctrine/` is **not** a doctrine feature category — edit
it directly like any project file, same as per-slice artefacts.

A single reconcile pass may use both surfaces — e.g. update `design.md` directly
*and* author a REV for an ADR amendment. Where each change lands is driven by the
reconciliation brief, not guessed.

> **A brief item can name a surface you don't write.** `plan.toml` criteria
> (`EN-/EX-/VT-`, `PHASE-NN`) are immutable-append (boot rule) — not a reconcile
> surface. If a brief item asks you to edit a plan criterion, do not; hand it back
> to `/audit` or `/consult` as a design/plan escalation. And a conformance /
> "spurious undelivered" item is fixed by the **selector registry** (`doctrine
> slice selector rm`/`add`) — the load-bearing verb — not by a `design.md §6`
> prose edit alone (§6 is only the mirror; `slice conformance` reads the registry
> in `slice-NNN.toml`). Edit prose only, and conformance stays red.

> **No CLI verb surface.** `doctrine slice reconcile` is not built yet (deferred).
> You drive existing verbs (`doctrine revision *`, direct file edits)
> as manual discipline — same posture as `/audit` today.

> **Inspect, don't re-audit.** You inspect target artefacts to validate
> applicability, locate edit points, and detect drift since audit — but you do not
> perform new issue discovery. If you discover a *new* gap not in the brief, do not
> open a new finding here; hand it back to `/audit` or raise it with `/consult`.
> The seam stays intact: audit owns discovery, you own the write.

Inputs:

- the **RV ledger** — `review-NNN.toml` (finding status) + `review-NNN.md` (the
  review markdown, carrying the reconciliation brief)
- the **`## Reconciliation Brief`** section within `review-NNN.md` — the structured
  handoff from audit. It maps findings to target artefacts, split into
  per-slice (direct edit) and governance/spec (REV) items. Its shape:

  ```markdown
  ## Reconciliation Brief

  ### Per-slice (direct edit)
  - design.md §3: the eviction model changed … update prose

  ### Governance/spec (REV)
  - ADR-NNN: branch-point staleness description is wrong → REV modify
  - REQ-NNN: cordage scale target verified at 50k nodes → REV status active
  ```

The brief lives in a dedicated section, separate from `## Synthesis` (the audit's
closure story).

## Human-facing reconciliation

For a consequential proposed change, make the current passage, proposed
passage, and effect on future work legible before asking for the existing
confirmation or REV approval. Give enough context to judge the change and the
exact `doctrine <kind> show <ID>` command for consequential Doctrine sources.
Offer `/walkthrough` of the passages and their implications when it would help;
an answer about remaining risk or intent may improve the proposal, so carry it
into the write. This composes with the confirmation below: do not add a second
acceptance act or require the human to prove understanding. Respect the
project's engagement default and the human's verbal changes.

## Process

### 1. Read inputs

Read `review-NNN.md` for the `## Reconciliation Brief` section. Read finding
status with `doctrine review show RV-NNN` — confirm **every finding is terminal**
(`verified` / `withdrawn`) and the pass concluded (`doctrine review status
RV-NNN` reads `done · await=none`). A finding still `open` / `answered` /
`contested`, or an unconcluded pass, is an incomplete audit — stop and hand back
to `/audit`.

Findings stay `verified` — remediation is recorded separately by you, never by
mutating the finding disposition. Record the RV id and the brief items you will act
on.

### 2. No-op gate

If the reconciliation brief is **empty** — every finding was withdrawn or tolerated
with no writes needed — append a `## Reconciliation Outcome` section to
`review-NNN.md` confirming the no-op, then hand off to `/close`:

```markdown
## Reconciliation Outcome

All findings were withdrawn or tolerated with rationale. No writes needed.
Reconcile pass complete — handoff to /close.
```

### 3. Per-slice edits

For each direct-edit item in the brief:

- **Present** the proposed edit to the user. Show the exact location, the old text,
  and the new text. Get confirmation before writing.
- **Write** the edit to `design.md` and/or `slice-NNN.md` (if scope changed during
  implementation).
- **Record** what was edited — and which finding drove it — in a running
  reconciliation outcome. You will append this to the RV markdown in step 6.

### 4. REV authoring

For each governance/spec item in the brief, author a REV change. Multiple
governance items may be collated into a single REV per slice by default (one
`reconcile SL-NNN` REV with multiple `[[change]]` rows), or into separate REVs
when items need independent debate (see the split rule below).

#### 4a. Discover or create the REV

If the brief records a REV id, use it:

```bash
doctrine revision show REV-N
```

Otherwise, create one by convention:

```bash
doctrine revision new "reconcile SL-NNN" --slug reconcile-sl-NNN
```

The REV starts `proposed` with no change rows. Transition it to `started` before
adding rows:

```bash
doctrine revision status REV-N started
```

#### 4b. Collision guard

If `reconcile-sl-NNN` slug already exists, **inspect** before reuse:

```bash
doctrine revision show REV-N
```

- **If related** (same slice, same class of change) → reuse it; append new
  `[[change]]` rows.
- **If unrelated** (different slice or intent collided on slug) → create a distinct
  slug or ask the user for a decision. Do not silently mix unrelated changes in one
  REV.

#### 4c. Add `[[change]]` rows

For each governance/spec item, append a typed row:

```bash
doctrine revision change add REV-N --action <action> [--target <T>] [--to-status <S>] [--new-label <L> --member-of <SPEC>] [--primary]
```

See `doctrine revision change add --help` for the `--action` values and their
flags.

See `doctrine revision apply --help` for which `--action` values auto-land vs.
surface for manual landing.

#### 4d. Record the reconcile narrative

Write the reconciliation rationale into `revision-NNN.md` — what changed, why, and
a link back to the RV finding that drove it. Example:

```markdown
## Reconcile narrative

- [RV-NNN finding F-3]: the branch-point staleness description was wrong.
  Updated to match the CAS row semantics from the coordination slice.
- [RV-NNN finding F-5]: the scale requirement verified at 50k nodes. Status moved to `active`.
```

#### 4e. Split rule

If any row is known to require **separate debate** or will not land in this pass,
**split it into its own REV before approval/apply**. Do not create a half-applied
omnibus REV that blocks close because one row is stuck. A REV stays `started` until
all rows land — a stuck row in an omnibus REV blocks the whole slice.

### 5. Approve & apply

When all `[[change]]` rows are written and the narrative is complete:

```bash
doctrine revision approve REV-N
doctrine revision apply REV-N
```

- `approve` records the orthogonal approval — `apply` refuses without it
  (invoker-blind: a solo dev self-approves).
- `apply` auto-lands `status` rows and surfaces `modify` / `create` / `introduce` /
  `move` / `retire` / `prose` rows for manual landing. A pre-flight from-guard
  aborts the whole apply if any target moved since the change was drafted — if this
  fires, re-inspect the affected targets and retry.
- Note which rows were auto-landed and which are surfaced-for-manual.

### 6. Manual prose landing

For surfaced-for-manual rows, perform the edits by hand under the **authored-truth
honour model**. The REV tells you *what* to change; you make the actual file edit.

When all surfaced rows are landed:

```bash
doctrine revision status REV-N done
```

Then record the reconciliation outcome on the RV. Append a `## Reconciliation
Outcome` section to `review-NNN.md`:

```markdown
## Reconciliation Outcome

### Direct edits applied
- design.md §3: updated eviction model prose → matches implementation (finding F-2)

### REVs completed
- REV-NNN (`reconcile-<slug>`): done — the staleness description amended, REQ-NNN → active
  (covers findings F-3, F-5). Rationale in revision-nnn.md.

### Withdrawn / tolerated
- Finding F-4: tolerated — drift in error message wording; rationale in finding disposition.
```

### 7. Escalation gate

If while reconciling you discover that the **model itself is inadequate** — not
mere instance drift, but a design flaw that the change cannot be expressed within —
escalate back to design:

```bash
doctrine slice status <id> design
```

This is the design back-edge: `reconcile → design`. Describe the inadequacy in
a note (the `--note` flag), and what the design needs to resolve. Do not improvise
a fix that the governing design does not support.

When all items are resolved and the outcome is recorded, hand off to `/close`.

## Outcomes

- Every governance/spec item from the reconciliation brief is resolved: covered by
  a `done` REV, withdrawn with rationale in the RV, tolerated with rationale in the
  RV, or escalated to design.
- Every per-slice direct-edit item is applied to its target file.
- The RV carries a `## Reconciliation Outcome` section recording what was done and
  why.
- Each REV carries a reconciliation narrative in its `revision-NNN.md`.
- The slice is ready for `/close` — every item is resolved; no half-applied REVs
  block the close-gate.
