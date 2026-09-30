# Notes SL-001: Walking skeleton

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Design triage (2026-09-30, exploring)

Constraining governance: ADR-001 (entry-resident state), ADR-002 (buffer-
mediated writes, save policy, single writer), ADR-003 (four layers), POL-001
(lint/test gate), POL-002 (one implementation per concept), POL-003 (human
trial), PRD-001 § 4 constraints. Evidence: `research/research.md` (T2-*, X1-X5).

Shaping decisions carried in from research:
- Discovery rescans every operation with a raw-text `:IW_` prefilter; no
  index (research X1; settles PRD-001 OQ-1 provisionally, revisit SL-004).
- Tests isolate `org-id-locations-file` (T2-7).
- Makefile parameterised by `EMACS=`; Emacs 30 run verified by the user (T2-10).

Open design questions: tracked as `inq-*` nodes in the design run
(`doctrine design show --format prompt SL-001`).

Risks:
- Emacs 30 compatibility unverifiable in the agent jail (T2-10).
- `org-id-get-create` side effects on the user's global id locations in real
  use are expected and fine; only tests must isolate.
- Doc-level entries appear in discovery reads via `point-min` but are not
  targeted in SL-001; keep the read path uniform so SL-004 adds no parallel
  reader (POL-002).

Assumptions:
- Configured sources are few enough that a synchronous rescan is imperceptible
  (measured 10 ms prefilter / 112 files).

## Design review (2026-09-30)

RV-001 (`doctrine review show RV-001`): adversarial agent pass, 4 rounds, 24
findings, all fix-now and verified by the raiser. Further pass: none needed
before planning. Residual probe targets for implementation (tests carry them):
the raw IW-line reader and block-skip rule (§ 5.4 step 4), `resolve` under
narrowing/indirect buffers, and put-rank's atomic/save-failed paths — all of
which are cheaper to prove by the § 9 tests than by more design review.

## Design lock (2026-09-30)

Locked at run rev 38 on the user's "accept and lock" (all 14 sections
attested; RV-001 disposed `conducted`). The user accepted knowingly over the
pass's 2 blockers / 8 majors (all repaired in prose); a code review follows
implementation. The lock required a route on every severe finding, so they
were backfilled (reopen → re-dispose): F-9, F-11 `review` (verified);
F-1, F-3 `probe`; F-2, F-4, F-6, F-10 `control`; F-5 `demonstrate`. The
seven instrument-routed findings stay `answered` — `/plan` must transcribe
each one's criterion sketch and host-phase constraint (on the RV) onto a
phase criterion; the raiser verifies after `slice phases`.
DEC-001..006 accepted. Slice → plan.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-09-30 · design/locked (run rev 38) → plan · 2ee8aa5 (design artefacts uncommitted)

### Produced
- design.md (materialised, run dr-01a0f222…); DEC-001..DEC-006 (accepted)
- RV-001 (24 findings; 7 instrument-routed answered, rest verified; re-concluded)
- research/research.md (+ raw/), T2-1..T2-12; DEC-003 evidence corrected (F-19)

### Learned
- Org API sharp edges recorded in design.md § 3 (org-find-entry-with-id, org-entry-properties upcasing, lock files, indirect buffers, shared byte-compile masking) — candidates for /record-memory at close
- No Linux Emacs 30 in nixos-unstable / emacs-overlay; nixos-26.05 has 30.2 (research T2-11)

### Open
- /plan: transcribe RV-001 F-1..F-6, F-10 instrument criteria onto phases; raiser verifies after `slice phases`
- Post-implementation /code-review (user intent)
- flake.nix Emacs 30 change + `make test-all` need the user (no nix in jail)
