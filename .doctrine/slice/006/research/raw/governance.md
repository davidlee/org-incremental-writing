<!-- Thread 1 raw output: read-only general-purpose subagent (Opus 5.5), 2026-10-06. Content as returned; bullets reflowed by the assembler. -->
## Thread 1 — governance applicability

### Binding constraints

- **ADR-004** (sparse integer ranks) — the central authority. Rules: (1) domain "A rank is an integer `r` with `|r| ≤ 2^53 − 1`. Negative ranks are valid… Order is by rank, then by entry ID (`string<`)." (`org-iw-core-rank-limit`, `org-iw-core.el:38`). (2) spacing "New ranks are laid out at a fixed power-of-two spacing, a core constant" — 1024 (`org-iw-core-rank-spacing`, `org-iw-core.el:35`; DEC-010). (3) allocation writes one entry, computed "over the order with the target removed": empty → spacing; end → last + spacing; front → first − spacing; between → `floor((L + R) / 2)` "used only when it lies strictly between them"; "A placement that leaves the relative order unchanged writes nothing." (4) no gap: "If no allowed rank exists, either because the neighbours are adjacent or because the result would pass the limit, the operation stops before any change and says that redistribution is needed. It never renumbers silently or falls back to another scheme." (5) redistribution is maintenance: "Renumbering a queue, including the pending placement, re-lays every member at the spacing, in order. It runs only after the user approves a previewed plan, and it follows REQ-019 and REQ-020 … It writes through the mutation layer's shared preflight and apply, as every rank write and delete does." (6) "Rank domain, spacing, allocation and redistribution plans are pure core functions over plain data … No other layer computes a rank." Neutral: "Ranks carry no meaning beyond order. Their values drift and are normalised only on request"; tail rotation reaches the limit only "after about 2^43 rotations". Verification: "Review: no layer other than the core computes a rank." — binds SL-006 entirely; not listed in SL-006's `governed_by` (see Revision candidates).
- **ADR-001** — "No queue file, database, persistent index, review log or recovery journal is authoritative or required." Negative consequences: "Global operations such as redistribution touch many files." — rules out a recovery/undo journal for a failed redistribution (matches the slice non-goals); the plan must be derived from source entries only.
- **ADR-002** — "every change through a buffer visiting the file (opening it if needed) … live buffer contents, including unsaved changes, as authoritative over disk." Save policy: "a buffer that was unmodified before the operation is saved after it. A buffer that was already modified is left unsaved." "org-iw assumes one active Emacs writer. It claims no transactional, atomic or multi-instance guarantees. Multi-file work (batch add, redistribution) reports partial completion, and recovery is by Git and normal buffer tools." Verification: "Multi-file tests simulate a write failure and check the partial-completion report (REQ-020)." — the apply/save mechanism and non-atomicity contract.
- **ADR-003** (with REV-002, REV-004) — four layers, fixed direction; core is pure and owns "redistribution plans"; "Every guard on a write, including file, buffer, stale-value and drawer-shape checks, lives in the mutation layer's preflight, so every caller gets it"; "Every reader of Org structure and every scan query lives in discovery"; "Commands compose the layers and let their refusals surface. They own only their own preconditions." — the plan goes in `org-iw-core.el`; writability/unsaved checks belong to write-layer preflight, not commands; preview UI holds no ordering logic.
- **POL-001** — zero-warning lint (byte-compile, checkdoc, package-lint), ERT green on Emacs 30 and 31, red/green/refactor; "No phase or slice closes red or with lint warnings."
- **POL-002** — one implementation per concept; "Before writing new code, search for an existing owner and adapt or extend it." Owners SL-006 must extend: `org-iw-core-place`/`org-iw-core-rank-at` (`org-iw-core.el:172,193`), `org-iw-write--preflight`/`--apply` (`org-iw-write.el:90,111`), `org-iw--refuse-no-room` (`org-iw.el:229`), `org-iw--save-status` (`org-iw.el:336`), the batch open/write/kill helper `org-iw--batch-outcome` (`org-iw.el:655`), batch report `org-iw--batch-report` (`org-iw.el:635`).
- **POL-003** — VH trial required; SL-006 states it: "on a disposable Git-backed fixture, cancel and approve a redistribution, then inspect `git diff`."
- **STD-001** — item 2 tested oracles ("Cancel changes nothing" needs a self-tested oracle); item 3 every new guard killed by mutation (recheck/stale-plan rejection, unwritable detection, unsaved resolution, failure path); item 4 pin constants literally (spacing 1024; re-laid ranks); item 5 context fixtures (dirty, indirect/narrowed buffers).
- **STD-002** — VT `keywords` name `ert-deftest`/test-code symbols, never message text.
- **STD-003** — "Scale up for high-stakes slices (write path, redistribution): add the legibility reviewer and an opus verifier." SL-006 is named.
- **STD-004** — item 4 "Every refusal is `org-iw-core-refuse`"; item 1 one file per layer (plan in `org-iw-core.el`); item 2 no cross-file `--` use (relevant if `org-iw--batch-outcome` is reused outside its file); item 7 core purity.
- **REQ-019** (FR-019) — "When a placement cannot be represented, or on explicit request to normalise a queue, the user is shown a redistribution plan (affected entries and files, the pending operation, unsaved buffers, unwritable files, non-atomicity and a Git-commit recommendation) and must approve it before any rank changes." AC verbatim: "Cancelling applies neither redistribution nor the pending move." / "A plan whose source state changed after preview is rejected and a fresh plan is presented for approval." / "Unsaved edits in affected buffers must be resolved explicitly; approval never discards them." / "Unwritable targets are detected before any write." / "Redistribution preserves intended order including the pending move."
- **REQ-020** (FR-020) — "If a redistribution write fails, the operation stops and reports which files were saved, which buffers are modified and which were untouched, and does not complete the pending navigation." AC: "A simulated write failure mid-plan produces a report partitioning affected files into saved/modified/untouched." / "Continue does not navigate onward after a failed redistribution."
- **REQ-021** (FR-021) — "A buffer that was clean before an operation is saved automatically after it; an already-modified buffer is left unsaved with a clear report…; files are never written behind live buffers." AC: "Unrelated draft edits are never saved silently." / "Batch operations apply the same policy per file."
- **REQ-010** (FR-010) — "if no integer rank exists between the intended neighbours, the operation stops before any mutation and offers redistribution." AC: "A move between adjacent ranks 5 and 6 makes no change and offers redistribution." — changes today's refusal to an offer.
- **REQ-023** (NF-001) — exact integer arithmetic, "never rounded"; re-laid ranks satisfy `org-iw-core-rank-p`.
- **REQ-004** (FR-004) — "Adding, moving or removing membership in queue A leaves IW_B, IW_AFTER_A and all non-IW properties byte-identical." Redistribution of A touches only `IW_A` lines.
- **REQ-008** (FR-008) — order is rank then entry ID; re-laying must reproduce current order including ties (equal ranks re-laid in ID order).
- **REQ-015** (FR-015) Continue — "After success, the new first entry becomes the retained context"; "If the retained target was removed or is unresolvable, Continue reports it and neither recreates it nor navigates."
- **REQ-022** (FR-022) — "No cross-file undo log is created."
- **REQ-025** (NF-003) — "No review log, external queue file, persistent index or recovery journal is created." Failure report must not persist as a journal.
- **REQ-007** (FR-007) — duplicate identity: "no operation writes to either until resolved"; invalid ranks "excluded from ordering; it is not rewritten".
- **PRD-001 § 3** — "Unsurprising over frictionless for multi-file writes. A single-entry change is quiet; anything spanning files is previewed and approved." "Surface, don't repair."
- **PRD-001 § 4 invariants** — "A blocked or cancelled operation leaves every file and buffer unchanged." "An already-modified buffer is never saved by the package without the user's explicit resolution." "An operation targeting queue A never alters memberships in other queues…"
- **PRD-001 § 6 "Redistribution / normalise"** — "Trigger: blocked placement, or explicit normalise request. Preview shows counts, browsable affected files, pending operation, unsaved and unwritable targets, non-atomicity and a strong recommendation to commit to Git first. User resolves unsaved edits, then approves or cancels. Cancel → no change at all. Approve → revalidate against live state; if changed, re-preview and re-approve; else apply and save via buffers, then finish the pending navigation. Write failure → stop, report saved / modified / untouched files, do not navigate."
- **PRD-001 § 6 Continue alternate flow** — "no integer gap → pause and offer redistribution".
- **PRD-001 § 7 Verification** — "redistribution (REQ-019, REQ-020): cancel changes nothing, stale approved plans are rejected, simulated write failure yields a correct partition report."
- **PRD-001 § 5 acceptance gate** — "exercise redistribution cancellation and approval" on disposable Git-backed fixtures; SL-007 walkthrough depends on SL-006.
- **RFC-001** slice 6 — "Preview, resolve unsaved buffers, check writability, approve, recheck against live state, apply and save, report partial failures. Blocked moves and Continue hand off to it. Explicit normalise command." Reqs 019, 020; "Slice 6 needs 2 (placement) and 3 (move)."
- **DEC-003 / DEC-027** — rescan per operation, no cache; "every read goes through org-iw-discovery-scan; … batch add scans once and derives every rank from that scan". By analogy: plan from one scan; recheck is a fresh scan compared against it.
- **DEC-004** — "A file org-iw had to visit to write is left open (clean, saved)" — single-entry commands.
- **DEC-026** — "Batch add kills each buffer it had to open if that buffer is unmodified once the file is done… A buffer it opened that stays modified … is kept and reported." Consequences: "SL-006 redistribution may reuse the same open-write-kill helper". SL-006 must choose DEC-004 vs DEC-026 behaviour.
- **DEC-028** — progress reporter, echo summary that "says the operation is not atomic", `*org-iw batch*` report "on trouble", report data "built as plain data". Existing owner of a multi-file report; POL-002 candidate for REQ-020's partition report.
- **DEC-005** — single global in-memory session; Continue sets it. Successful redistribution must finish Continue's navigation and set the session; failed leaves it unchanged.
- **DEC-011** — `org-iw-continue` applies default placement; `C-u` opens the chooser.
- **DEC-012** — Move "places through org-iw-core-place without navigating; … no gap refuses." Handoff replaces that refusal.
- **DEC-013** — view up/down and before/after are placements through `org-iw-core-place`; consequences: "equal-rank neighbours as no-gap (refuse until SL-006)."
- **DEC-019** — "Every action rescans, finds its entry by ID, and redraws." View-triggered redistribution must redraw.
- **DEC-009** — default End; "revisit the default once SL-006 lands, if the user wants." (PRD-001 OQ-3.)
- **DEC-010** — spacing stays 1024; "no-room refusals remain possible for repeated Soon/Later before SL-006."
- **DEC-014** — delete and put-rank share `--preflight` and `--apply`; redistribution must use the same pair, no third preflight.
- **DEC-021 / DEC-022** — document identity; document markers at widened `point-min`; `:document t` only for creation. Re-ranking existing document members must take discovery's markers.
- **EVD-002** — one fixed placement exhausts its gap "after 11 Continues"; a random mix lasts 41–5911. The handoff will be hit in ordinary use.

