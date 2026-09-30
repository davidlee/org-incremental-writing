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

## Plan (2026-09-30)

8 phases (`plan.toml`; rationale and design deltas in `plan.md`). Planning
found the jail has no `make`; user chose a justfile and added `just` to
the flake — the Makefile→justfile swap is a recorded delta to reconcile into
design § 9/§ 10 and slice scope. PHASE-01/VH-1 is a hard gate: the user
rebuilds the dev shell (just + emacs-30) before the gate can run in-jail.
RV-001 instrument findings transcribed and verified (transcription only);
RV-001 now fully verified. verify-vt: all 23 mandates checkable (FAIL =
files not yet written). Slice → ready.

## PHASE-01 (2026-10-01) — completed, 405af23

Gate landed as a justfile (lint = compile + checkdoc + package-lint +
relint on Emacs 31; test-all on 31.1 and 30.2; `check` / `gate` recipes for
`doctrine check`). RV-001 F-10 controls observed: all four candidates fail
`just lint`; a shared-process compile masks the sibling-require fault, the
per-file compile catches it. Gotcha: package-lint in batch needs
`(require 'compile)` first or prints an autoload error (harmless).
Licence: GPL-3.0-or-later (user, LICENSE.md; headers 31e311c). URL header confirmed against origin (davidlee/org-incremental-writing).

## PHASE-02 (2026-10-01) — completed, 72d1071

org-iw-core landed, 11 tests; gate green on Emacs 31.1 and 30.2. I6 child-
Emacs test shown red with a temporary `(require 'org)`. Design delta for
/reconcile: § 5.2 `org-iw-core-append-rank` takes `(ORDERED QUEUE)`.

## PHASE-03 (2026-10-01) — completed, 82c3bd2

org-iw-discovery (files + scan) and the corpus fixture
(test/org-iw-test-helpers.el); 33 new tests (44 total), gate green on both
Emacs; discovery coverage 99%. Gap rulings: an entry with no surviving
membership is not emitted; `duplicate-id` per in-file-skipped entry plus one
per cross-entry shared ID; `IW_<Q>+` alone is `invalid-property`, with
`IW_<Q>` a `duplicate-property`; missing sources skipped; exclude regexp
case-sensitive. The ID-line owner (`org-iw-discovery--id-values`) exists for
PHASE-04's id-count. Worker choices: a live buffer's widened text is copied
into the temp buffer (one read path; the user's buffer untouched; non-Org-mode
live buffers work); inaccessible subdirectories are skipped. Org 9.7.11 and
9.8.10 agree on block lineage, `org-at-property-p` and document drawers.
Gotchas: a dangling lock symlink is already dropped by the regular-file
filter, so the `.#` rule needs a regular `.#` file to test;
`set-buffer-modified-p nil` alone releases a lock file. Deltas for /reconcile:
`org-iw-scan-create` constructor; fixture FILES is an evaluated form.

## PHASE-04 (2026-10-01) — completed, uncommitted at worker hand-back

`org-iw-discovery-buffer`, `-id-count`, `-resolve` added to
org-iw-discovery.el; 9 new tests (53 total), gate green on both Emacs.
Rulings: `id-count` (no buffer argument) works on
`(or (buffer-base-buffer) (current-buffer))`, widened, so a narrowed
indirect buffer still counts the whole base; `resolve` calls it inside
`(with-current-buffer (org-iw-discovery-buffer FILE) ...)`. POL-002: the
PHASE-03 owner became `org-iw-discovery--id-lines` returning
`((VALUE . LINE-START) ...)`; `--id-values` (scan tally) is its `mapcar
#'car`, `--id-positions` (count and resolve) filters it — one matcher. The
scan-excluded check is by ID only (a cross-file duplicate names just the first
file, so a file check would let the second file's entry through); refusal
wording differs per cause (duplicate / not found / ambiguous) and always
names ID and file. F-1 probe: holds for a same-file copy without and with
another membership, lowercase `:id:` key, case-variant value, a copy hidden by
narrowing, and via an indirect buffer. Copies present at scan time surface as
"duplicate"; copies added after the scan (test inserts them into the visiting
buffer) exercise the "ambiguous" path. The indirect-buffer claim of design § 3
holds on Emacs 30 and 31: `buffer-file-name` is nil and `find-buffer-visiting`
returns the base. `org-back-to-heading-or-point-min` is passed `t`
(invisible-ok) so a folded heading cannot fail the lookup. No design delta.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-10-01 · started · PHASE-01 completed; PHASE-02 next · 4eae0e7

### Produced
- design.md (materialised, run dr-01a0f222…); DEC-001..DEC-006 (accepted)
- RV-001 (24 findings, all verified; instrument ones as transcriptions)
- plan.toml / plan.md (8 phases); phase sheets materialised
- research/research.md (+ raw/), T2-1..T2-12; DEC-003 evidence corrected (F-19)

### Learned
- Org API sharp edges recorded in design.md § 3 (org-find-entry-with-id, org-entry-properties upcasing, lock files, indirect buffers, shared byte-compile masking) — candidates for /record-memory at close
- No Linux Emacs 30 in nixos-unstable / emacs-overlay; nixos-26.05 has 30.2 (research T2-11)

### Open
- PHASE-02..08 via /capsule-driver (agents in .claude/agents/, spawn depth 2 in settings); PHASE-08 VH-1 human trial is the user's
- /reconcile: Makefile→justfile, `clean` recipe (plan.md § Deltas)
- Post-implementation /code-review (user intent)
- `just test-all` on 30.2 needs the rebuilt shell (PHASE-08)
