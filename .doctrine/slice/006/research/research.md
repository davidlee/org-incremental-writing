# SL-006 research — redistribution maintenance

**Producers:** two read-only subagents (Opus 5.5), 2026-10-06, at HEAD
ae1ba9f. Thread 1 covers governance; output in `raw/governance.md`.
Thread 2 maps the code; output in `raw/code-map.md`. The orchestrating
agent assembled this document and re-checked the rows marked ✓.
Baseline: `baseline.toml` (stamped by `doctrine slice research SL-006`).

**Legend:** ✓ = verified by the consuming agent by reading or grepping the
cited site. Unmarked = researcher claim: cited, not re-checked. Design
leans on ✓ rows only, or verifies at the point of use.

## Thread 1 — governance applicability

Full sweep in `raw/governance.md`. The binding core:

### Binding constraints

- ✓ **ADR-004** is the central authority. SL-006 was not linked to it;
  `governed_by` was added on 2026-10-06.
  - Rule 4: with no gap, the operation "stops before any change and says
    that redistribution is needed. It never renumbers silently".
  - Rule 5: "Renumbering a queue, including the pending placement,
    re-lays every member at the spacing, in order. It runs only after the
    user approves a previewed plan, and it follows REQ-019 and REQ-020 …
    It writes through the mutation layer's shared preflight and apply".
  - Rule 6: "redistribution plans are pure core functions over plain
    data … No other layer computes a rank."
- ✓ **REQ-019**, acceptance criteria:
  - "Cancelling applies neither redistribution nor the pending move."
  - "A plan whose source state changed after preview is rejected and a
    fresh plan is presented for approval."
  - "Unsaved edits in affected buffers must be resolved explicitly;
    approval never discards them."
  - "Unwritable targets are detected before any write."
  - "Redistribution preserves intended order including the pending move."
- ✓ **REQ-020**, acceptance criteria:
  - "A simulated write failure mid-plan produces a report partitioning
    affected files into saved/modified/untouched."
  - "Continue does not navigate onward after a failed redistribution."
- ✓ **REQ-010**: the operation "stops before any mutation and offers
  redistribution". Its acceptance criterion: "A move between adjacent
  ranks 5 and 6 makes no change and offers redistribution".
- **ADR-002**:
  - Writes go through visiting buffers. A clean buffer is saved; a dirty
    one is left unsaved.
  - "Multi-file work (batch add, redistribution) reports partial
    completion, and recovery is by Git".
  - Its verification requires a simulated write failure in multi-file
    tests.
- **ADR-003**: the plan is pure core. Every write guard lives in the
  write-layer preflight. Commands hold no ordering logic.
- **ADR-001, REQ-022, REQ-025**: no journal, no undo log and no
  persisted report. This matches the non-goals.
- **REQ-004, REQ-008, REQ-021, REQ-023, REQ-007, REQ-015**:
  - only `IW_<Q>` lines change;
  - re-laying keeps rank-then-ID order, ties included;
  - the save policy applies per file;
  - the arithmetic is exact integers;
  - excluded entries are not rewritten;
  - Continue retains its context on success.
- **PRD-001**:
  - § 3: "anything spanning files is previewed and approved".
  - § 4: "A blocked or cancelled operation leaves every file and buffer
    unchanged".
  - § 6 gives the normative redistribution/normalise flow: preview with
    counts, *browsable* affected files, the pending operation, unsaved
    and unwritable targets, non-atomicity, and Git first; resolve,
    approve or cancel; revalidate; apply and save; on failure, a
    partition report and no navigation.
- **POL-001..003; STD-001..004**:
  - STD-003 names redistribution for the scaled-up review roster.
  - STD-001: a self-tested "cancel changes nothing" oracle, and mutation
    over every new guard.
  - STD-004 item 4: every refusal goes through `org-iw-core-refuse`.
- **Decisions:**
  - DEC-003/027: one scan per operation, no cache.
  - DEC-004 vs DEC-026: keep or kill opened buffers. ✓ DEC-026's
    consequences say "SL-006 redistribution may reuse the same
    open-write-kill helper".
  - DEC-028: progress reporter, summary and report buffer.
  - DEC-005: the session.
  - DEC-011, DEC-012, DEC-013, DEC-019: the Continue, Move and view
    surfaces.
  - DEC-014: one preflight/apply pair.
  - DEC-022: document markers.
  - EVD-002: one fixed placement exhausts its gap "after 11 Continues",
    so the handoff will be hit in ordinary use.

### Checked — not applicable

See `raw/governance.md` § Checked — not applicable. In short:
- DEC-001/002/006/007/008/015/016/017/018/020/023..025;
- QUE-001/002 (both answered) and EVD-001;
- SL-005 is not a prerequisite;
- there are no open ASM, QUE or CON records on redistribution.

### Deferred-to-SL-006 promises

- Prior designs routed every no-gap here: SL-001 `design.md:213-214`;
  SL-002 `:173`, `:391-393` (I9, I10), `:410-415`; SL-003 `:622-633`,
  `:678-680`, `:808`; SL-004 `:443-444`.