### Checked — not applicable

- DEC-001 (module layout) — subsumed by STD-004 item 1; SL-006 adds no file.
- DEC-002 (`org-iw-queues` shape) — no queue configuration added, unless design adds a normalise option.
- DEC-006 (Emacs 30 test binary) — test infrastructure only.
- DEC-007 (placement forms) — pending operation reuses existing placements.
- DEC-008 (vocabulary) — no vocabulary change.
- DEC-015 / DEC-016 (Remove) — Remove needs no gap.
- DEC-017 (view context column) — unless the preview reuses the view's columns.
- DEC-018 (entry at point) — unchanged.
- DEC-020 (`C-u` queue choice) — queue resolution precedes the handoff.
- DEC-023 / DEC-024 / DEC-025 — enrolment surfaces; but see the open question on blocked Add and batch add at the limit.
- ASM-001 (unique file names) — carries over if the preview lists basenames.
- QUE-001 — answered (STD-001..004). QUE-002 — answered by DEC-021.
- EVD-001 — delivery evidence.
- No open ASM, QUE or CON records bear on redistribution (`doctrine knowledge list -a`: ASM-001 held, QUE-001/002 answered, EVD-001/002; no CON).
- Backlog not applicable: IMP-001, ISS-003, IMP-004, IMP-008, IMP-009, IDE-002, ISS-006, CHR-004, CHR-005.
- SL-005 — not a prerequisite (`needs: SL-002, SL-003`; RFC-001 "Slice 6 needs 2 … and 3").
- ADR-001's reserved `IW_AFTER_<Q>` — ADR-004: "stays reserved and is never written".

