# PRD-001: org-iw: incremental writing queues for Org

<!-- Reference forms: `lib:reference/glossary.md` § reference forms. -->

Source brief: `org-incremental-writing-brief.org` (2026-09-30). This spec
normalises it; where they differ, this spec governs once accepted.

## 1. Intent

Unfinished writing, past journals and worthwhile but ill-defined tasks decay
when nothing brings them back. The user wants to return to them incrementally:
open a named queue when inclined to work, take something worth working on,
edit it where it already lives, and put it back with one short interaction.

org-iw provides named, ordered queues of existing Org documents and headings.
It is incremental writing first, with incremental reading and general
resurfacing as the same mechanism. Time-based scheduling, recall scoring and
maturity stages are not the foundation.

Desired end state: the loop *open queue → visit → edit in place → continue*
is fast and predictable, and the metadata left in the user's files is
comprehensible without the package.

Motivating uses: revisiting Org/Denote day journals; developing notes,
articles and ideas over many encounters; returning to deadline-free tasks;
occasionally resuming a skill or project via an Org entry that links to it.

## 2. Scope

In scope:

- Queues whose members are Org documents or Org headings with Org IDs.
- Enrolment (single entry and batch of files at document level), inspection,
  visiting, continuing, moving and removing memberships.
- Per-queue reinsertion vocabulary in Elisp configuration.
- Discovery over user-configured files/directories.
- Explicit redistribution/normalisation of ranks as a maintenance action.

Out of scope (deferred; see brief § Deferred features):

- Snoozing (`IW_AFTER_<Q>` is reserved but neither written nor interpreted).
- Batch enrolment of headings; query/tag-driven membership; any query DSL.
- Full multi-membership UX (the representation supports it now).
- SRS/FSRS, recall ratings, adaptive or persistent scheduling policies.
- Review statistics, encounter histories, maturity taxonomies.
- Native adapters for non-Org targets (Denote notes, URLs, repositories are
  reached via links in an Org entry).
- Automated extract/merge/refile, agent suggestions, automatic Git operations,
  multi-writer concurrency.

Boundaries:

- One active Emacs writer. No multi-instance or transactional guarantees are
  claimed.
- No public data API is locked down before the interactions work.

## 3. Principles

- **The entry is the database.** Membership and rank live on the entry as
  properties; queue views are derived. There is no authoritative index, log
  or external queue file.
- **Content stays in place.** Nothing is copied, archived or deleted; TODO
  state and priority are untouched and independent of position.
- **Position is not importance.** Queue order expresses only "what next".
- **Visiting is not consuming.** Only an explicit operation changes
  membership or order.
- **Unsurprising over frictionless for multi-file writes.** A single-entry
  change is quiet; anything spanning files is previewed and approved.
- **Surface, don't repair.** Ambiguity (duplicate IDs, invalid ranks,
  missing targets) produces a diagnostic, never an arbitrary write.
- **Earn complexity.** A feature enters only when real use calls for it.

## 4. Requirements

The functional and quality requirements this capability must satisfy are
recorded as requirement entities and appear under the synthesized
Requirements section below. This section carries only the constraints and
invariants that bound every valid implementation.

Constraints:

- Package name `org-iw`; all public and private symbols use the `org-iw-`
  prefix.
- Minimum Emacs 30.1 with bundled Org; no third-party runtime dependencies.
- Must not require org-roam, Denote or `org-agenda-files`.
- Membership properties are read locally, never via property inheritance.
- Rank values are signed decimal integers; floating-point ranking is
  forbidden.
- Writes happen through visiting buffers; files are never written behind a
  live buffer.
- Queue definitions (ID, display name, reinsertion labels/placements,
  default) live in Elisp configuration; unconfigured queues found in files
  remain usable with defaults.

Invariants:

- A membership is identified by (entry Org ID, canonical queue ID); absence
  of `IW_<QUEUE-ID>` means non-membership.
- Visiting an entry never changes queue state.
- An operation targeting queue A never alters memberships in other queues,
  reserved `IW_AFTER_<Q>` metadata, or non-IW properties.
- An ordinary single-membership operation writes at most one rank (plus an
  ID on enrolment).
- A blocked or cancelled operation leaves every file and buffer unchanged.
- An already-modified buffer is never saved by the package without the
  user's explicit resolution.
- Ordering is a total, deterministic function of source state (rank, then
  entry ID).

## 5. Success Measures

Outcomes:

- The user uses org-iw for their journal corpus and article drafts in
  preference to ad-hoc revisiting.
- Continue is a single command in the common case.

Acceptance gates:

- The manual walkthrough passes on disposable Git-backed fixtures: enrol a
  journal batch, add an article heading, inspect and reorder both queues,
  edit a visited entry, Continue using multiple placements, remove a
  membership, and exercise redistribution cancellation and approval.
