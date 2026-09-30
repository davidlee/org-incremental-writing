---
name: dispatch
description: Use to drive a slice's phases to completion through confined subprocess workers in isolated worktrees — you orchestrate and are the sole writer, the workers execute. Workers spawn via `/dispatch-spawn`, one path for every harness. You drive the landing yourself — import, commit, record, verify, conclude, reap; `doctrine dispatch next` prescribes only for a fork bound at creation, which this path does not mint. Default serial (one worker per phase); parallelize file-disjoint phases. Conflicts report-and-halt, never auto-merge.
---
# Dispatch (router)
Drive a slice's phases to completion through confined subprocess **workers** —
you are the orchestrator and **sole writer**, they execute.

**Announce at start:** "Using the dispatch skill to drive phases through confined
workers."

## The outer loop
1. `dispatch setup --slice <N> --dir <path>` — create/resume coordination worktree.
   Under a Claude harness `--dir` MUST resolve inside the project root (convention
   `.dispatch/SL-<n>`); an outside-root dir fails closed. Other harnesses
   keep their enforced outside-root isolation.
2. Commit the orchestrator's own authored writes (slice status, memory, audit)
   with `dispatch commit --slice N -m <msg> -- <path>…` (pathspec-mandatory),
   never a raw `git commit`.
3. `dispatch plan-next --slice <N>` — find next actionable phase(s); plan parallel batches when file-disjoint
4. Spawn worker(s) via [`/dispatch-spawn`](../dispatch-spawn/SKILL.md) — one
   confined subprocess path for every harness (default to the `pi` harness until
   `preferred-subprocess-harness` selection is wired).
5. Land each phase yourself — import, commit, record the boundary, verify, flip
   the phase to `completed`, reap the fork (below)
6. Conclude: `slice verify-vt <id>` (VT gate, coord tree) → on green
   `dispatch sync --prepare-review` → remove coord worktree → audit

## Per batch

**Base-clean precondition (pre-spawn, NON-mutating).** Before capturing `B` /
spawning any worker — and on `main` before you branch the coordination fork —
assert the base is prove-clean:
```
doctrine check prove     # fmt-check + lint; asserts, never fixes
```
A RED base is a **BASE defect**, DISTINCT from any worker finding: it means the
tree you are about to fork from is already unformatted or lint-red. Remediate it
operator-side — a format-and-commit you own (or an isolated prep worktree) — and
NEVER fold it into a worker delta, NEVER auto-fix it. A worker spawned off a dirty
base would either inherit the red (and be halted at import for a defect it did not
cause) or launder it. Run this exactly once per batch here on the hot path (the
only other prove run is the post-import gate below — do not double-run).

Capture `B = git rev-parse HEAD` pre-spawn, then capture the regression
baseline on the coord tree at `B`:
```
doctrine check regression capture --base "$B"     # suite @ B; no-op on cache hit
```
**Normalise filter state before BOTH this capture and the verify diff**:
confirm `DOCTRINE_WORKER` is unset in your own environment and force a real
rebuild, so capture and diff run an identical suite invocation + test selection.
Same tree alone is insufficient — a leaked `DOCTRINE_WORKER` changes which tests
run and breaks the cancellation property (a fingerprint mismatch is then a cache
miss → honest re-capture, never a poisoned baseline).

Worker self-reports are advisory; trust only your own verify beat.

### Landing a phase: you drive, in this order

The worker hands back an **uncommitted working tree** (it cannot commit — the
real git dir is read-only inside its jail). You land it: `worktree import
--from-worktree` → one coordination commit → `slice record-delta --commit <S>` →
run the phase's verification → `slice phase --status completed` → reap the fork.
`/dispatch-spawn` carries the mechanics and the refusal semantics of each step;
the beats below are the ones that belong to the batch rather than to a single
phase.

### The funnel oracle — for a bound fork only

See `lib:reference/dispatch-mechanics.md` § The funnel record, and when it is
the driver.

The machinery is retained and unchanged; what it prescribes when a row *does*
exist:

| `kind` | what it prescribes |
|---|---|
| `spawn` | no funnel row yet — hand off to `/dispatch-spawn` (a script invocation, so `next` emits no literal) |
| `await-worker` | the fork is armed; wait for the worker to return |
| `import` | land the worker delta (`dispatch_import`, MCP-only) |
| `verify` | run the phase suite and land evidence (`doctrine dispatch verify`, CLI) |
| `reverify-stale` | the pass evidence no longer describes the tip — re-run the suite |
| `triage-verify-failure` | RED evidence — a judgment beat, no command; triage before anything else |
| `conclude` | land the phase boundary (`dispatch_conclude_phase`) |
| `reap` | remove the spent fork (`dispatch_reap`) |
| `all-reaped` | the phase funnel is done — hand off to `doctrine dispatch status --slice <N>` |

Parallel file-disjoint phases stay single-prescription: red evidence anywhere
triages first (the suite is coord-tree-global), an awaiting phase never
suppresses a runnable one, and the other in-flight phases are named in `detail`
at every rung.

See `lib:reference/dispatch-mechanics.md` §§ "Two altitudes" and "A refusal is
the recovery procedure".

### The batch-level beats

