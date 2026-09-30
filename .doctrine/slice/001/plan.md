# Implementation Plan SL-001: Walking skeleton

Prose companion to `plan.toml`. Narrative only — no queried data lives here
(the storage rule); the phase list, criteria, verification, and links are
authored in the TOML. Use this for the plan's rationale and sequencing.
<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

## Overview

Eight phases, built bottom-up along ADR-003's dependency direction: gate,
core, discovery (two phases), write, commands (two phases), then the
two-version gate and human trial. Each phase leaves the tree green under
the POL-001 gate, so any phase boundary is a safe stopping point and a
clean hand-off for a dispatch worker.

The canonical reference is `design.md` (locked, run rev 38). Criteria cite
its sections rather than restating them; a worker reads the design section
the criterion names.

## Sequencing & Rationale

- **PHASE-01 first, and gated on the user.** The gate must exist before the
  first red test, and must be shown to reject known-bad input (RV-001 F-10)
  before anything relies on it. The jail has no `just` (nor `make`) and no
  `emacs-30`; nothing can be verified in-jail until the user rebuilds the
  dev shell. That rebuild is PHASE-01's VH-1 and a hard gate on PHASE-02.
  The `org-iw.el` skeleton (header + defcustoms) lands here because
  package-lint needs its main file, and the corpus fixture later binds
  `org-iw-sources`.
- **Core before discovery.** Pure, fastest to TDD, and every other layer
  consumes its records and rules (DEC-001).
- **Discovery split in two.** PHASE-03 (file selection + scan + problems +
  fixture) is the largest and riskiest logic — the raw IW-line reader and
  block-skip rule are named residual probe targets. PHASE-04 (id-count +
  resolve) is small but is the sole resolution owner and carries a blocker
  (F-1); isolating it keeps that probe's evidence clean. The ID-line
  definition is shared between the scan tally and id-count (one owner).
- **The fixture lands with its first user** (PHASE-03), not in PHASE-01
  (POL-003: no infrastructure ahead of need).
- **Write before commands.** put-rank is the one write path (F-11); both
  Add and Continue call it.
- **Add before Continue.** Add is trial-able alone and exercises put-rank
  with `:ensure-id`; Continue then adds session, visit and the § 5.4
  sequence on top of an existing write path.
- **PHASE-08 closes the gates** that need the rebuilt shell and the human:
  `just test-all` on 30.2 and 31.1, and the § 9 human trial.

### Routed RV-001 findings

Each instrument-routed finding (`doctrine review show RV-001`) is
transcribed onto the earliest phase meeting its placement constraint, cited
inline in the criterion text. Two findings split by the constraint's two
halves:

- F-10 control → PHASE-01/EX-6
- F-6 control → PHASE-03/EX-5
- F-3 probe → PHASE-03/EX-6 (unit), PHASE-07/EX-4 (command)
- F-5 demonstrate → PHASE-03/EX-7 (symlink), PHASE-06/EX-4 (indirect Add)
- F-1 probe → PHASE-04/EX-3 (resolve), PHASE-07/EX-5 (Continue writes nothing)
- F-4 control → PHASE-05/EX-3
- F-2 control → PHASE-06/EX-3

The raiser verifies each after `slice phases` (transcription, not repair).

## Notes

### Deltas from the locked design (reconcile at /reconcile)

- **justfile instead of Makefile** (user direction, 2026-09-30). Design
  § 9 Tooling and § 10 Code Impact, and the slice scope's Tooling bullet,
  name a `Makefile`; the recipes map one-to-one. The user adds `just` to
  the flake's `projectPkgs`; the agent adds the Emacs 30 input and wrapper
  (DEC-006). Not reopened at design: a runner swap changes no design
  content.
- **Every phase gates on `just test-all`**, not only PHASE-08: the rebuilt
  shell has `emacs-30` in-jail (30.2 ships Org 9.7.11 vs 9.8.10 on 31.1; the
  research probes ran on 9.8.10 only), so Org-version drift surfaces in the
  phase that introduces it.
- **Flake input name** is `nixpkgs-stable` (user), not DEC-006's
  `nixpkgs-emacs30`; same pin (nixos-26.05).
- **`clean` recipe** is kept from the slice scope although design § 9 omits
  it (no `.elc` should ever land in the tree); it removes stray `*.elc`.

### Test-naming for VT mandates

VT keywords are the API symbols and user-visible message strings the tests
must exercise, not ERT test names — so workers keep freedom to name tests
by behaviour while the gate still has signal.
