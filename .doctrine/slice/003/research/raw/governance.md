<!-- Verbatim Thread 1 output, read-only general-purpose subagent, 2026-10-03. Researcher claims; see ../research.md for verified rows. -->
## Thread 1 — governance applicability

### Binding constraints

| authority (durable id) | constraint as it bears on SL-003 | design consequence |
|---|---|---|
| ADR-001 | Queue state = `IW_<Q>` on the entry; views always derived from sources; any in-memory copy disposable. | The view's row list is a display copy, never authoritative; every view action must rescan (DEC-003) and write against scanned rank. Refresh = rescan. No persisted view state (REQ-025). |
| ADR-002 | Writes go through visiting buffers, save policy; single-entry ops rely on buffer undo; one active Emacs writer, no transactions. | Move/remove reuse `org-iw-write--apply` (org-iw-write.el:81-97): clean buffer → saved, dirty → `unsaved` reported. Undo via ordinary buffer undo; no undo log. |
| ADR-003 (+REV-002 amendment) | Four layers; mutation "sets **or removes** one property"; every write guard lives in mutation preflight; every reader of Org structure lives in discovery behind public functions; commands own only their own preconditions. | Remove needs a mutation-layer entry point sharing `org-iw-write--preflight` (org-iw-write.el:59-79). Outline/file context and "memberships of entry at point" are discovery readers. View + keymap live in the command layer (org-iw.el); holds no ordering logic. |
| ADR-004 | Only core computes ranks; allocation writes one entry; no-op writes nothing; no gap → stop before any change. | Up/down/before/after/move all go through `org-iw-core-place` + `org-iw-core-reorder` (org-iw-core.el:191, :210). Up at front / down at end are `unchanged`. No-gap refuses (no redistribution, SL-006). |
| POL-001 | Lint clean, ERT on Emacs 30+31, TDD incl. refactor. | Gate: `just lint`, `just test-all`. |
| POL-002 | One implementation per concept incl. message contracts and test helpers; replaced code deleted same change. | Reuse `org-iw--visit` (open-from-view = visit), `org-iw--read-queue` (queue completion), `org-iw--refuse-no-room`, `org-iw--save-status`, `org-iw--put-rank`, `org-iw--refuse-absent`, the prompt recorder `org-iw-cmd-test--with-prompt` (test/org-iw-test.el:66). A second write path or second resolver = blocking. |
| POL-003 | VH trial required; slice not closeable without it. | VH trial already named in SL-003: inspect, reorder, remove, undo in source, refresh. |
| STD-001 | Independent tests; self-tested oracles; every guard mutation-killed; literals pinned; buffer readers tested in context fixtures; prefer public entry points. | New outline-context reader needs nesting/narrowing/indirect/dirty/non-Org fixtures (item 5). Every new refusal (empty view, no entry at point, ambiguous queue, not a member) needs a killing test (item 3). `just test-each`. |
| STD-002 | VT keywords name `ert-deftest`s or code symbols, never message text; `test_file` must contain tests. | Plan rule; view message wording must not key VTs (mem.pattern.doctrine.vt-keywords-match-prose). |
| STD-003 (default) | Two-reviewer pre-close roster; scale up for high-stakes slices — explicitly includes the write path. | Adding a delete to org-iw-write.el triggers scale-up: add legibility reviewer + opus verifier or justify in audit brief. |
| STD-004 | One file per layer; `--` names file-private; every refusal via `org-iw-core-refuse`; primitives first; tests on real temp Org files via the shared fixture. | View stays in org-iw.el (new `org-iw-view.el` breaches item 1 and DEC-001). Any discovery helper commands need is public. Use built-in `tabulated-list-mode` (no dep, REQ-024). |
| REQ-001 | Absence of `IW_<Q>` = non-membership. | Remove = delete that property line; nothing else marks removal. |
| REQ-002 | Document and heading entries share one ordering. | View must render document entries (discovery already scans them, org-iw-discovery.el:138, :201). Source-entry commands for documents → see OQ 7. |
| REQ-003 | Queue IDs canonicalised. | Prompts go through `org-iw--queue-id` (org-iw.el:180). |
| REQ-004 | Write leaves other IW, `IW_AFTER_`, non-IW properties byte-identical; never deletes content or changes TODO. | Remove deletes one line. Note `org-entry-delete` also deletes `IW_<Q>+` lines and an emptied drawer (org 9.8.10 org.el:13431-13450); preflight already refuses accumulated keys; members carry an ID so the drawer survives in practice. Byte-level preservation test. |
| REQ-005 | Only configured sources read/written. | Source-entry commands refuse outside sources (reuse `org-iw--source-file-p`, org-iw.el:155). |
| REQ-006 | Live buffer authoritative over disk. | View refresh reads live buffers incl. after undo. |
| REQ-007 | Unresolvable/duplicate targets diagnosed, never written/recreated. | View actions on a row that vanished/duplicated refuse (reuse `org-iw--refuse-absent` pattern). Full diagnostics = SL-005. |
| REQ-008 | Order = rank then ID; ordinals 1..N regardless of rank. | View shows derived ordinals, not ranks (brief l.40 "Stored ranks need not dominate"). |
| REQ-009 / REQ-010 | Placement forms; one-line writes; no-op writes nothing; no gap → stop. | Every view/source move maps to a placement passed to `org-iw-core-place`. Tests: one changed line; no-op leaves file unmodified; no-gap unchanged. |
| REQ-013 | Queue chosen by completion; ordinal, title, file/outline context; open / up/down / place before/after / remove / refresh. ACs: every configured+discovered queue offered; same-title entries distinguishable; refresh reflects undo; open = Visit-next session. | `org-iw--read-queue` already satisfies AC1. AC2 needs data the scan doesn't produce: `org-iw-entry` has only id/title/file/memberships (org-iw-core.el:48-54). AC4: reuse `org-iw--visit` (org-iw.el:453). |
| REQ-014 | Visit changes no queue state; session retained and visible. | Open-from-view must not write; session via `org-iw--session-start` only (org-iw.el:309-312, DEC-005). |
| REQ-015 | Continue acts on retained entry; removed target reported, not recreated, no navigation. | Removing the session entry (view/source) → next Continue hits "no longer in queue" refusal (already tested path). |
| REQ-016 / DEC-008 / DEC-009 | Per-queue vocabulary; standard Soon/Later/End. | Source-entry move may read the vocabulary (`org-iw--read-placement`, org-iw.el:267). Remove-in-chooser interacts with label validation (`org-iw--check-placements`, :214). |
| REQ-017 | Move from view or source entry; ask queue when ambiguous outside a session; only that rank changes. | Queue-disambiguation prompt only when no session and >1 membership at point. |
| REQ-018 | Remove deletes only the selected property; distinct from Continue; Remove-in-chooser doesn't reinsert. | New delete write + Continue-chooser integration (DEC-011 consequence). |
| REQ-021 | Save policy; unsaved report. | Remove reports via `org-iw--save-status`. |
| REQ-022 | Single-entry ops undoable; views reflect undo on refresh. | Test: move/remove → `undo` in source buffer → refresh → previous order. No undo log. |
| REQ-023 | Exact integer ranks. | Inherited via core; no new arithmetic. |
| REQ-024 | Emacs 30.1+, bundled Org, no runtime deps, tested 30+31. | `tabulated-list-mode` is built in. Avoid 31-only APIs (mem.fact.emacs.completion-table-with-metadata-31-only). |
| REQ-025 | No auxiliary files/logs/indexes. | View keeps no persistent state. |
| PRD-001 §3 | "Visiting is not consuming"; "Surface, don't repair". | Open-from-view never writes; stale/ambiguous rows refuse. |
| PRD-001 §4 invariants | Op on queue A never alters others; ≤1 rank write; blocked/cancelled op changes nothing; modified buffer never saved; deterministic order. | Assert these for move, up/down, before/after, remove, incl. cancel of a queue/entry prompt (C-g → no change). |
| PRD-001 §6 Inspect / Move-remove / Continue | Empty queue → "reported empty"; remove "deletes only that property"; Continue lists "Remove as a distinct action" among alternatives. | Empty view reuses `org-iw--report-empty` (org-iw.el:474). Remove joins the chooser. |
| DEC-001 | One file per layer; finer split premature. | No separate view file (org-iw.el is 615 lines). |
| DEC-003 | Every operation rescans; no cache. | Each view action and refresh rescans; actions must not trust row data for the write beyond `:expected`. |
| DEC-004 | Buffers opened only to write stay open. | Applies to remove/move unchanged. |
| DEC-005 | One global in-memory session, set by visit/continue/**opening from a view**; cleared only by `org-iw-end-session`. | Open-from-view sets it (decision already anticipates). Remove clearing the session would contradict "cleared only by" → OQ 6. |
| DEC-006 | Emacs 30 test binary. | Tests both versions. |
| DEC-007 | Placements `(after N)`/`(fraction …)`/`(percent P)`/`end`; front = `(after 0)`. | Up/down/before/after expressible as `(after k)` over the order without the target. Whether commands may compute k → OQ 2. |
| DEC-010 | Spacing 1024. | Repeated "before X" halves the same gap (EVD-002: ~11 uses); expect no-room refusals from view reordering pre-SL-006. |
| DEC-011 | `completing-read` chooser over labels; consequence: "Remove joins the chooser only when SL-003 provides it". | SL-003 owns the chooser change → OQ 3. |
| SL-002 design I10 (.doctrine/slice/002/design.md:393) | "No other function computes a rank, a depth or a neighbour" outside `rank-at`/`place`. | Mapping "before entry X" / "up" to a depth in the command layer arguably violates I10 → OQ 2. |

### Checked, not applicable

| authority | reason not applicable |
|---|---|
| REQ-011 (Add) | Enrolment unchanged; only reuse the target-resolution helper `org-iw--add-target` for source-entry commands. |
| REQ-012 (Batch add) | SL-004. |
| REQ-019 / REQ-020 (redistribution) | SL-006 (SL-003 non-goal); SL-003 only refuses via `org-iw--refuse-no-room`. |
| DEC-002 (config shape) | No new `org-iw-queues` key needed unless OQ 3 adds a configurable Remove label. |
| DEC-009 default End (revisit) | Revisit tied to SL-006, not SL-003. |
| EVD-001 | RFC-001 delivery evidence, no constraint here. |
| QUE-001 / IMP-002 | One-scan-per-command fix deferred to SL-004; SL-003 should not regress it further but doesn't own it. |
| IMP-001 (public session string) | Display API, unrelated to view. |
| IMP-004 (bad config keys) | Load-time diagnostics; SL-003 only validates on use like SL-002. |
| CHR-001 / CHR-002 | Tooling chores; SL-003 uses the RV-002 mutation harness / review until they land (STD-001, STD-004 verification). |
| PRD-001 OQ-1 / OQ-2 | Scan cost / buffer lifetime — SL-004; only relevant if outline context adds per-entry cost (OQ 4). |
| PRD-001 OQ-4 | Session display settled by DEC-005/IMP-001. |
| REV-001 / REV-002 / REV-003 | Done; effects folded into POL-001, ADR-003/POL-002, PRD-001 above. |

### Open questions / tensions surfaced by governance

1. **What does "move from source entry" place with?** REQ-017 says only "change one membership's position"; PRD-001 §6 gives no form. Options: (a) reuse the queue vocabulary via `org-iw--read-placement` (REQ-016, DEC-008, DEC-011 surface) — cheapest under POL-002; (b) explicit position/ordinal; (c) "before/after a chosen entry" completing-read over the queue. (a) makes "move" = Continue-without-navigation, coherent with SL-002 design §4 claim that SL-003's move calls `place` (design.md:92). Design should record a DEC.
2. **Who computes the depth for up/down/before/after?** SL-002 design I10 (design.md:393) and ADR-004 §6: no layer outside core computes a depth or neighbour. ADR-003: commands hold no ordering logic. "Before X" → `(after (position X in others))` and "up" → `(after (1- i))` are depth computations. Either add a pure core helper (relative placement over plain data, e.g. `before`/`after ENTRY`), or rule that index lookup to produce a DEC-007 form is command-layer input translation. Needs a decision — this is exactly the POL-002/I10 boundary.
3. **Remove in Continue's chooser vs DEC-011.** DEC-011 fixed the chooser as `completing-read` over vocabulary labels; consequence: "Remove joins the chooser only when SL-003 provides it". REQ-018 AC2 and PRD-001 §6 want Remove as a distinct action. Tensions: a user label named "Remove" collides (`org-iw--check-placements`, org-iw.el:214, would need to reserve it or the candidate needs a distinct marker); is Remove offered by default or configured per queue (DEC-008)? After Remove, does Continue navigate to the new head and retain it (as for `moved`) or stop? RET-default safety (mem.fact.emacs.completing-read-default-bubbles) — Remove must never be the default. May need a DEC-011 amendment.
4. **New write-path entry point vs single-writer / one implementation.** ADR-002 "single writer" = one Emacs instance, not one function; ADR-003 explicitly puts "removes one property" in mutation. But org-iw-write.el:1, :25-29, :101 call `org-iw-write-put-rank` "the one write path". POL-002 forbids a parallel preflight/apply. Options: (a) `org-iw-write-delete-rank` sharing `--preflight`/`--apply`; (b) generalise put-rank with a nil rank = delete. (a) clearer naming; (b) keeps the literal "one write path" claim. Either way docstrings/commentary change (see Revision candidates), and `org-iw--save-status` docstring (org-iw.el:285) names put-rank only.
5. **What does "distinguishing context" require?** REQ-013 AC2: same-title entries distinguishable by "file/outline context". `org-iw-entry` (org-iw-core.el:48-54) carries only file. Choices: file name only (fails two same-title headings in one file); outline path read in discovery during scan (new field on the core struct; discovery reader per ADR-003/REV-002; cost per DEC-003/PRD-001 OQ-1); or resolve at display time per row (second read; conflicts with DEC-003 "rescan, no cache"?). STD-001 item 5 then demands context fixtures for the reader.
6. **Session interaction.** Removing the session entry (view/source/chooser): leave the session so the next Continue refuses "no longer in queue" (REQ-015 AC2, existing path), or end it? Ending contradicts DEC-005/org-iw.el:311 "cleared only by `org-iw--session-end`" via `org-iw-end-session` — needs an amendment. Moving the session entry: no session effect needed (session holds (queue, ID), not position). Inside a session, does a source-entry move/remove act on the entry at point or the retained entry? Continue uses retained (REQ-015 AC1); PRD-001 §6 "Outside a session … ask for the queue" implies the session queue applies inside one — but not what happens when the entry at point isn't a member of the session queue. Open-from-view replaces the view window (`pop-to-buffer-same-window`, org-iw.el:463) — acceptable UX?
7. **Document targets.** `org-iw--add-target` refuses before the first heading (org-iw.el:362; documents = SL-004). The view will list document entries (discovery reads them). Do source-entry move/remove support documents now, or refuse like Add until SL-004?
8. **Undo/refresh expectations (REQ-021/REQ-022).** After a move on a clean buffer the save policy saves; undo then dirties the buffer; refresh must read the live buffer (REQ-006). Does the view auto-refresh after its own actions? (It is a display copy — ADR-001 — but a stale row after a source edit can be acted on; guarded only by preflight `:expected` → "IW_Q changed since scan".) Decide: rescan before each action and act by entry ID, or refuse when the row is stale.
9. **Refusal wording reuse.** `org-iw--refuse-no-room` (org-iw.el:189-193) says "choose another placement" — fits Continue/Add, not view up/down. POL-002 treats the message as a concept; design should generalise one owner rather than add a second message.

### Relevant memories

- `mem.fact.emacs.batch-test-gotchas` — prompts block in batch (`</dev/null`), `current-message` nil / mode line "" in batch, private `*code-conversion-work*` buffer, advising inlined struct accessors does nothing. Directly relevant to testing tabulated-list output and prompts.
- `mem.fact.emacs.org-write-idioms` — `org-entry-put` ignores read-only (check `buffer-read-only` yourself); `atomic-change-group` outside `org-with-point-at`; use `org-with-point-at`; avoid Org calls in non-Org buffers; `string-match-p` in pure code. Applies to the new delete write.
- `mem.fact.emacs.save-hook-errors-demoted` — testing a failed save after remove: fail `write-file-functions`, not `before-save-hook`.
- `mem.fact.emacs.completing-read-default-bubbles` — chooser order/RET-default semantics; bears on adding Remove to the chooser (OQ 3) and on any queue/entry prompt.
- `mem.fact.emacs.completion-table-with-metadata-31-only` — use a lambda table, not `completion-table-with-metadata`, for Emacs 30.
- `mem.pattern.doctrine.vt-keywords-match-prose` — key VTs on test names; re-run `verify-vt` slice-wide each phase; view message wording must not be keywords.
- `mem.pattern.doctrine.design-review-gate-gotchas` — design-run review/lock gotchas (doctrine 0.46.5) for the SL-003 design run.
- (No memories exist for "tabulated", "mutation", or "remove property" — searched.)

### Revision candidates

- **org-iw-write.el:1, :25-29, :101 (code docs, not governance):** "the one write path" / put-rank as sole writer becomes false once remove lands — reword to "the write layer". ISS-001 (put-rank docstring omits read-only refusal) can be fixed in passing.
- **org-iw.el:285** `org-iw--save-status` docstring names only put-rank's result.
- **DEC-011:** consequence anticipates Remove in the chooser, but the choice text defines the chooser as vocabulary labels only — likely amendment (OQ 3).
- **DEC-005:** amend only if remove ends the session (OQ 6).
- **SL-002 design I10 / ADR-004 §6:** if OQ 2 adds a relative-placement core helper, no change; if commands translate view index → `(after k)`, record a DEC clarifying this is input translation, not depth computation, or I10 drifts.
- **SL-003 metadata (slice-003.toml):** `governed_by` lists ADR-001..003, POL-001..003 but omits ADR-004 (SL-002 added it) and STD-001..004 — stale relative to the governing set; fix with `doctrine link SL-003 governed_by ADR-004` etc. (orchestrator/user act; not done here).
- **PRD-001 §6 "Move / remove":** does not say what placement a source-entry move uses; if OQ 1 settles it, consider a REV annotating §6 / REQ-017 (as REV-003 did for OQ-3).
- No accepted ADR/policy/standard text needs to change for SL-003 as scoped — ADR-003 already anticipates "removes one property", and ADR-001/002 cover view/undo semantics.
