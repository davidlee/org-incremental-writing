# REV REV-001 — reconcile SL-001

Revision — a pending revise-intent against authored governance/spec
truth. The structured `[[change]]` payload lives in the sister `revision-NNN.toml`;
this prose companion carries the rationale and the free-text before/after excerpts
for prose-body section edits.

## Rationale

<!-- Why this revision: what authored truth needs to change and why, the scope of
     the staged delta, and (for ADR/POL/STD/prose rows) the before/after excerpts
     the structured payload only labels. Seeded at `revision new`. -->

Reconciles SL-001's audit (RV-002) into governance. One row: POL-001
§ Verification names the gate SL-001 actually built. The Statement is
unchanged.

## Reconcile narrative

- [RV-002 finding F-27, design-wrong]: POL-001 § Verification named
  `make lint` / `make test` and a Makefile. SL-001 built a justfile
  instead (user direction 2026-09-30; SL-001 plan.md deltas). User
  assent to the amended text: "agreed" (session 2026-10-01).

Before:

> `make lint` and `make test` (with every supported Emacs) run before a
> phase is marked completed. The audit checks the evidence. The Makefile
> targets are established in SL-001.

After:

> `just lint` and `just test-all` (every supported Emacs) run before a
> phase is marked completed; `just gate` (`doctrine check gate`) runs
> both. The audit checks the evidence. The justfile recipes are
> established in SL-001.