- `git diff` after an ordinary Continue shows exactly one changed property
  line in one file.
- The automated suite passes on Emacs 30 and 31; lint is clean.

Signals:

- Redistribution is rare in practice (tail rotation dominates).
- No reports of lost or silently saved draft edits.

## 6. Behaviour

**Add.** Trigger: user invokes add in an Org buffer. Target is the heading at
point, or the document before the first heading, or the document explicitly
(command/prefix). User chooses a queue (completion); default placement is
append. Result: target has an ID and `IW_<Q>`; save policy applied. Existing
membership → reported no-op.

**Batch add.** Trigger: user selects Org files. Files are processed in
canonical path order and appended in that order. Result: report of added,
already-present and failed files; partial completion is stated plainly.

**Inspect.** Trigger: user chooses a queue. A list shows ordinal, title and
distinguishing context. Actions: open (establishes session), up/down, place
before/after a chosen entry, remove, refresh. Empty queue → reported empty.

**Visit next.** Trigger: user chooses a queue (or reuses the session queue).
Opens the first entry; retains (entry, queue) and displays it. Repeated visit
without Continue reopens the same entry. No state change.

**Continue.** Trigger: user in an established session invokes the default
or chooses an alternative (e.g. Soon / Later / End, or Remove as a distinct
action). The queue is recomputed from source; the retained membership is
placed; the new first entry is opened and retained.
Alternate flows: sole entry → left in place, "no other entry" reported;
target removed/unresolvable → reported, no recreation, no navigation;
placement changes no relative order → no write; no integer gap → pause and
offer redistribution; depth zero → may reopen the same entry, deliberately.

**Move / remove.** From view or source entry. Outside a session with
multiple memberships at point, ask for the queue. Remove deletes only that
property.

**Redistribution / normalise.** Trigger: blocked placement, or explicit
normalise request. Preview shows counts, browsable affected files, pending
operation, unsaved and unwritable targets, non-atomicity and a strong
recommendation to commit to Git first. User resolves unsaved edits, then
approves or cancels. Cancel → no change at all. Approve → revalidate against
live state; if changed, re-preview and re-approve; else apply and save via
buffers, then finish the pending navigation. Write failure → stop, report
saved / modified / untouched files, do not navigate.

**Diagnostics.** Duplicate IDs, invalid ranks, invalid queue IDs and
unresolvable targets are reported with locations; affected entries are
excluded from writes.

## 7. Verification

Automated ERT suites run in batch on Emacs 30 and 31 against temporary
fixture files and buffers. They concentrate on ordering and preservation
risk:

- pure placement and rank allocation (REQ-009, REQ-010, REQ-023): fixed,
  fractional and end forms, clamping, negative ranks, empty and singleton
  queues, no-op moves, repeated gap subdivision, gap exhaustion, ties;
- representation and discovery (REQ-001–REQ-008): document vs heading
  properties, no inherited enrolment, queue-ID canonicalisation and the
  reserved `IW_AFTER_` namespace, live-buffer precedence, dedup and
  diagnostics;
- preservation (REQ-004) as byte-level comparison of untouched regions and
  properties after each mutating operation;
- session semantics (REQ-014, REQ-015): Continue targets the retained
  membership after navigation or queue change; missing-target handling;
- save policy and undo (REQ-021, REQ-022) with initially clean vs dirty
  buffers;
- batch add (REQ-012): deterministic order, existing-membership no-ops,
  partial failure;
- redistribution (REQ-019, REQ-020): cancel changes nothing, stale
  approved plans are rejected, simulated write failure yields a correct
  partition report.

The manual walkthrough in § 5 is the acceptance gate for interaction
quality (REQ-011, REQ-013–REQ-018) and is recorded as a human-verified
criterion. Lint (byte-compile warnings as errors, checkdoc, package-lint)
is a standing gate.

## 8. Open Questions

- OQ-1 — Discovery performance on a large journal corpus: is a full rescan
  per operation acceptable, or is an in-memory index needed from the start?
  Shapes the discovery design and whether cache invalidation enters v1.
- OQ-2 — Files opened by the package to perform a write (no prior buffer):
  leave the buffer open or kill it after a clean save? Affects buffer-list
  noise and batch add behaviour.
- OQ-3 — Default placement depths for the standard Soon / Later / End
  vocabulary (brief suggests after-2, halfway, tail). Confirm before the
  session slice.
  **Settled** by DEC-009 (2026-10-01), implemented by SL-002: Soon
  `(after 2)`, Later `(fraction 1 2)`, End `end`, in that chooser order;
  default End. Revisit the default once SL-006 lands.
- OQ-4 — How the session context is displayed (mode-line lighter, header
  line, or echo only) and whether it persists across Emacs restarts. The
  brief requires visibility, not persistence.
