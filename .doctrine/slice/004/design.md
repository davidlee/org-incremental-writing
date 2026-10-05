<!-- doctrine:section sec-01-problem -->
## 1. Design Problem

SL-001 to SL-003 queue headings well, but a whole Org document can't be
enrolled: Add refuses before the first heading, and there is no way to
enrol many files at once. The user's journal is 74 Denote-named files
with no `:ID:` and no `#+identifier:` (research T1, corpus survey), so
today every one would need an inserted `:ID:` and a separate Add.

SL-004 delivers:

- **Document entries** (REQ-002): the file-level property drawer is the
  document's entry; nothing is inherited by its headings.
- **Document identity** (DEC-021): a document is identified by its
  file-level `:ID:`, else by Denote's own filename identifier when Denote
  is available, else it has none and Add gives it an `:ID:`.
- **Leaving a queue** (DEC-022): removing a document's last membership
  takes its emptied drawer with it, so a Denote note returns to its
  original text.
- **Add a document** (REQ-011, DEC-023): `org-iw-add` before the first
  heading, or `org-iw-add-document` from anywhere in the file.
- **Batch add** (REQ-012, DEC-024..028): `org-iw-add-files` enrols
  selected files at document level, appended in canonical path order,
  with a per-file report and partial completion.

Out of scope: a scan cache (DEC-027, IMP-010); heading identity by
`CUSTOM_ID` (IDE-002); batch heading enrolment; batch placement other
than append (DEC-025); a hard Denote dependency.

<!-- doctrine:section sec-02-current -->
## 2. Current State

- **Discovery already reads document entries.**
  `org-iw-discovery--scan-buffer` takes each IW_ line back to its entry
  with `org-back-to-heading-or-point-min`; an IW_ line in a drawer before
  the first heading yields a document entry at `point-min`. Only the
  entry's own drawer is read (`org-iw-discovery--iw-lines`), so headings
  never inherit (REQ-002 AC1/AC2 already hold; tests exist for the
  document read, `org-iw-discovery-test-scan-document-entry`).
- **Identity is `:ID:` only.** `org-iw-discovery-entry-id` reads
  `(org-entry-get nil "ID")`. The ID-line matcher `--id-lines` feeds the
  per-file tally, `org-iw-discovery-id-count`, `--id-positions` and
  `org-iw-discovery-resolve`. A document member without `:ID:` is a
  `missing-id` problem.
- **The write layer marks a document by `point-min`.**
  `org-iw-write-put-rank` takes "a marker at an entry's heading, or at
  `point-min` for a document entry". With `:ensure-id` it calls
  `org-id-get-create`. Research T2: this works when the file has text
  before its first heading, and enrols the *first heading* when the file
  starts with one (T2-2).