- The temporary refusal text "redistribution is not yet available" is
  owned by ✓ `org-iw--refuse-no-room` (`org-iw.el:229-233`).
- Scheduled revisit: DEC-009 (default End vs Soon), "once SL-006
  lands" (SL-002 `:430`; SL-003 `:725`; PRD-001 OQ-3).

### Revision candidates (for design to weigh; none raised yet)

- **ADR-004 rule 5** is underspecified:
  - the start of the re-laid sequence (k·spacing from k = 1?);
  - whether members already at their target are rewritten;
  - how excluded memberships count;
  - "shared preflight and apply" against a per-entry apply that saves
    on every call (✓ `org-iw-write.el:111-127`).
- **REQ-019** leaves open what "resolve" unsaved edits means, and
  whether approval is possible with unwritable targets.
- **REQ-020** leaves the partition semantics implicit.
- **PRD-001 OQ-2** (keep or kill opened buffers) is unsettled for
  redistribution.
- **Stale once SL-006 lands:** DEC-012 and DEC-013's "refuse until
  SL-006", SL-002 I10 ("every rank comes from `rank-at`"), and the
  `--refuse-no-room` text.

## Thread 2 — code map

Full map in `raw/code-map.md`.

### Hotspots

- `org-iw-core.el` (243 lines): the new pure plan sits beside
  `org-iw-core-rank-at` and `-place`.
  - ✓ `no-gap` is produced only by `org-iw-core-place` (`:201,210`).
  - `org-iw-core-reorder` (`:212-217`) yields the order with the pending
    move applied.
- `org-iw-write.el` (227): writes are single-entry only.
  - ✓ `org-iw-write--apply` (`:111-127`) wraps one FN in
    `atomic-change-group` and saves the base buffer if it was clean, once
    per call.
  - Preflight is `--check-file` (`:63-76`: changed on disk, not writable,
    read-only) and `--check-entry` (`:78-88`: expected value, drawer).
    Both refuse on the first problem.
- `org-iw.el` (1530):
  - ✓ `no-gap` is consumed in exactly two places: `org-iw--add-entry`
    (`:478`) and `org-iw--move` (`:881`). Every surface reaches them:
    Add and labelled Add, batch add (caught as a failure), Move,
    Continue (`--continue-place` `:936-942`, refusing before
    `--visit`), view M-up/M-down and view place before/after.
  - The preview, handoff and normalise command go here.
- Tests asserting the old refusal text: `test/org-iw-test.el:175-189,
  2871, 2877` (`org-iw-cmd-test--no-room`).

### Reuse candidates and gaps

| Owner | Reuse | Gap |
|---|---|---|
| `org-iw-core-place` / `-reorder` | `(no-gap DEPTH)` is the trigger; `reorder` gives the target order | no pure re-lay or diff function (order → new ranks → changed set) |
| `org-iw-write--check-file` / `--check-entry` | whole-plan preflight before any edit | refuse on the first problem; the preview needs reason-returning predicates, with the refusers wrapping them (POL-002) |
| `org-iw-write--apply` | the was-clean / change-group / save policy | one marker and one save per call; no per-file grouped apply; no multi-file driver returning saved / modified / untouched |
| `org-iw--batch-outcome` (`org-iw.el:655`) | DEC-026 kill rule, `left-open` | per-file failure capture, whereas redistribution does preflight-all-then-apply; extract the kill rule |
| `org-iw--batch-report` / `-summary` / `--save-status` | the report and the "not atomic" text | hard-titled "Batch add to %s" (`:648`); generalise |
| ✓ `y-or-n-p` (`org-iw.el:1460`, the only prompt), `special-mode`, progress reporter | approve/cancel, preview buffer | nothing saves or reverts other buffers on request |
| `org-iw--entry-marker` → `discovery-resolve` | a marker per affected entry | opens buffers, so it needs a kill rule |

Test helpers to reuse:
- the corpus fixture;
- the prompt recorder (`y-or-n-p` :yes/:no; there is no `yes-or-no-p`
  recorder);
- save-failure injection through `write-file-functions`;
- `--diverting` with `--named-p`, to fail one named file;
- `set-modes`, to make a file unwritable;
- `rewrite-behind`, to change a file on disk for the recheck;
- `edit-elsewhere`, to leave unsaved edits;
- `test-state` with `--should-change-nothing`, for cancel;
- `--ranks`.

Missing: a multi-file "changed exactly these lines" oracle.
`--should-change-lines` (`test/org-iw-test.el:2557`) checks one file.

## Cross-thread findings

1. **Per-file apply vs ADR-004 rule 5.** Rule 5 says redistribution
   "writes through the mutation layer's shared preflight and apply".
   Today's apply saves once per entry (✓ `org-iw-write.el:111-127`).
   - Re-laying a queue with several members in one file would save that
     file once per member.
   - REQ-020 partitions by *file* (saved / modified / untouched), so a
     per-file apply is the natural unit.
   - Extending `--apply` to N entries per base buffer, with one change
     group and one save, keeps "shared apply" honest without a REV.
     Calling `put-rank` N times does not.