### Backlog items relevant to SL-006

- IMP-002 — preview scan, recheck scan and interactive scan compound.
- IMP-010 — redistribution scans a queue at least twice; not a blocker at user scale (DEC-027: <200 files ~0.15 s).
- IDE-001 — open views of the queue go stale after a redistribution.
- ISS-002 — Continue status hidden by a refused head visit; same shape after an approved redistribution + pending Continue.
- ISS-004 — quoted refusal display affects every new SL-006 refusal.
- CHR-001 (`just mutate`), CHR-002 (cross-file `--` lint), CHR-003 (README each slice), IMP-003 (one self-tested state oracle), IMP-006 ("WHERE, D/N" text owner), IMP-007 (prompt recorder unconsumed answers).

### Deferred-to-SL-006 promises from prior slices

- `.doctrine/slice/001/design.md:15-17` — later slices extend the owners named here, no parallel path (POL-002).
- `.doctrine/slice/001/design.md:101` — "Later slices (move, remove, batch add, redistribution) reuse these owners unchanged." (write-layer preflight).
- `.doctrine/slice/001/design.md:213-214` — "Allocation that would cross the limit returns nil. Callers report that as 'redistribution needed', which SL-006 will provide."
- `.doctrine/slice/001/design.md:393` — `--apply`/save path: "… and SL-006 redistribution."
- `.doctrine/slice/002/design.md:19` — "redistribution (SL-006), which SL-002 only refuses toward".
- `.doctrine/slice/002/design.md:89-93` — every placement decision from `org-iw-core-place`; "SL-006's pending placement call the same two functions."
- `.doctrine/slice/002/design.md:173` — `(no-gap DEPTH)  no allowed rank: write nothing, redistribution needed`.
- `.doctrine/slice/002/design.md:391-393` — I9 "A `no-gap` placement changes nothing and navigates nowhere. The session is unchanged." I10 "Every rank written comes from `org-iw-core-rank-at` … No other function computes a rank, a depth or a neighbour."
- `.doctrine/slice/002/design.md:410-415` — tied neighbours → `no-gap`, routed to redistribution; limit → `no-gap`.
- `.doctrine/slice/002/design.md:430` — "Revisit DEC-009 (default End) once SL-006 makes exhaustion recoverable."
- `.doctrine/slice/002/design.md:468-472` — hot-spot exhaustion mitigated by default End "and SL-006 is two slices away".
- `.doctrine/slice/003/design.md:21-22` — redistribution out of scope "(SL-006; until then the command stops and reports)".
- `.doctrine/slice/003/design.md:622-633` — single-owner text "no room WHERE in NAME; redistribution is not yet available"; WHERE forms "at LABEL", "at the end", "before T"/"after T", "at position D/N"; "temporary until SL-006". Code owner `org-iw.el:229-232`.
- `.doctrine/slice/003/design.md:678-680` — equal-rank neighbours → `no-gap`, refused until SL-006.
- `.doctrine/slice/003/design.md:725` — DEC-009 revisit waits for SL-006.
- `.doctrine/slice/003/design.md:753-756` (inq-9) — `org-iw--refuse-no-room` one owner, "temporary until SL-006".
- `.doctrine/slice/003/design.md:808` — "Ties and front exhaustion refuse until SL-006."
- `.doctrine/slice/004/design.md:251` — Add step refuses "no room"; no handoff yet.
- `.doctrine/slice/004/design.md:443-444` — batch: "No room at the end (rank limit) → that file and the rest fail with the no-room message; redistribution is SL-006."

