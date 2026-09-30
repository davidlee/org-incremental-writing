---
name: close
description: Use to formally close a slice once its phases are complete, audited, and reconciled — confirm the rollup, verify spec-coherence, harvest durable findings, reconcile lifecycle status, and land a clean final commit. Routed to from /reconcile.
---

# Close

You are executing formal closure, not just marking work done.

Inputs:

- completed, audited, reconciled implementation phases
- the reconciliation review (RV) with every finding terminal and the
  `## Reconciliation Outcome` recorded (see `/reconcile`)
- the governing slice id

## Process

1. **Pre-check:**
   - Phase exit criteria (`EX-`) and verification (`VT-`) are met. Confirm the
     rollup: `doctrine slice list` should show the slice as `X/X complete` with
     no `!N` blocked, no `?N` anomalous, no `—` untracked.
   - `/reconcile` is done (via `/audit → /reconcile`): the RV ledger is resolved,
     every governance/spec finding is dispositioned, and the RV carries a
     `## Reconciliation Outcome` section. If the reconciliation brief was empty
     (no-op), the outcome confirms that explicitly.
   - Durable findings from the slice are harvested per
     `lib:reference/harvest.md` before
     closure — or **consciously rejected**. A clean slice may harvest nothing;
     the conscious-rejection gate is what closure checks.
   - `doctrine check gate` is green.
2. **Spec-coherence gate — confirm reconciliation is complete before `done`:**
   Before the terminal transition, verify every item from the audit's
   reconciliation brief is resolved through one of four paths:
   * **REV done** — governance/spec items covered by a `done` REV
     (`revision status REV-N done`). The REV rationale (`revision-NNN.md`)
     carries the reconcile narrative.
   * **Withdrawn** — finding withdrawn in the RV with rationale.
   * **Tolerated** — finding tolerated in the RV with rationale.
   * **Escalated to design** — slice transitioned back to `design` via the
     design back-edge (`reconcile → design`).
   Additionally:
   * Every per-slice direct-edit item is applied to `design.md` /
     `slice-NNN.md` and recorded in the `## Reconciliation Outcome`.
   * The RV ledger is resolved (`done · await=none`): every finding terminal
     **and** the pass concluded (`review conclude RV-NNN --basis …`). A ledger
     whose findings are all terminal — a zero-finding ledger included — reads
     `active · await=raiser` until the raiser concludes it; conclude it, do not
     raise a token finding. The absence of unresolved blockers is what gates the
     transition, never the status string (a display summary, never a gate).
   * The reconcile outcome is recorded (REV rationale and/or RV
     `## Reconciliation Outcome`).
   No free-floating "rejected" disposition is permitted — every finding
   must land in one of the terminal states above.
   If any item is unresolved, **refuse close** and return to `/reconcile`.
   (The structural closure seam is the mechanical backstop; this gate is the
   substantive check — the verb enforces; the skill verifies.)
3. **Commit cleanly:** land `.doctrine/**` workflow artefacts in small, clean
   conventional commits scoped with the slice id, rather than letting them
   accumulate. Code and workflow edits go together or separately, whichever
   commits cleanly first.
   > **Stage the slug symlink.** `*/new` verbs lay out `<kind>/NNN/` **and** a
   > sibling slug symlink `<kind>/NNN-slug -> NNN` (slice, review, revision, rec, …).
   > A path-scoped `git add <kind>/NNN/` stages the dir but misses the symlink,
   > stranding it uncommitted. Stage both — `git add <kind>/NNN*` — or add the
   > symlink explicitly. Check `git status` for a dangling `NNN-slug` before the
   > final commit.