- **Add refuses documents.** `org-iw--heading-or-refuse` ("document
  targets are not yet supported", DEC-018). `org-iw--target-at-point`
  already returns `point-min` before the first heading; Move and Remove
  accept member documents.
- **Add's checks** live in `org-iw--check-heading`: already a member →
  position; IW line for the queue but excluded → refuse; ID shared →
  refuse. Add then calls `org-iw-core-place` with `end` or the chosen
  placement and `org-iw-write-put-rank … :expected :absent :ensure-id t`.
- **Delete keeps the drawer.** `org-iw-write-delete-rank` restores the
  buffer and errors if the deletion emptied the drawer
  (`org-iw-write.el`, "IW_%s not deleted alone"), on the assumption that
  the drawer holds the entry's `:ID:`. A Denote note's drawer holds only
  `IW_` lines (RV-012 F-1).
- **Buffers opened to write stay open** (DEC-004), via
  `org-iw-discovery-buffer` (`find-file-noselect`).
- **Every command rescans** (DEC-003). Add scans twice (interactive spec
  and body; IMP-002).

<!-- doctrine:section sec-03-forces -->
## 3. Forces & Constraints

- **ADR-001** — membership is an `IW_<Q>` property on the entry; any
  index is a disposable copy. A document's membership lives in its
  file-level drawer.
- **ADR-002 / REQ-021** — every write through a visiting buffer; save a
  buffer that was clean, leave a dirty one unsaved and say so; batch
  applies the policy per file; no atomicity is claimed.
- **ADR-003** — readers of Org structure and identity live in discovery;
  write guards in the write preflight; commands hold no ordering logic.
- **ADR-004 / SL-002 I10** — every rank comes from
  `org-iw-core-rank-at` via `org-iw-core-place`.
- **POL-002** — one implementation per concept: one identity owner, one
  add step shared by Add, Add-document and batch, no copied Denote rules.
- **REQ-024 / PRD-001 § 4** — Emacs 30.1+, built-ins only. Denote may be
  used when installed, never required (DEC-021: soft load).
- **REQ-012** — same file set → same order; existing reported unchanged;
  failures don't stop the run; partial completion reported; not atomic.
- **Minimise property litter** (user, 2026-10-05) — a Denote note gains
  only its `IW_<Q>` line (and a drawer around it), never an `:ID:`.
- **Scale** (DEC-027) — <200 files now; thousands later must stay
  possible: one scan per batch, per-file scan results.

<!-- doctrine:section sec-04-principles -->
## 4. Guiding Principles

1. **One add step.** Add, Add-document and each file of a batch run the
   same check-place-write step over plain data; the batch is a fold of it
   over files.
2. **Identity has one owner.** Discovery computes an entry's identity and
   its occurrences in a buffer; every reader (scan, tally, resolve, Add's
   checks) agrees because they call it.
3. **Use Denote's own machinery.** org-iw asks Denote whether a file is a
   note and what its identifier is; it reimplements no Denote rule.
4. **Say "document" explicitly where `point-min` is ambiguous.** Only
   creation needs it, so only the write and Add's checks take the flag.
5. **Batch is not a transaction.** Each file stands alone; the report is
   the recovery aid (ADR-002).

<!-- doctrine:section sec-05-1-system-model -->
## 5. Proposed Design

### 5.1 System Model

```
org-iw.el (commands)
  org-iw-add ─────────┐
  org-iw-add-document ┼─► org-iw--add-entry  (one step: check, place, write)
  org-iw-add-files ───┘      ▲ fold over files, order threaded
        │                    │
        ├─ org-iw-discovery-files      (selection + canonical order)
        ├─ org-iw-discovery-scan       (once per command run)
        ├─ org-iw-discovery-entry-id   (identity, file-aware)
        ├─ org-iw-discovery-document-slot-p
        ├─ org-iw-core-place           (end / chosen placement)
        └─ org-iw-write-put-rank :document t
org-iw-discovery.el
  identity: :ID: ▸ Denote filename identifier ▸ none
  org-iw-discovery-document-id (the one owner of document identity)
  org-iw-discovery--denote-identifier (soft-loads Denote once)
org-iw-write.el
  preflight + atomic apply; inserts an empty file-level drawer when the
  document has no slot; a document's emptied drawer goes on delete
```

A **document slot** exists when `point-min` is before the first heading:
there the file-level drawer is, or can be inserted by Org. A file that
starts with a heading has no slot until the write inserts an empty drawer
at `point-min` (research T2-3).

<!-- doctrine:section sec-05-2-interfaces -->
### 5.2 Interfaces & Contracts

**Discovery (`org-iw-discovery.el`)**

- `org-iw-discovery-document-slot-p ()` — *new.* Non-nil if the current
  buffer, widened, has text before its first heading (`point-min` is
  `org-before-first-heading-p`). The one owner of "does `point-min` hold
  the document's entry" (DEC-022).
- `org-iw-discovery-document-id (file)` — *new.* The identity of the
  current buffer's document, FILE being its truename: the file-level
  `:ID:` if the buffer has a slot and its drawer has one; else
  `org-iw-discovery--denote-identifier` of FILE; else nil. The one owner
  of document identity (DEC-021); it reads widened, wherever point is.
- `org-iw-discovery-title (file)` — *made public* (was
  `org-iw-discovery--title`): the title of the entry at point, so
  `--add-entry` can build its ENTRY through discovery (RV-012 F-7).
- `org-iw-discovery-entry-id (file)` — *changed signature.* The ID of the
  entry at point in FILE: at a heading, its `:ID:` (unchanged); before
  the first heading, `org-iw-discovery-document-id`. The scan passes its
  FILE, commands pass `org-iw--buffer-truename`. Callers: `--read-entry`,
  `org-iw--check-heading` (becoming `--add-entry`),
  `org-iw--scanned-entry-at`.
- `org-iw-discovery--denote-identifier (file)` — *new, private.* If
  Denote is available and `denote-file-has-denoted-filename-p` accepts
  FILE, return `denote-retrieve-filename-identifier`; else nil. The
  naming-scheme check alone: `denote-filename-is-note-p` is an obsolete
  alias of it since Denote 4.1.0, and the directory check
  (`denote-file-is-in-denote-directory-p`) creates directories (RV-012
  F-3). Availability: `(featurep 'denote)`, else, once per session, set
  `org-iw-discovery--denote-tried` and `(require 'denote nil t)` inside a
  `condition-case` that turns a load error into one `display-warning`.
  `declare-function` for both Denote functions.
- `org-iw-discovery--id-positions (id file)` — *changed.* The positions
  in the base buffer, widened, where ID occurs as an identity: its `:ID:`
  lines outside the file-level drawer (excluded by position, not
  value), plus `point-min` when `org-iw-discovery-document-id` is ID. So
  the file-level `:ID:` counts once, as `point-min`, and a heading that
  copies it counts again: a duplicate (REQ-007). `org-iw-discovery-id-count
  (id file)` and `org-iw-discovery-resolve` use it, so a Denote-identified
  document resolves to `point-min` and counts once.
  `org-iw-discovery-shared-id-p (scan id file)` passes FILE through.
- **Scan.** `--read-entry` passes FILE to `entry-id`. The per-file tally
  counts identities through the same owner: the heading `:ID:` lines plus
  the document's identity, so a heading whose `:ID:` equals the file's
  Denote identifier is a `duplicate-id`, and in a slotless file the first
  heading's `:ID:` is never mistaken for the document's.
  `--title` becomes public `org-iw-discovery-title`.
  `--drop-shared-ids` is unchanged: two member files with one Denote
  identifier are dropped and reported, as for `:ID:`.

**Write (`org-iw-write.el`)**

- `org-iw-write-put-rank (marker queue rank &key expected ensure-id
  document)` — *new key.* With DOCUMENT non-nil, MARKER must be at the
  base buffer's widened `point-min` (else an error: F-6). When the buffer
  has no document slot, EXPECTED must be `:absent` (else an error), the
  preflight's queue-line and drawer checks hold trivially, and the atomic
  edit inserts `:PROPERTIES:\n:END:\n` at `point-min` under
  `save-excursion`, then runs `org-id-get-create` (if ENSURE-ID) with
  point at `point-min`, then puts the rank at the marker (F-2). Without
  DOCUMENT, behaviour is unchanged. Save policy and results unchanged.
- `org-iw-write-delete-rank (marker queue &key expected)` — *changed
  rule.* For a document entry (MARKER at the widened `point-min` and
  `org-iw-discovery-document-slot-p`), the deletion may remove the
  emptied drawer; for a heading the drawer must survive, as now (F-1).
  Either way, nothing deleted is an error and rolls back.
- The commentary's "a marker at `point-min` for a document entry" is
  qualified: callers creating a document membership pass `:document t`.

**Core (`org-iw-core.el`)** — no change. Batch ranks come from
`org-iw-core-place … 'end` over an order extended by each added entry.

**Commands (`org-iw.el`)**

- `org-iw--require-source ()` — *new, extracted from
  `org-iw--target-at-point`.* Refuse unless the current buffer visits a
  source file in Org mode. Add and Add-document call it; the batch does
  not, having checked each FILE against its `sources` set once and
  calling `org-iw-discovery-require-org-mode` itself (RV-012 F-14: a
  per-file `org-iw--files` walk would cost minutes at 3,000 files).
- `org-iw--document-marker ()` — *new.* A marker at the widened
  `point-min` of the current buffer's base buffer; no checks (F-6).
  `org-iw--target-at-point` and Add-document compose it with
  `--require-source`.
- `org-iw--add-entry (scan order marker queue placement document)` —
  *new, replaces the body of `org-iw-add` and `org-iw--check-heading`.*
  Checks the target, places it, writes it. Returns plain data:
  `(existing POSITION)`, or `(added DEPTH STATUS ENTRY)`, ENTRY an
  `org-iw-entry` for the new member built after the write from
  `org-iw-discovery-entry-id`, the title and the placed rank. The checks
  read only through discovery: identity via `entry-id`
  (`document-id` for documents), queue lines only when the target has a
  slot or is a heading. Refuses as Add does today: excluded, ID shared,
  no room, write refusals. `:ensure-id` is passed only when the target
  has no identity, so a Denote note never gains an `:ID:`.
- `org-iw-add (queue &optional label)` — *changed.* Before the first
  heading it enrols the document; `org-iw--heading-or-refuse` is
  deleted. Docstring updated.
- `org-iw-add-document (queue &optional label)` — *new, autoloaded.* As
  `org-iw-add`, the target from `org-iw--require-source` then
  `org-iw--document-marker`. Prefix
  argument as Add's (DEC-011).
- `org-iw-add-files (queue files)` — *new, autoloaded.* FILES is a list
  of files and directories. Interactively: QUEUE as Add's; FILES from
  `dired-get-marked-files` in a dired buffer, else one file or directory
  from `read-file-name`. Runs the fold under `unwind-protect`, so the
  summary and report appear even after `C-g` (F-7). Returns the summary.
- `org-iw--batch-add (scan queue files sources progress)` — *new.* The
  fold. PROGRESS is a function of one argument (files done), called after
  each file; the command passes a progress reporter's update, tests pass
  `ignore` (F-10). Returns `(FILE . OUTCOME)` in canonical order, OUTCOME
  `(added STATUS)`, `(existing)` or `(failed REASON)`. It catches only
  `org-iw-refusal` and `file-error` per file (F-7); anything else is a
  bug and propagates after the outcomes so far are reported.
- `org-iw--batch-summary (queue outcomes)` and
  `org-iw--batch-report (queue outcomes)` — *new.* The echo summary
  text, and the `*org-iw batch*` buffer listing failed and unsaved files
  (a `special-mode` buffer), displayed only when there are any (DEC-028).

<!-- doctrine:section sec-05-3-data -->
### 5.3 Data, State & Ownership

- **Batch outcomes** are plain data, built by the fold and consumed by
  the summary and report. Example:

  ```elisp
  (("/n/journal/20260512T000000--tuesday__journal.org" added saved)
   ("/n/journal/20260513T000000--wednesday__journal.org" existing)
   ("/n/inbox.org" failed "not a source file")
   ("/n/journal/20260514T000000--thursday__journal.org"
    added (save-failed . (file-error …))))
  ```

- **New state:** `org-iw-discovery--denote-tried`, a private boolean in
  discovery, set before the one soft load of Denote is attempted. No
  other new state. No cache (DEC-027).
- **Ownership:** document identity → `org-iw-discovery-document-id`
  (with `entry-id`, `--id-positions` and the tally reading through it);
  document slot → `org-iw-discovery-document-slot-p`; drawer insertion
  and the document drawer-removal rule → write apply; file selection and
  canonical order → `org-iw-discovery-files`; ranks → core; the batch's
  in-run identity set and buffer opening/killing → the batch fold
  (DEC-026).

<!-- doctrine:section sec-05-4-dynamics -->
### 5.4 Lifecycle, Operations & Dynamics

**Add / Add-document**

1. Target: `org-iw--target-at-point` (Add) or `--require-source` +
   `--document-marker` (Add-document). DOCUMENT is non-nil when the target is the widened
   `point-min` and not a heading (Add), or always (Add-document).
2. Queue and label are validated before the scan (unchanged).
3. One scan in the body; order; `org-iw--add-entry`; message as today
   (`Added to J at 3/3 (saved)` / `Already in J at 2/5`).

**Batch add (`org-iw-add-files`)**

1. Validate QUEUE. `sources` ← `(org-iw--files)` as a set (which applies
   `org-iw-exclude-regexp`). `files` ← `(org-iw-discovery-files FILES
   nil)`: expanded, deduplicated, truename-sorted. Empty → "no Org files
   selected", nothing else.
2. One scan; `order` ← QUEUE's order; `added-ids` ← empty set.
3. For each FILE, then PROGRESS:
   1. Not in `sources` → `(failed "not a source file (outside
      org-iw-sources or excluded)")` (F-9).
   2. `had` ← `find-buffer-visiting`; buffer ← `org-iw-discovery-buffer`.
   3. In the buffer: `org-iw-discovery-require-org-mode`; the
      document's identity, if any, is in `added-ids` →
      `(failed "same ID as a file added in this batch")` (F-5); else
      `org-iw--add-entry scan order (org-iw--document-marker) queue 'end
      t`.
   4. `(added DEPTH STATUS ENTRY)` → outcome `(added STATUS)`;
      `order` ← `(append order (list ENTRY))`; ENTRY's ID into
      `added-ids`. `(existing _)` → `(existing)`.
   5. `org-iw-refusal` or `file-error` → `(failed MESSAGE)`; the loop
      continues. The atomic write has already rolled back its own edit.
   6. If the buffer was opened here (`had` nil) and is unmodified (saved,
      or untouched after a refusal or an existing membership), kill it. A
      modified opened buffer (save failed, or an Org hook dirtied it)
      stays open and its outcome says so (DEC-026).
4. Summary in the echo area, also after `C-g` or an unexpected error:
   `Added 70 to Journal, 3 already present, 1 failed, 0 unsaved (not
   atomic; see *org-iw batch*)`. The report buffer is shown only when
   something failed or is unsaved. The session is untouched.

Only the first of two selected copies sharing an identity is added; the
second is refused, so the queue keeps one valid member (a non-member
copy is never scanned, so it causes no `duplicate-id`).

**Remove a document's last membership**

`org-iw-write-delete-rank` deletes the `IW_` line; Org deletes the
emptied drawer; for a document that is accepted, so the file returns to
its text before Add (undo restores it).

Example over the user's journal: 74 files without drawers gain

```org
:PROPERTIES:
:IW_JOURNAL: 1024
:END:
#+title: 2026-05-12 Tuesday
```

and each next file's rank is 1024 more.

<!-- doctrine:section sec-05-5-invariants -->
### 5.5 Invariants, Assumptions & Edge Cases

Invariants:

- **I1** A document's headings never become members by its membership
  (REQ-002).
- **I2** A file named by Denote's scheme (Denote available) never gains
  an `:ID:` from org-iw.
- **I3** Adding to a document in a file that starts with a heading
  changes only the inserted drawer and its lines; the heading's text and
  drawer are byte-identical (REQ-004), with or without `:ensure-id`.
- **I4** The batch body scans once (the interactive queue prompt scans
  too, IMP-002); ranks are strictly increasing in canonical order across
  the files it added.
- **I5** A batch never kills a buffer that existed before it, nor one it
  left modified.
- **I6** One file's failure leaves the others' outcomes as they would be
  alone.
- **I7** A document that leaves its last queue keeps no `IW_` drawer of
  org-iw's making; a heading keeps its drawer.

Assumptions:

- **A1** Denote's `denote-file-has-denoted-filename-p` and
  `denote-retrieve-filename-identifier` keep their 4.x contracts.

Edge cases:

- Denote not installed: identity is `:ID:` only; Add inserts one.
- Denote installed but failing to load: one warning; identity as if
  absent.
- Denote loaded later in the session: `featurep` picks it up at the next
  scan.
- A session without Denote: Denote-identified members are `missing-id`
  and leave the queue until Denote is available (DEC-021 consequence).
- A file named by Denote's scheme outside `denote-directory`: still
  Denote-identified (naming scheme only).
- A document gains an `:ID:` after enrolment (e.g. org-roam): its
  identity switches to that ID; its membership is untouched; a live
  session naming the old identity reports it gone (REQ-015 path).
- A Denote note and a heading in it with the same ID → `duplicate-id`.
- Two member files with one Denote identifier → both `duplicate-id`,
  excluded; in a batch, the second of two selected copies fails.
- A file with a drawer after `#+title:` → unrecognised drawer, failed
  (existing preflight).
- A selected file that is open with unsaved edits → added, `unsaved`,
  listed in the report.
- A selected file open narrowed → the document target widens.
- No room at the end (rank limit) → that file and the rest fail with the
  no-room message; redistribution is SL-006.
- Empty file → a drawer is inserted at `point-min` (research T2-1).
- Batch placement is quadratic in queue length (append + place per
  file): 3,000 files ~1.6 s (RV-012 F-13); noted under IMP-010.

<!-- doctrine:section sec-06-open -->
## 6. Open Questions & Unknowns

None blocking. Deferred: scan performance at thousands of members
(IMP-010, with IMP-002); `CUSTOM_ID` heading identity (IDE-002).

<!-- doctrine:section sec-07-decisions -->
## 7. Decisions, Rationale & Alternatives

| ID | Decision | Rejected |
|---|---|---|
| DEC-021 | Identity: file-level `:ID:` ▸ Denote filename identifier (soft-loaded Denote, naming-scheme check) ▸ inserted `:ID:`; `#+identifier:` never read; one owner `org-iw-discovery-document-id` | Org ID only; `#+identifier:`; copied Denote regexps; `fboundp` only; the obsolete `denote-filename-is-note-p` |
| DEC-022 | `:document` flag on put-rank; the write inserts a missing drawer without moving point; one slot predicate in discovery; a document's emptied drawer goes on delete | target struct through every reader; insert before preflight |
| DEC-023 | `org-iw-add-document`; Add before the first heading enrols the document | `C-u C-u`; numeric prefix |
| DEC-024 | `org-iw-add-files`: dired marks, else a file/directory prompt; `org-iw-discovery-files` order; non-sources fail | wildcard prompt; CRM over sources; dired only |
| DEC-025 | Batch appends only | batch placement |
| DEC-026 | Batch kills buffers it opened if unmodified when done (saved, refused or existing); single commands keep DEC-004 | keep all open; kill in every command |
| DEC-027 | No cache; one scan per batch; per-file scan results | cache now; shared Org buffer |
| DEC-028 | Progress reporter; echo summary; report buffer on failure/unsaved | echo only; always a buffer |

<!-- doctrine:section sec-08-risks -->
## 8. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Identity reader change breaks heading paths | `entry-id`'s heading branch is unchanged; the full existing suite runs; I1–I3 tests |
| Denote presence differs between test Emacsen (31's site-lisp has Denote 4.2.3 under `-Q`; 30's has none), so results could depend on the binary | Existing fixtures use no Denote-scheme names (checked), so they behave identically. Denote-route tests use Denote-scheme names and `skip-unless` Denote loads; the justfile puts `ORG_IW_DENOTE_DIR` (dev shell) on the load path so both binaries run them. A Denote-absent case uses a Denote-scheme name with `features` bound without `denote` and `org-iw-discovery--denote-tried` bound to t. Byte-compile sees only `declare-function`, so an obsolete Denote name would not warn: the Denote-route tests are the check that the named functions exist and behave |
| Org hooks dirty a freshly opened buffer, so it isn't saved or killed | Outcome `unsaved`; buffer kept; report lists it |
| A batch over thousands of files is slow under the user's config | Progress reporter; one scan; measured in the VH trial |
| Partial batch leaves the corpus half-enrolled | Report lists every failure; rerun is idempotent (existing → no-op); Git |

<!-- doctrine:section sec-09-quality -->
## 9. Quality Engineering & Validation

ERT, on Emacs 30 and 31, over the shared corpus fixture (STD-001/004):

- **Discovery:** `document-id` with a file-level `:ID:`, with only a
  Denote-scheme name (Denote loaded), with neither, and with Denote
  absent; a heading-first Denote note whose first heading has an `:ID:`
  (the document's identity is the Denote one, F-4); `document-slot-p`
  both ways; `--id-positions` / `id-count` / `resolve` for a
  Denote-identified document; duplicate Denote identifiers across member
  files; heading `:ID:` equal to the file's Denote identifier; a Denote
  load error warns once; I1 for a member document with headings.
- **Write:** `:document t` on a heading-first file, with `:ensure-id` and
  the heading with and without an `:ID:`: the drawer and the document's
  `:ID:` are inserted, the heading is byte-identical (I3, F-2); undo
  restores the file; a marker not at the widened `point-min`, or a
  non-`:absent` EXPECTED without a slot, is an error; delete of a
  document's last `IW_` line removes the drawer, and undo restores it
  (I7, F-1); a heading's rank-only drawer still errors; existing
  behaviour unchanged without `:document`.
- **Add / Add-document:** before the first heading; Add-document from a
  heading and from a narrowed buffer (F-6); Denote note gains no `:ID:`
  (I2); non-Denote file gains one (REQ-011 AC3); existing document →
  no-op (AC4); queue B untouched (AC5); placement prefix.
- **Remove / Continue → Remove** of a Denote document member, its last
  queue (F-1).
- **Batch:** canonical order regardless of selection order (REQ-012 AC1);
  existing reported unchanged (AC2); a failure mid-run (unwritable file,
  non-source, excluded by `org-iw-exclude-regexp` with its own reason)
  with the rest processed (AC3, I6); two selected copies with one
  identity → the second fails (F-5); the summary says not atomic (AC4);
  dirty pre-existing buffer → unsaved; a save-failed opened buffer kept
  and reported (REQ-021 AC4, I5); opened buffers killed, pre-existing
  kept; a narrowed pre-existing buffer gets its drawer at the top (F-6);
  I2 across a batch; one scan in the body (I4, counted by advising
  `org-iw-discovery-scan` around a Lisp call); report buffer only on
  trouble; summary still produced when a file's step signals a non-caught
  error (F-7).
- **Lint:** `just lint` clean; `just test-all` green.

**VH trial (POL-003):** on a Git copy of `~/notes`, batch-enrol the
journal directory from dired; inspect the queue; Visit and Continue a few
times; `git diff` shows one drawer per file and no `:ID:` lines; undo one
document add.

<!-- doctrine:section sec-10-code-impact -->
## 10. Code Impact

- `org-iw-discovery.el` — identity (`document-id`, `entry-id`,
  `--id-positions`, `id-count`, `shared-id-p`, tally), `document-slot-p`,
  `--denote-identifier`.
- `org-iw-write.el` — `:document` key, drawer insertion, the document
  drawer-removal rule in delete, commentary.
- `org-iw.el` — `--require-source`, `--document-marker`, `--add-entry`, Add, Add-document,
  Add-files, batch fold,
  summary and report; delete `--heading-or-refuse`, fold
  `--check-heading` into `--add-entry`; callers of `entry-id` pass FILE.
- `test/org-iw-discovery-test.el`, `test/org-iw-write-test.el`,
  `test/org-iw-test.el`, `test/org-iw-test-helpers.el` (Denote corpus
  helper).
- `justfile`, `flake.nix` — Denote on the test load path.
- `README.md` — document entries, Denote identity, batch add.