### Revision candidates

- SL-006 metadata — `governed_by` omits ADR-004 and STD-001..004 (relationship edit, not a REV).
- ADR-004 rule 5 underspecified: starting value of the re-laid sequence (`k·spacing`, k=1..N, inferred); whether members already at target rank are rewritten; how excluded memberships (REQ-007) relate to "every member"; per-entry `--apply` saves after each entry (`org-iw-write.el:111-127`), so a file with several members saves several times mid-plan — a REV may need to allow a multi-entry, per-file apply sharing the preflight.
- ADR-004 rule 4 vs REQ-010 "offers redistribution" — consistent, but SL-003's message (`design.md:622`) and code (`org-iw.el:232`) become stale.
- PRD-001 § 6 / REQ-019 — "resolve" undefined (save, revert, exclude, abort); does a user-performed save conflict with "A blocked or cancelled operation leaves every file and buffer unchanged" on a later cancel? AC could state allowed resolutions.
- REQ-019 "Unwritable targets are detected before any write" — doesn't say what follows; a REV could add "approval is unavailable while any target is unwritable".
- REQ-020 "which buffers are modified" — partition semantics: saved = written and saved; modified = written, not saved; untouched = not reached.
- PRD-001 § 8 OQ-2 (keep/kill opened buffers) — settled only for batch (DEC-026) and single-entry (DEC-004); redistribution needs an answer; prose REV to mark settled.
- PRD-001 § 8 OQ-3 / DEC-009 — scheduled revisit at SL-006 close.
- SL-002 design I10 (`design.md:393-395`) — "Every rank written comes from `org-iw-core-rank-at`" is too narrow once plans exist (ADR-004 rule 6 permits).
- DEC-012 ("no gap refuses") and DEC-013 consequences ("refuse until SL-006") — become stale; amend.
- RFC-001 slice 2 row ("redistribution not yet available") — historical; record SL-006 delivery in RFC-001 outcome.
- ADR-002 Neutral — "(PRD-001 OQ-2)" cross-reference to update once SL-006 decides.