2. **Preflight must be collectable.** REQ-019 needs a preview that lists
   every unwritable and unsaved target. ADR-003 puts those guards in the
   write preflight, which today only refuses. One implementation (POL-002)
   means refactoring the preflight to return reasons, which the preview
   lists and the apply refuses on. The preview must not grow a parallel
   check.
3. **Two interception points, many surfaces.** All no-gap paths funnel
   through `--add-entry` and `--move` (✓). The handoff can therefore live
   in one place per path. Which surfaces hand off is a scope call:
   - SL-006 names "blocked moves and Continue", which covers Move,
     Continue and the view moves.
   - Add-at-placement and batch add at the limit are not named.
4. **Buffer lifetime.** The preview resolves markers, which visits files.
   DEC-004 (single-entry: keep) and DEC-026 (batch: kill clean opened
   buffers, and "SL-006 … may reuse") conflict. PRD-001 OQ-2 is open for
   redistribution. DEC-026's precedent points to "kill", reusing the rule
   extracted from `--batch-outcome`.
5. **"Resolve unsaved" vs "cancel changes nothing".**
   - PRD-001 § 4 says "A blocked or cancelled operation leaves every file
     and buffer unchanged", and an already-modified buffer is never saved
     without explicit resolution.
   - If resolution is a user save (or revert) before approval, a later
     Cancel leaves that save in place. That is defensible as the user's
     act, but no authority states it.
   - The simplest compliant reading: the preview lists dirty buffers,
     and approval is refused while any remains; the user resolves with
     normal Emacs tools and re-previews. org-iw then never saves or
     reverts on the user's behalf, and the apply only ever meets clean
     buffers.
6. **Recheck = fresh scan, compared.**
   - DEC-027 (one scan per operation) plus REQ-019 AC2 suggest the plan
     records the queue's (ID, file, rank) list from its scan.
   - Approval rescans and compares. Any difference means re-preview.
   - Per-entry `--check-entry` expected values (already compare-and-set,
     "IW_%s changed since scan") give a second, write-time guard.
7. **Failure semantics fit the existing outcome shapes.**
   - Per file: `saved`, `unsaved`/`left-open` (modified), and not reached
     (untouched). This maps onto `--save-status` and the batch outcome
     vocabulary.
   - Continue's no-navigate-on-failure needs `--move` to return a
     distinguishable result instead of the `--refuse-no-room` signal
     (✓ `org-iw.el:881`).
8. **Excluded entries.** REQ-007 says invalid ranks are "not rewritten"
   and duplicates get no writes. A queue with excluded members can still
   be re-laid over its valid members. Whether to refuse instead is a
   design decision ("surface, don't repair" argues for proceed-and-
   report).

## Design-input deltas

- The plan is a **pure core function**: target order (from `reorder` at
  the no-gap DEPTH, or the current order for normalise) → ranks
  k·1024 → the changed (entry . new-rank) set, entries already at their
  rank left out. Its literals are pinned (STD-001 item 4). One plan
  shape serves both the handoff and normalise.
- **Write layer:**
  - The preflight becomes reason-returning (preview) and refusing
    (apply), one implementation.
  - `--apply` generalises to one change group and one save per base
    buffer over several ranks.
  - A multi-file driver returns per-file outcomes. No third preflight
    (DEC-014).
- **Commands:**
  - The `no-gap` branches of `--add-entry` and `--move` hand off instead
    of refusing (scope: which surfaces).
  - A preview buffer (special-mode, DEC-028 style) and a `y-or-n-p`
    approve.
  - Recheck by rescanning, then apply.
  - The REQ-020 partition report reuses the generalised batch report.
  - An explicit `org-iw-normalise` command.
  - `--refuse-no-room`'s text changes.
- **Decisions to make in design:**
  1. the resolve-unsaved policy (finding 5);
  2. unwritable means approval is refused;
  3. buffer lifetime (finding 4; settle PRD-001 OQ-2);
  4. which surfaces hand off (finding 3);
  5. excluded entries (finding 8);
  6. the recheck criterion (finding 6);
  7. the preview UI form and "browsable files";
  8. Continue's reporting after the handoff (ISS-002 shape);
  9. the normalise target queue and the no-op case;
  10. the DEC-009 revisit.
- **Governance likely touched at reconcile:**
  - ADR-004 rule 5 (sequence start; per-file apply);
  - REQ-019 (resolve and unwritable semantics);
  - PRD-001 OQ-2/OQ-3;
  - DEC-012/013 consequences;
  - SL-002 I10's wording.
- **Size signal for the scope question.** Core is small (one function).
  Write is moderate (a preflight refactor plus a grouped apply). Commands
  carry the bulk: preview, resolve, recheck, report, handoff on 4–6
  surfaces, and normalise. The natural split, if design finds it
  unwieldy: (a) plan + grouped apply + normalise + partition report;
  (b) handoff from the blocked surfaces.
