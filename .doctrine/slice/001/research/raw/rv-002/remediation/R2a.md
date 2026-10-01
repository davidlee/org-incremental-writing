# R2a work sheet: POL-002 DRY and legibility (RV-002)

Repo `/workspace/org-incremental-writing`, main worktree. Start from HEAD 5846207 (R1 landed), clean.
SL-001 is in `audit`. This is NOT a plan phase: no phase sheet, no phase status flip, no `doctrine review`
write verb, no edit to `.doctrine/slice/001/design.md` (LOCKED) or any other authored state. **Do not commit.**

Findings: `doctrine review show RV-002`. Full detail and rulings: `.doctrine/review/002/review-002.toml`
(each finding's `response` is binding). Here: F-6, F-7, F-8, F-9, F-10, F-12, F-13, F-14, F-16.
R2b (ADR-003 ownership: F-2, F-11, F-15, G10) runs AFTER this sheet, on your tree. Do not do R2b work here.

Contract: behaviour-neutral, with these deliberate exceptions:
- put-rank's QUEUE contract narrows to canonical IDs (F-8, public API change);
- put-rank checks RANK (F-6);
- resolve's refusal causes are reworded so "ID" is not said twice (F-7).

## Standing constraints

- ADR-003 direction: core <- discovery <- write <- org-iw. A layer calls only downwards. Core loads no Org.
- POL-002: one implementation per concept. Before adding a function, grep for an existing one.
- POL-001: `just lint` has zero warnings. Lint each file as you go (`just compile checkdoc` after each edit, full `just lint` at step ends).
- 2-space indentation (Emacs Lisp default indentation). Small pure functions, good names, honest docstrings.
- Red/green/refactor for every behaviour change. Show red before green.
- Run `just test </dev/null` after every step. The `</dev/null` matters: a regression that reaches a `yes-or-no-p` save prompt hangs on an open stdin instead of failing (notes.md § PHASE-05, F-4 red proofs).

## What to know first (distilled; cite to pull more)

- Refusal messages use `format`, never `format-message`, because the latter curls the apostrophe in "doesn't". `org-iw-core-refuse` must keep `format` (notes.md § PHASE-06 "Messages").
- `plan.toml` VT keywords are matched literally in test files by `doctrine slice verify-vt SL-001`. Do not delete or reword a test string that is a keyword. The ones near this work are PHASE-05 VT-2 in `test/org-iw-write-test.el` (`org-iw-refusal`, `make-indirect-buffer`, `set-file-modes`, `:expected`) and PHASE-06 VT-2 in `test/org-iw-test.el` (`"property drawer Org doesn't recognise"`, `"ID shared with another heading"`, ...). In PHASE-06 a helper move silently dropped a keyword (notes.md § PHASE-06 "Trap").
- `org-with-point-at` (Org 9.8.10) expands to `(save-excursion (set-buffer (marker-buffer m)) (org-with-wide-buffer (goto-char m) BODY))`, which is equivalent to the hand-rolled forms. The reviewer checked this on Org 9.7.11 and 9.8.10 (RV-002 F-10).
- `(cl-check-type x (satisfies PRED))` signals `(wrong-type-argument PRED VALUE x)`, so the predicate's name is the error's legible part. Checked in this jail.
- `string-to-number` on a long digit string returns a bignum, not a float. The limit predicate still rejects it.
- `just test-each` (R1) runs every test in its own Emacs. Optional, but cheap insurance after renames.
- TDD discipline: a test that was never red proves nothing. Existing green tests are the behaviour-preservation gate, so a refactor must not rewrite them to fit (mem.pattern.doctrine.tdd-loop).

## Anchors (HEAD 5846207; production unchanged since the review, so the review's line numbers hold)

- `org-iw-core.el`: `:41` define-error; `:58-65` `org-iw-core-queue-id`; `:67-78` `classify-property` (`:74` `string-match`); `:80-89` `parse-rank` (`:89` limit test); `:117-127` `append-rank` (`:127` limit test).
- `org-iw-discovery.el`: `:347-353` `org-iw-discovery-buffer`; `:355-363` `--id-positions` (`:360` base-buffer expression); `:371-373` `--refuse`; `:389-390`, `:393`, `:399-400` resolve's WHAT strings.
- `org-iw-write.el`: `:40-44` `--base`; `:46-52` `--refuse`; `:65-82` `--preflight` (`:77-80` hand-rolled point-at); `:84-101` `--apply` (`:92-95`); `:103-138` `put-rank` (docstring `:106-120`, `:127` check-type, `:128-130` canonicalise-or-refuse).
- `org-iw.el`: `:90-92` `org-iw--refuse`, called at `:134 :143 :215 :218 :274 :285 :288 :386 :387 :418`; `:102-107` `--buffer-truename`; `:131-134` `--queue-id`; `:189-191` `defvar org-iw--session`; `:265-288` `--check-heading` (docstring `:266-269`, `:270-272` hand-rolled point-at); `:307-308` the `org-iw-add` interactive spec; `:326-352` `--visit` (`:343-350` session/mode line); `:432-441` `moved`; `:446-458` `org-iw-end-session`.
- Tests: `test/org-iw-core-test.el` `:86` parse-rank-rejects, `:93` rank-limit-literal, `:140` append-rank-limit. `test/org-iw-write-test.el` `:79-92` saves-clean-buffer (passes `"essays"` at `:83`), `:203-208` refuses-invalid-queue, `:210-215` expected-is-checked.

Re-grep before editing (`grep -n` the symbol). If anything has drifted, anchor on content.

## Decisions (names, signatures, rationale)

| Item | Decision | Why |
|---|---|---|
| F-7 | `(org-iw-core-refuse FORMAT-STRING &rest ARGS)` in core, directly after the `define-error`. Body: `(signal 'org-iw-refusal (list (apply #'format format-string args)))`. | The error's owner owns its constructor. Core is the only layer all three share. |
| F-7 | Delete `org-iw--refuse` and call `org-iw-core-refuse` at its 10 call sites. | Its prefix is empty, so a wrapper would be a second name for one thing (POL-002). |
| F-7 | `org-iw-write--refuse MARKER FORMAT-STRING &rest ARGS` stays and becomes `(org-iw-core-refuse "%s: %s" FILE (apply #'format format-string args))`. `org-iw-discovery--refuse WHAT ID FILE` stays as `(org-iw-core-refuse "ID %s in %s: %s" id file what)`. | Each layer keeps only its prefix, as ruled. |
| F-7 | **Fix the repeated "ID".** Resolve's WHAT strings become `"duplicated, excluded from the queue"`, `"not found"`, `"ambiguous, more than one heading"`, so the message reads "ID x1 in /…/a.org: not found". | Today it says "ID x1 in /…/a.org: ID not found", repeating "ID" (review F-7 detail, `:390`). The discovery tests match the regexps `"not found"`, `"duplicate"` and `"ambiguous"` (`org-iw-discovery-test.el:695-748`), and `org-iw-test.el:640` matches `"ambiguous"`. All stay green unedited. README quotes none of these. |
| F-8 | The one owner of canonicalise-or-refuse is `org-iw--queue-id` (`org-iw.el:131`), unchanged. Write stops canonicalising. | Only commands receive user-typed IDs. Core keeps the pure `org-iw-core-queue-id`. |
| F-8 | New core predicate `(org-iw-core-canonical-queue-id-p OBJECT)`: `(and (stringp object) (equal (org-iw-core-queue-id object) object))`. It goes after `org-iw-core-queue-id`. put-rank does `(cl-check-type queue (satisfies org-iw-core-canonical-queue-id-p))`. A non-canonical QUEUE is `wrong-type-argument`, not a refusal. | Same form as EXPECTED's `cl-check-type`. A caller error is a type error, not user-facing state. It delegates to `org-iw-core-queue-id`, so the rule has one implementation. |
| F-6 | New core predicate `(org-iw-core-rank-p OBJECT)`: `(and (integerp object) (<= (abs object) org-iw-core-rank-limit))`. It goes directly before `org-iw-core-parse-rank`. `parse-rank` ends `(and (org-iw-core-rank-p rank) rank)`. `append-rank` ends `(and (org-iw-core-rank-p rank) rank)`. | One limit test for all three, as ruled (POL-002). |
| F-6 | put-rank does `(cl-check-type rank (satisfies org-iw-core-rank-p))`. **An out-of-limit RANK is a type error** (`wrong-type-argument`), like a non-integer. | Every caller takes RANK from `append-rank`, which already refuses at the limit. An out-of-limit RANK reaching put-rank is a programming error, as with EXPECTED, not a user-recoverable state. A refusal would claim the user can act on it. |
| F-9 | New public `(org-iw-discovery-base-buffer &optional BUFFER)`: "Return the base buffer of BUFFER, or BUFFER if it is not indirect." BUFFER defaults to the current buffer. It goes directly before `org-iw-discovery-buffer`, and each docstring cross-references the other. | It is discovery's concept (resolve and id-count already rely on it). A buffer argument suits all three sites: write has a marker's buffer, the commands and `--id-positions` the current buffer. |
| F-9 | Delete `org-iw-write--base`. Write calls `(org-iw-discovery-base-buffer (marker-buffer marker))` at its 3 sites (`--refuse`, `--preflight`, `--apply`). `org-iw--buffer-truename` uses `(org-iw-discovery-base-buffer)`, and so does `--id-positions`. | A marker wrapper would be a second helper for the same concept. |
| F-9 | `org-iw-test-base` (test/org-iw-test-helpers.el:239) does **not** delegate. Add one docstring sentence: "Deliberately independent of `org-iw-discovery-base-buffer`: tests use it as an oracle." | An oracle that calls the code under test cannot catch that code being wrong. Consolidating test capture helpers is IMP-003 (F-24 follow-up), so leave the rest alone. |
| F-10 | `org-with-point-at marker` at write `:77-80` and org-iw `:270-272`. At `--apply` `:92-95`: `(with-current-buffer (marker-buffer marker) (atomic-change-group (org-with-point-at marker (funcall fn))))`. | Ruled. The outer `with-current-buffer` stays because `atomic-change-group` records the current buffer. |
| F-12 | `(org-iw--session-start QUEUE ENTRY)` sets `org-iw--session` from ENTRY's id and title, wraps a non-list `global-mode-string`, `add-to-list`s the construct and forces a mode-line update. `(org-iw--session-end)` returns the ended session (or nil), clears the variable, deletes the construct when the value is a list, and forces an update. Both go in `;;;; Session` after `org-iw--mode-line`. | One owner of the session and its mode-line item. `--visit` loses two jobs. Taking ENTRY keeps the struct construction inside the owner. This is the seam IMP-001 will use; do not implement IMP-001. |
| F-12 | `org-iw--visit` calls `(org-iw--session-start queue entry)`. `org-iw-end-session` becomes `(message (if (org-iw--session-end) "org-iw session ended" "No org-iw session"))`, with `(interactive)` and the docstring unchanged. The defvar docstring becomes "Set only by `org-iw--session-start'; cleared only by `org-iw--session-end'." | Return values and messages are unchanged. |
| F-13 | `--check-heading` docstring, self-contained, citing no design steps: "Refuse unless the heading at MARKER may join QUEUE, a canonical queue ID. ORDER is QUEUE's members in SCAN. Refuse if Org does not recognise the heading's property drawer, if the heading has an IW_ line for QUEUE but is not in ORDER (the scan excluded it), or if another heading has its ID. Return the heading's 1-based position in ORDER if it is already a member, else nil." Adjust wording for checkdoc. | Ruled. (R2b removes the drawer clause.) |
| F-14 | Above the `(interactive (progn (org-iw--add-target) …))` at `org-iw.el:307`, add the comment `;; Called for its refusals: a buffer or point Add cannot use fails before the prompt.` It is the only spec that calls `--add-target` for effect. | Self-contained, with no "steps 1-3" (that kind of design citation is F-13's complaint). |
| F-16 | `moved` -> `save-status` (`org-iw.el:432`, used at `:438-439`). It holds the save-status text of the move, or nil when the entry was already last. `string-match` -> `string-match-p` at `org-iw-core.el:74`. Do NOT rename `org-iw-discovery-buffer`. | Ruled. A local `save-status` beside a call to `org-iw--save-status` reads fine in a Lisp-2. |

The public surface added here is `org-iw-core-refuse`, `org-iw-core-rank-p`, `org-iw-core-canonical-queue-id-p` and `org-iw-discovery-base-buffer`. Each has a cross-file caller.

## Steps (run `just test </dev/null` after each; lint each edited file)

1. **F-16** (warm-up, neutral). Make the two edits. Run `just test`.
2. **F-7** (neutral apart from the reworded causes). Add `org-iw-core-refuse`. Rewire `org-iw-write--refuse` and `org-iw-discovery--refuse`. Delete `org-iw--refuse` and replace its 10 calls (`grep -n 'org-iw--refuse\b'`; note that `org-iw--refuse-absent` is a different function and stays). Reword the three resolve causes. Run `just test`. All green with no test edit. If one goes red, a test asserts the old wording: report it, don't loosen it silently.
3. **F-9**. Add `org-iw-discovery-base-buffer`. Replace the 5 uses. Delete `org-iw-write--base`. Add the docstring sentence to `org-iw-test-base`. Then `grep -n 'buffer-base-buffer' org-iw*.el` must show only the new function. Run `just test`.
4. **F-10**. Make the three rewrites. The indirect/narrowed tests are the gate: `org-iw-write-test-writes-through-indirect-buffer`, `-ensure-id-through-narrowed-indirect`, `-refuses-changed-on-disk-indirect`, and the Add indirect tests. Run `just test`.
5. **F-6**, test-first.
   - a. Core red: add `org-iw-core-test-rank-p` to `test/org-iw-core-test.el` after `-rank-limit-literal` (`:93`), with literal bounds (R1 pinned them). Accept `0`, `-5`, `9007199254740991`, `-9007199254740991`. Reject `9007199254740992`, `-9007199254740992`, `1.5`, `"1024"`, `nil`. Red: `void-function org-iw-core-rank-p`. Green: add the predicate. Refactor `parse-rank` and `append-rank` onto it. The existing `parse-rank-*`, `rank-limit-literal` and `append-rank-limit` tests must stay green unedited.
   - b. Write red: add `org-iw-write-test-rank-is-checked` after `-expected-is-checked` (`:210`). On `org-iw-write-test--target`, for each RANK in `(1.5 "3072" nil 9007199254740992)`, `(should-error (org-iw-write-put-rank marker "ESSAYS" rank :expected 2048) :type 'wrong-type-argument)`, and `org-iw-test-snapshot` must be unchanged. Use a fresh corpus per value or an `org-iw-test-snapshot` comparison inside one corpus. Under red, 1.5 is written and saved, so the corpus changes. Red today: 1.5 returns `saved`, so `should-error` fails. Record that failure. Green: the `cl-check-type`. Docstring: replace "RANK is an integer, written as is: callers take it from `org-iw-core-append-rank', which checks the limit." with "RANK is an integer of magnitude at most `org-iw-core-rank-limit', as from `org-iw-core-append-rank'; anything else is an error."
   - Run `just test`.
6. **F-8**, test-first.
   - a. Core red: add `org-iw-core-test-canonical-queue-id-p` after `-queue-id` (`:49`). Accept `"ESSAYS"`, `"AFTER-X"`. Reject `"essays"`, `"Essays"`, `"ESS_AYS"`, `""`, `nil`. Red: void-function. Green: the predicate.
   - b. Write red: replace `org-iw-write-test-refuses-invalid-queue` (`:203-208`) with `org-iw-write-test-queue-is-checked` ("QUEUE must be a canonical queue ID; anything else is an error, before anything changes."). For `"ESS_AYS"`, `"essays"` and `nil`: `should-error … :type 'wrong-type-argument`, snapshot unchanged. Red today: `"essays"` returns `saved`, and `"ESS_AYS"` signals `org-iw-refusal`, not `wrong-type-argument`. Record that.
   - c. In `org-iw-write-test-saves-clean-buffer` (`:83`), change `"essays"` to `"ESSAYS"`. That test is about the save (I4), and lowercase was incidental to the old any-case contract. This edit is needed by the contract change, not a fit-the-test rewrite. Say so in the hand-back.
   - d. Green: in put-rank, add `(cl-check-type queue (satisfies org-iw-core-canonical-queue-id-p))` beside the EXPECTED check, delete the `queue-id` let (`:128-130`) and use `queue` throughout. Docstring: "QUEUE is a canonical queue ID, as from `org-iw-core-queue-id'; anything else is an error." Remove "QUEUE is not a valid queue ID" from the refusal list.
   - e. Confirm both put-rank callers pass canonical IDs (`org-iw.el:318` `queue-id`, `:396` the session's canonical queue). `grep -n 'invalid queue ID' org-iw*.el` must show exactly one hit (`org-iw--queue-id`). The Add/Visit invalid-queue tests (`org-iw-test.el:254`, `:722`) stay green.
   - Run `just test`.
7. **F-12** (neutral). Extract the pair and rewire `--visit` and `org-iw-end-session`. Then `grep -n 'setq org-iw--session\|global-mode-string' org-iw.el` should show assignments only inside the pair (the defvar and the `--mode-line` read aside). Run `just test`: the mode-line, end-session and non-list `global-mode-string` tests are the gate (`org-iw-test.el:486-505`, `:770`, `:784`).
8. **F-13, F-14** (docstring and comment only). Run `just lint`.
9. **Notes** (below), then the **exit gate**.

Expected test-count delta: +3 tests (`core-test-rank-p`, `core-test-canonical-queue-id-p`, `write-test-rank-is-checked`). One is renamed (`write-test-refuses-invalid-queue` -> `-queue-is-checked`). So 143 -> 146.

## Tests that change, and why

- `org-iw-write-test-refuses-invalid-queue` -> `org-iw-write-test-queue-is-checked`: the contract narrowed (F-8). A non-canonical QUEUE is a type error, not a refusal.
- `org-iw-write-test-saves-clean-buffer`: `"essays"` -> `"ESSAYS"`. The old any-case contract is gone (F-8).
- New: `org-iw-core-test-rank-p`, `org-iw-core-test-canonical-queue-id-p`, `org-iw-write-test-rank-is-checked`.
- `org-iw-test-base`: docstring only.
- No other test may change. If one must, stop and report why.

## notes.md edits (append only; do not rewrite existing text)

Under `## Audit remediation (RV-002)`, after the R1 entry, add `### R2a — POL-002 DRY and legibility`. List per F-n what changed (names), the new tests, the red evidence (one line each), the resolve rewording, the `org-iw-test-base` decision, and the gate counts.

Under `## Design deltas for /reconcile`, append these lines. Citation rule: write "user ruling 2026-10-01" only where the ledger `response` says "User ruled" (F-7, F-8, F-9). For F-6 and F-12, write "RV-002 F-n fix-now disposition 2026-10-01".
- § 5.1 / § 5.2 core (RV-002 F-7, user ruling 2026-10-01): core gains `org-iw-core-refuse FORMAT-STRING &rest ARGS`, the one `org-iw-refusal` constructor (uses `format`). Write keeps a "FILE: " prefix and discovery an "ID X in FILE: " prefix. The command layer calls it directly. Resolve's causes now read "duplicated, excluded from the queue", "not found" and "ambiguous, more than one heading".
- § 5.2 `org-iw-write-put-rank` (RV-002 F-8, user ruling 2026-10-01): QUEUE must be canonical (`org-iw-core-canonical-queue-id-p`), else `wrong-type-argument`, as for EXPECTED. The "invalid queue ID" refusal has one owner, `org-iw--queue-id` in org-iw.el, which § 5.2's private-helper list gains.
- § 5.2 core and put-rank (RV-002 F-6 fix-now disposition 2026-10-01): core gains `org-iw-core-rank-p`, the one limit test, used by `parse-rank`, `append-rank` and put-rank's `cl-check-type` on RANK. An out-of-limit or non-integer RANK is `wrong-type-argument`. This supersedes PHASE-05 gap 5's "RANK not range-checked".
- § 5.2 discovery, write preflight, `org-iw--source-file-p` (RV-002 F-9, user ruling 2026-10-01): `(or (buffer-base-buffer b) b)` is `org-iw-discovery-base-buffer &optional BUFFER`, the one base-buffer helper. `org-iw-write--base` is gone.
- § 5.3 Session (RV-002 F-12 fix-now disposition 2026-10-01): set only by `org-iw--session-start QUEUE ENTRY` (called by `org-iw--visit`) and cleared only by `org-iw--session-end` (called by `org-iw-end-session`). The pair owns the `global-mode-string` item.
- (F-10, F-13, F-14, F-16 are code-only. No delta.)

## Exit gate (all must hold)

1. `just lint`: zero warnings (compile, checkdoc, package-lint, relint).
2. `just test-all </dev/null`: green on Emacs 31.1 and 30.2. Record counts (expect 146).
3. Optional: `just test-each </dev/null` passes.
4. `git status`: only `org-iw-core.el`, `org-iw-discovery.el`, `org-iw-write.el`, `org-iw.el`, `test/org-iw-core-test.el`, `test/org-iw-write-test.el`, `test/org-iw-test-helpers.el` and `.doctrine/slice/001/notes.md` changed. Not committed.
5. Greps: `buffer-base-buffer` only in `org-iw-discovery-base-buffer`. `(signal 'org-iw-refusal` only in `org-iw-core-refuse`. `invalid queue ID` once, in `org-iw--queue-id`. No `org-iw--refuse\b` and no `org-iw-write--base`.

## If blocked

- If a ruling cannot be met behaviour-neutrally, or two items conflict, stop and report with a proposed default. Do not improvise a design change.
- Do not touch F-1/F-3 (read-only and non-Org-mode refusals), F-5/IMP-002 (double scan), the `org-iw--visit` POS/TOTAL arguments (R1 note), or R2b items.

## Hand-back (required)

- Per F-n: done / not done, the names introduced or removed, test names, and red evidence (command, failing assertion, the observed wrong result) for F-6 and F-8.
- Gate tails: `just lint` summary, and the `just test-all` result lines for 31.1 and 30.2 (counts).
- Files changed (`git status --short`).
- Deviations from this sheet, with reasons. Friction (tooling, lint, flaky tests).
- Model echo: your model name/id.