### Open questions for design

- What does "resolve unsaved edits" offer (save, revert, abort, exclude)? Does a save done during resolution survive a later Cancel? — REQ-019 AC3, PRD-001 § 4, § 6, ADR-002.
- Can a plan with unwritable targets be approved, or is approval withheld until a clean re-preview? — REQ-019 AC4/AC5.
- What counts as "changed live state" for the recheck: ordered (ID, rank) list, modification ticks, or the full plan? Does a change in another queue or in non-IW text force re-preview? — REQ-019 AC2, PRD-001 § 6, DEC-027.
- Re-laid sequence (`k·1024` from k=1?) and whether entries already at target are skipped — ADR-004 rules 2/5, REQ-010, STD-001 item 4.
- Excluded memberships (invalid rank, duplicate ID, missing ID): refuse while the queue has problems, or proceed and leave them out? — REQ-007, PRD-001 § 3, ADR-004 rule 5.
- Per-file apply granularity; a multi-entry apply keeping the shared preflight (POL-002, DEC-014) — ADR-002, ADR-003, ADR-004 rule 5.
- Buffers opened by redistribution: keep (DEC-004) or kill once clean (DEC-026); generalising `org-iw--batch-outcome` (`org-iw.el:655`) — PRD-001 OQ-2, POL-002.
- Which blocked operations hand off: Continue, Move (DEC-012), view up/down/before/after (DEC-013, DEC-019); Add-at-placement (REQ-011, DEC-011) and batch add at the limit (`.doctrine/slice/004/design.md:443-444`) not named — RFC-001, PRD-001 § 6, REQ-010.
- Pending-operation representation: `(no-gap DEPTH)` + `org-iw-core-reorder` + a new core re-lay function? — ADR-004 rules 5/6, SL-002 design `:89-93`, `:173`.
- Preview UI: DEC-028 report form, a dedicated mode, or the queue view (DEC-019)? "Browsable" files vs ASM-001 basenames — PRD-001 § 6, REQ-019, DEC-028, ASM-001.
- After a successful Continue handoff, reporting multi-file save status and navigation without repeating ISS-002 — REQ-015, REQ-020, ISS-002, DEC-005.
- View redraw after a view-started redistribution; other open views (IDE-001) — DEC-019.
- Normalise target: session queue or completion prompt; empty or already-normal queue a no-op? — PRD-001 § 6, REQ-019, RFC-001.
- Git recommendation: detect repo/dirty, or static text? (Git automation non-goal; PRD-001 § 2) — REQ-019.
- DEC-009 default revisit at SL-006 close — DEC-009, PRD-001 OQ-3, SL-002 `:430`, SL-003 `:725`.