3a. **Dispatched slice — integrate the admitted OID (post-audit only).** If the
   slice was driven by `/dispatch`, project the audited units now:

   ```bash
   # 0. Resolve the trunk delivery ref once (config-driven; default refs/heads/main):
   trunk=$(doctrine dispatch deliver-to)

   # 1. Admit a close_target candidate (if not already done during /reconcile):
   doctrine dispatch candidate create --slice <N> --label close-001 \
     --role close_target --payload code --base "$trunk" \
     --source refs/heads/review/<N>
   doctrine dispatch candidate admit --slice <N> --role close_target \
     --candidate refs/heads/candidate/<N>/close-001 --review RV-NNN

   # 2. Project onto trunk (--trunk is REQUIRED; omitting it is a dry run):
   doctrine dispatch sync --slice <N> --integrate --trunk "$trunk"
   ```

   When a candidate workflow is active this targets the immutable **admitted
   `close_target` OID** (and `--edge` the admitted `review_surface` OID) under a
   fast-forward-only CAS row — **never a raw `phase/*`/`review/*` tip or the
   mutable candidate ref**, and never a close-time merge. A moved trunk refuses
   (admit a superseding close-target candidate on the new base). This is the
   **only** place `--integrate` runs — never at `/dispatch` conclude, only here,
   post-audit.

   **Verify (tree-true).** After `--integrate --trunk`, both checks
   below must pass — do **not** proceed to step 4 unless they do:
   ```bash
   # (a) No phantom reverse-diff: the tracked working tree matches HEAD. A nonzero
   #     exit means integrate advanced the ref but desynced the live checkout — STOP.
   git diff --quiet HEAD

   # (b) The projected delta genuinely landed (not a silent dry-run): the committed
   #     journal's trunk row holds the planned tip; it must equal the trunk ref.
   trunk=$(doctrine dispatch deliver-to)
   planned=$(doctrine dispatch sync --slice <N> --show-journal-trunk-oid \
     --trunk "$trunk")
   git diff --quiet "$planned" "$trunk"
   ```
   (a) is the phantom-reverse-diff detector — the **whole tracked tree**, not
   path-limited (a phantom reverse-diff can span any file the slice projected,
   not just `src/`).
   (b) reads the trunk row's `planned_new_oid` from the committed `dispatch/<N>`
   journal — a tree-read, stable from this checkout — and diffs it against
   the resolved trunk delivery ref (`doctrine dispatch deliver-to`, default
   `refs/heads/main`); a difference means trunk does not hold the projected tip, so
   integration did not land.

3b. **Split lineage — the payload reached trunk out-of-band
   (`--record-integration`).** See `lib:reference/dispatch-mechanics.md` §
   Split lineage — record an already-landed payload, don't advance trunk.
   The close gate still refuses `done` ("dispatched but no
   trunk row"). Record the earned row instead of hand-editing `journal.toml`:

   ```bash
   trunk=$(doctrine dispatch deliver-to)
   doctrine dispatch sync --slice <N> --record-integration --trunk "$trunk"
   ```

   Per `lib:reference/dispatch-mechanics.md` § Split lineage,
   `--record-integration` asserts the payload is already an ancestor of trunk
   and commits a single Verified trunk row. Then `slice status <N> done` reads
   that row and passes. This is the
   sanctioned replacement for a hand-written journal row; land the payload
   out-of-band as `git merge --no-ff phase/<N>-NN` (or
   the admitted candidate), not `review/<N>`.

4. **Transition lifecycle:** confirm the slice is in `reconcile` (flip it with
   `doctrine slice status <id> reconcile` if `/audit` didn't), then
   `doctrine slice status <id> done` (`<id>` is the bare number, e.g. `40`).
   The closure seam enforces the order and refuses while an RV targeting the
   slice carries an unresolved blocker. Re-run `doctrine slice list` and confirm
   the `⚠` divergence marker is gone — authored status now agrees with the
   rollup. (The terminal set is `{done, abandoned}`; closure here is the `done`
   path — abandoning a slice is a separate decision, not this skill.)
5. **Close the originating backlog item:** if a backlog item (ISS/IMP/CHR/RSK)
   spawned this slice, transition it too — `doctrine backlog edit <ID>
   --status resolved --resolution fixed` (or the resolution that fits). A closed
   slice with its origin still open is hygiene debt.
6. If a blocking finding remains unresolved, do **not** close — return to
   `/reconcile`. If closure depends on tolerated drift with material
   tradeoffs, `/consult` before normalising around it.

### Drift discharge recipe

When `slice status <id> done` refuses with *undischarged residual drift*, each
flagged requirement needs an `accept` REC **owned by the closing slice** that
satisfies all three clauses:

- **(a)** `move = accept` — an affirm, not `revise`/`redesign`.
- **(b)** a `[[status_delta]]` naming the requirement whose `to` equals its
  current authored status (the status the refusal prints).
- **(c)** the REC's `[[evidence_ref]]` set ⊇ every distinct coverage key feeding
  that requirement's composite, so fresh contradictory evidence cannot be excused
  by a stale REC.

Author it, then hand-edit the two tables:

```bash
doctrine rec new --move accept --owning-slice SL-NNN --title "accept REQ-NNN"
# then hand-author the [[status_delta]] and [[evidence_ref]] tables
```

Full predicate, rationale, and a worked example:
`doctrine memory show mem.pattern.doctrine.close-drift-discharge-rec`.

## Outcomes

- The slice is `done`, with the rollup in agreement.
- The originating backlog item (if any) is resolved.
- Durable guidance is captured in memory or consciously rejected.
- The tree is clean and the workflow artefacts are committed.