- **Verify's regression half.** At the verify beat also run `doctrine
  check regression diff --base "$B"` (suite @ S, the SAME normalised filter state
  as the capture). Exits non-zero on `new ∪ changed` (a slice regression
  regardless of which test binary/env it surfaces under) OR an unobtainable run
  (a compile error / panic / format change is a hard halt, never a silent green
  ∅). `persistent` (same key + same signature at B and S) is the tolerated env
  artifact; a non-empty baseline is surfaced as a trunk warning to fix, not
  laundered as "env". On halt the named `new`/`changed` keys ARE the offenders;
  nothing further needs isolating. (Carry-forward of the green current-set as
  `baseline-<B'>` is a deferred cost optimisation; steady state still re-captures.)
- **The import's prove gate.** `worktree import --from-worktree` is
  non-committing and runs the **reject-and-halt prove gate** in-process
  (`doctrine check prove` on the post-import tree): an unformatted OR lint-red
  delta halts the import per `lib:reference/dispatch-mechanics.md`
  (land-or-reject, never rewrite). A red here is
  a WORKER-delta defect, distinct from the pre-spawn BASE defect above.
- **The registry write.** After the code commit, `doctrine slice record-delta
  <SL> PHASE-NN --commit <S>` writes the commit-scoped `[S^,S]` row into the
  primary-tree conformance registry (the symmetric ledger derive is deferred —
  mechanics in `/dispatch-spawn`). Not a "remember to also record"
  hand-step: the Conclude beat's completeness gate halts if a landed phase is
  missing its row (below).
- **Per-phase review.** Between `import` and `conclude`, weigh a review of the
  landed delta per the code-review skill's `## Cadence`: default on below the
  adherence bar, mandatory on any tripwire (deleted tests, `Deviations: NONE`,
  waived/uncheckable VT, out-of-scope touch).
- **Knowledge** trails the confirmed commit, never precedes it.

**Report-and-halt** on conflict, moved HEAD, or authored-tree touch — never auto-resolve.

## Handover cadence
Hand over at a committed boundary: after `handover_after` batches (default 5) or
`handover_delta` cumulative reviewed-delta lines (default 2000), whichever first.

## Base freshness (mid-drive)
A long drive lets trunk advance under the coordination branch; the drift stays
invisible until `dispatch sync`/candidate-create conflicts on a merge-base
divergence — the most disruptive place to discover it. `dispatch status` surfaces
it (`trunk: moved (N commit(s) ahead of fork-point)`). When status shows movement,
run `dispatch refresh-base --slice <N>` — it merges current trunk into
`dispatch/<N>` in the live coordination worktree, advancing the base early and in
context so each conflict is one phase's delta. Conflicts there report-and-halt for
manual resolve in the coord tree — never auto-merged.

## Conclude
When all phases land, run the conclude cadence **in the coord tree, before it is
removed**: `slice verify-vt <id>` → on green
`dispatch sync --prepare-review` → remove coordination worktree directory (KEEP
the refs) → `slice status <id> audit` → `/audit` from parent/root. Stage-2
integrate is `/close`'s job, post-audit — never land code pre-audit.

`slice verify-vt <id>` is the **VT existence/shape gate**: it reads the coord
tree's `plan.toml` and checks every `VT`-mode criterion's mandated `test_file` +
`keywords`. A `Fail` exits non-zero and **HALTS handover** — do not prepare-review
past it; `/consult` → revise-or-waive the authored plan (never self-relax a
mandate), then re-run. `Uncheckable` / `Waived` are visible but non-halting. The
fs reader suffices here because the orchestrator (sole writer) has committed any
mid-dispatch waiver onto `dispatch/<slice>`, so the coord working tree == the
committed graph `prepare-review` projects.

**Embed at handover:** carry the `verify-vt` VT summary block **and** a
one-line regression status (lifted from the verify beat's `check regression
diff`) into the conclude output and the `/handover` packet — so a gap (incl.
`UNCHECKABLE` / `WAIVED`, rendered distinctly) is visible at handover, not at audit.

`prepare-review` is the **enforced** conformance beat: before projecting
refs it commits the boundaries ledger, **derives** registry rows from that committed
ledger (every ledger row is upserted into the primary registry — arm-neutral), then
runs a completeness **gate** that `bail!`s if any completed phase lacks a row. So
the registry is guaranteed complete by audit; a gap halts here (no refs created),
the operator commits the ledger / `record-delta`s the gap, and re-runs.

## Red Flags
IMPORTANT: READ VERY CLOSELY

**Never:** spawn without routing; let a worker write `.doctrine/`/`.claude/`;
expect a worker to commit (its `.git` is read-only — you import its working
tree); replay fork history; auto-merge conflicts; auto-adapt plan/
design (`/consult` forks); drive on session `main`; integrate at conclude; delete
deliverable refs; bail to inline execution; **work the landing state out of git
by hand — the order above is the order**; improvise a repair around a refusal
(its text IS the procedure); "heal" a missing funnel row (an unbound fork never
lands one).
! NEVER bail to inline execution - if you are about to `/execute`, STOP.
! NEVER use git like a drunk with a chainsaw - if you are about to do something potentially risky, STOP.
**Always:** spawn through `/dispatch-spawn`, whatever the harness; keep context
lean (capped reports, stat-first diffs); land each phase in the documented order
and finish one phase before starting the next; pre-distill self-contained worker
prompts; trail knowledge after the confirmed commit.
