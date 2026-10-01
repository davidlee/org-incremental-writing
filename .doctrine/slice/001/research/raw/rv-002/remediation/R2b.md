# R2b work sheet: ADR-003 ownership (RV-002)

Repo `/workspace/org-incremental-writing`, main worktree. **Precondition: R2a has landed**
(`/home/scratch/sl-001-review/remediation/R2a.md`; the orchestrator commits it before you start). Check with
`grep -n 'org-iw-core-refuse\|org-iw-discovery-base-buffer\|org-iw-core-rank-p' org-iw*.el`. If R2a is
absent, STOP and report.

SL-001 is in `audit`. This is NOT a plan phase: no phase sheet, no phase status flip, no `doctrine review` write
verb, no edit to `.doctrine/slice/001/design.md` (LOCKED) or any other authored state. **Do not commit.**

Findings: `doctrine review show RV-002`. Rulings: `.doctrine/review/002/review-002.toml` (`response`, binding).
Here: F-15, F-11, F-2, and the closure of logged delta G10 (`.doctrine/slice/001/notes.md`, "§ 5.1 / ADR-003
(G10)"). Contract: behaviour-neutral, except that F-2 adds a write refusal and F-15 widens core's
classification. Both are user rulings.

## Standing constraints

- ADR-003 direction: core <- discovery <- write <- org-iw. Core loads no Org. A layer calls only downwards.
- POL-002: one implementation per concept. A move is a move: delete the old definition in the same step.
- POL-001: `just lint` has zero warnings. Lint each file as you go (`just compile checkdoc` after each edit).
- 2-space indentation (Emacs Lisp default). Small pure functions, good names, honest docstrings.
- Red/green/refactor for every behaviour change. Show red before green.
- `just test </dev/null` after every step. Without `</dev/null`, a regression that reaches a save prompt hangs instead of failing (notes.md § PHASE-05).
- Public surface: promote only what is called across files. Each public docstring must be true for every caller, not just the one it came from.

## What to know first (distilled; cite to pull more)

- **Malformed-drawer semantics** (notes.md § PHASE-06 Outcomes; design § 5.4 Add step 4). The line test is Org's `org-property-start-re`, the same on Org 9.7.11 and 9.8.10. The section ends at `outline-next-heading` (point-max for the last heading), and both ends are tested. Inside an unrecognised drawer, `org-at-property-p` fails, so its `:ID:` and `:IW_` lines are invisible to `org-iw-discovery-entry-id`, the ID-line matcher and `queue-lines`. The scan reports such an IW line as `misplaced-property`.
- **R1 probes guard this move** (notes.md § Audit remediation R1). `org-iw-cmd-test-add-drawerless-before-drawer-heading` (B2) catches a drawer search not bounded at the next heading. `org-iw-cmd-test-add-refuses-nonmember-shared-id-in-file` (A1) catches a lost same-file id-count clause. Both must stay green unedited.
- **VT keywords are literal** (`doctrine slice verify-vt SL-001`). PHASE-06 VT-2 needs `"property drawer Org doesn't recognise"` in `test/org-iw-test.el` (`org-iw-cmd-test-add-refuses-malformed-drawer`, `:264`). Keep that substring in the message and in the test. PHASE-03 VT-2 needs `"IW_ESSAYS+"` and `"duplicate-property"` in `test/org-iw-discovery-test.el`, and PHASE-02 VT-1 needs `"iw_essays"` and `"IW_AFTER-X"` in `test/org-iw-core-test.el`.
- **Refusals** are built with `org-iw-core-refuse`, which uses `format`, not `format-message` (R2a). The apostrophe in "doesn't" must stay straight.
- `org-with-point-at MARKER` = set buffer, widen, go to MARKER (R2a F-10). Preflight already reads `queue-lines` inside one.
- Discipline: existing green tests are the behaviour-preservation gate for a move. Do not rewrite them to fit (mem.pattern.doctrine.tdd-loop).

## Anchors (production line numbers as of HEAD 5846207; R2a shifts them, so re-grep by symbol)

- `org-iw-core.el` `org-iw-core-classify-property` (`:67-78`).
- `org-iw-discovery.el`: `--iw-lines` `:135-154`; `--line-class` `:156-166`; `--queue-lines` `:168-177`; `--classify-lines` `:179-209` (calls `--line-class` at `:190`); `--entry-id` `:220-223` (called at `:229`); `--in-block-p` `:245-248`; `--excluded-id-p` `:375-380` (called at `:389`); `org-iw-discovery-id-count` `:365-369`.
- `org-iw-write.el`: `--expected-p` docstring names `org-iw-discovery--queue-lines` (`:56`); `--preflight` `:65-82` (call at `:80`).
- `org-iw.el`: `--problem-types` `:222-234`; `--unrecognised-drawer-p` `:236-251`; `--shared-id-p` `:253-263`; `--check-heading` `:265-288`; `--refuse-absent` `:380-388` (call at `:385`).
- Tests: `test/org-iw-core-test.el` `org-iw-core-test-classify-property` `:56-71` (`"IW_ESSAYS+"` in the invalid list at `:68`). `test/org-iw-write-test.el` Compare-and-set section `:174-232`, with `--should-refuse` helper `:38-51`. `test/org-iw-test.el` Add refusal tests `:233-375`.

## G10: every cross-file `--` call at HEAD, and its fate

`grep -noE 'org-iw-(discovery|write)--[a-z-]+' org-iw.el org-iw-write.el`:

| Site | Private | Replacement |
|---|---|---|
| write `:56` (docstring), `:80` | `org-iw-discovery--queue-lines` | public `org-iw-discovery-queue-lines` |
| org-iw `:278` | `org-iw-discovery--queue-lines` | same |
| org-iw `:275` | `org-iw-discovery--entry-id` | public `org-iw-discovery-entry-id` |
| org-iw `:385` | `org-iw-discovery--excluded-id-p` | public `org-iw-discovery-excluded-id-p` |
| org-iw `:263` (in `--shared-id-p`) | `org-iw-discovery--excluded-id-p` | moves into discovery with `shared-id-p`, so internal |
| org-iw `:250` (in `--unrecognised-drawer-p`) | `org-iw-discovery--in-block-p` | moves into discovery with the drawer test, so **stays private** |

- Not cross-file today: `--iw-lines` and `--line-class`. PHASE-06 G3 routed write through `--queue-lines`, so the older notes delta ("write calls `--iw-lines` and `--line-class`") is stale. `--iw-lines` stays private. `--line-class` is deleted (F-15).
- `org-iw.el` calls no `org-iw-write--` private. No test calls another file's private: `org-iw-discovery-test.el` uses its own layer's `--classify-lines`, and `org-iw-test.el` uses `org-iw--` privates only.

## Decisions (names, signatures, rationale)

| Item | Decision | Why |
|---|---|---|
| F-15 | `org-iw-core-classify-property NAME` returns `(accumulate . QUEUE-ID)` for `IW_<Q>+` with `<Q>` a valid queue ID. Add a cond clause after `reserved`: `((string-suffix-p "+" name) (if-let* ((id (org-iw-core-queue-id (substring name 3 -1)))) (cons 'accumulate id) 'invalid))`. `IW_AFTER_…+` stays `reserved` (that clause comes first). `IW_+`, `IW_ess_ays+` and `IW_Q++` stay `invalid`. Docstring adds the accumulate case ("Org's accumulate syntax"). | Ruled. Every input classifies as it does today through `--line-class`: checked for IW_AFTER+, IW_AFTER_X+, IW_+, IW_Q++, iw_q+, and names outside IW_. |
| F-15 | Delete `org-iw-discovery--line-class`. `--queue-lines` and `--classify-lines` call `org-iw-core-classify-property` directly. | Ruled. Write has no direct call to replace: it reads through `queue-lines`. |
| G10 | `--entry-id` -> **`org-iw-discovery-entry-id ()`** (rename, body unchanged). | It is called by the scan and by Add. |
| G10 | `--queue-lines` -> **`org-iw-discovery-queue-lines (QUEUE)`** (rename). Docstring: lines are read by `org-iw-discovery--iw-lines` (the only IW reader) and classified by `org-iw-core-classify-property`, so KIND is `member` or `accumulate`. | It is called by write preflight and Add. The docstring now names the real classifier. |
| F-11 | One private filter: **`org-iw-discovery--id-problems (SCAN ID)`** returns SCAN's problems whose ID is `equal` to ID, in scan order. | It is the one problem-by-ID filter, as ruled. It is used only inside discovery, so it stays private. |
| F-11 | **`org-iw-discovery-excluded-id-p (SCAN ID)`** = `(seq-some (lambda (p) (eq (org-iw-problem-type p) 'duplicate-id)) (org-iw-discovery--id-problems scan id))`. It replaces `--excluded-id-p`, and resolve uses it. | Called by resolve, `shared-id-p` and org-iw's `--refuse-absent`. |
| F-11 | **`org-iw-discovery-problem-types (SCAN ID)`** returns the distinct problem type **symbols** for ID, in scan order. If ID is nil it returns `(missing-id)`, since an entry without an ID has no ID to match its problem by. | Discovery owns the reading. Text is presentation, so the command keeps the `", "` join and the `"unknown"` fallback in a pure helper, `org-iw--problem-types-text (TYPES)`. |
| F-11 | **`org-iw-discovery-shared-id-p (SCAN ID FILE)`** has the body of `org-iw--shared-id-p`, with `org-iw-discovery-excluded-id-p` for the last clause. Docstring: "Return non-nil if a heading other than the entry at point has ID. ID is the entry's ID, and FILE the truename of the current buffer's file. That holds if ID is on other than one ID property line of the base buffer, a scanned entry in another file has it, or SCAN excluded it as a duplicate." | Moved as ruled. Keep the FILE argument: the caller already has it, and deriving it would duplicate `org-iw--buffer-truename`. |
| F-11 / F-2 | **`org-iw-discovery-unrecognised-drawer-p ()`** has the body of `org-iw--unrecognised-drawer-p`, generalised in the docstring to "the entry at point". Point must be at the entry's start: its heading, or `point-min` for the document entry. Place it after `--in-block-p`. | Its only caller after F-2 is write preflight, which is cross-file, so public. The search from point to `outline-next-heading` holds for a document entry too. |
| F-2 | Guard in **`org-iw-write--preflight`**, inside its `org-with-point-at`, **after** the compare-and-set: `(when (org-iw-discovery-unrecognised-drawer-p) (org-iw-write--refuse marker "entry has a property drawer Org doesn't recognise"))`. It is not gated on EXPECTED. | It protects every caller (ruled). Without gating it can still fire only for `:absent`: an integer EXPECTED needs a recognised drawer to pass the compare. The guard's reason, that `org-entry-put` would add a second drawer, does not depend on EXPECTED. "entry" because put-rank is entry-generic (SL-004 documents). The VT substring is kept. |
| F-2 | `org-iw--check-heading` drops its drawer check. Add lets write's refusal surface. | Ruled. |
| F-2 | put-rank docstring refusal list gains "…, or the entry has a property drawer Org does not recognise (Org would add a second one)". `org-iw-add`'s docstring stays: the user still sees that refusal. | Honest docstrings. |
| F-13 follow-up | `--check-heading` docstring (rewritten in R2a) loses its drawer clause. | Keep it true. |

The public discovery surface added by R2b is `entry-id`, `queue-lines`, `excluded-id-p`, `problem-types`, `shared-id-p` and `unrecognised-drawer-p`, each with at least one cross-file caller. Private: `--id-problems`, `--in-block-p`, `--iw-lines`, `--refuse`, `--id-positions`, `--id-lines`, `--classify-lines`.

**Behaviour change from F-2, state it in the hand-back.** The Add refusal now reads "/abs/a.org: entry has a property drawer Org doesn't recognise". It used to be "heading has a property drawer Org doesn't recognise", with no file. It also comes after Add's rank-limit check rather than before. Steps 5 and 6 cannot fire first, since Org sees no ID or IW line in an unrecognised drawer. The Add tests match by substring and stay green unedited. `org-iw-cmd-test-add-refusal-order` (`:298`) still passes: an invalid queue refuses before put-rank.

## Steps (run `just test </dev/null` after each; lint each edited file)

1. **F-15**, test-first, in core.
   - a. Red: edit `org-iw-core-test-classify-property`. Remove `"IW_ESSAYS+"` from the invalid list. Add `(should (equal (org-iw-core-classify-property "IW_ESSAYS+") '(accumulate . "ESSAYS")))`, the same for `"iw_essays+"`, and `"IW_AFTER+"` -> `(accumulate . "AFTER")`. Add `"IW_+"`, `"IW_ess_ays+"` and `"IW_ESSAYS++"` to the invalid list and `"IW_AFTER_X+"` to the reserved list. Run: the accumulate assertions fail (they get `invalid`). Record that.
   - b. Green: add the core clause and docstring.
   - c. Refactor: delete `--line-class` and point its two callers at core. `grep -n 'line-class' *.el test/*.el` must be empty. Discovery's classify/duplicate/invalid tests (`org-iw-discovery-test.el:420-475`) and `org-iw-write-test-refuses-repeated-key` stay green unedited.
   - Run `just test`.
2. **G10 renames** (neutral): `--entry-id` -> `org-iw-discovery-entry-id` and `--queue-lines` -> `org-iw-discovery-queue-lines`, at every use and docstring reference (discovery, write `--expected-p` docstring and preflight, org-iw `--check-heading`). Run `just test`.
3. **F-11 move** (neutral). In discovery, add `--id-problems`, `excluded-id-p` (deleting `--excluded-id-p`), `problem-types`, `shared-id-p` and `unrecognised-drawer-p`. In org-iw.el, delete `--problem-types`, `--shared-id-p` and `--unrecognised-drawer-p`, and add the pure `org-iw--problem-types-text (TYPES)`. `--check-heading` calls the discovery functions (the drawer check still in it this step, now via `org-iw-discovery-unrecognised-drawer-p`). `--refuse-absent` calls `org-iw-discovery-excluded-id-p`. Run `just test`: the gate is every Add refusal test, A1 and B2, and Continue's `org-iw-cmd-test-continue-refuses-duplicated-id` (`:919`).
4. **F-2**, test-first, in write.
   - a. Red: add `org-iw-write-test-refuses-unrecognised-drawer` in the Compare-and-set section, after `-refuses-repeated-key`. Docstring: ":absent refuses an entry whose drawer Org does not see; writing would add a second drawer and strand its ID." Corpus `a.org` = `(org-iw-test-org "* H" "body" ":PROPERTIES:" ":ID: x1" ":END:")`. For KEYS in `((:expected :absent) (:expected :absent :ensure-id t))`, call `(org-iw-write-test--should-refuse (org-iw-test-marker "a.org" "H") "ESSAYS" . KEYS)`, which asserts `org-iw-refusal`, file named and snapshot unchanged, and assert the reason contains `"property drawer Org doesn't recognise"`. Use a fresh corpus per KEYS. Run it: today put-rank returns `saved`, so `should-error` reports "did not signal" (review F-2 reproduced this). Record that output.
   - b. Green: add the preflight guard. Remove the drawer check from `--check-heading`, and its clause from the docstring. Update the put-rank docstring.
   - c. Confirm the Add-level behaviour tests stay green unedited: `org-iw-cmd-test-add-refuses-malformed-drawer` (`:264`), `-add-ignores-drawer-text-in-block` (`:271`), `-add-drawerless-before-drawer-heading` (`:148`), `-add-refusal-order` (`:298`).
   - Run `just test`.
5. **Closure greps** (all must be empty):
   - `grep -nE 'org-iw-discovery--' org-iw.el org-iw-write.el`
   - `grep -nE 'org-iw-write--' org-iw.el`
   - `grep -nE 'org-iw--(problem-types|shared-id-p|unrecognised-drawer-p)\b' *.el test/*.el`
   - `grep -n 'org-property-start-re\|outline-next-heading' org-iw.el org-iw-write.el` (Org-structure reading left the command and write layers)
   Then `just lint`.
6. **Notes** (below), then the **exit gate**.

Expected test-count delta: +1 (`org-iw-write-test-refuses-unrecognised-drawer`), so R2a's 146 -> 147.

## Tests that change, and why

- `org-iw-core-test-classify-property`: core's contract widened (F-15). `IW_ESSAYS+` is now `(accumulate . "ESSAYS")`, not `invalid`.
- New: `org-iw-write-test-refuses-unrecognised-drawer`. The guard moved to the layer that owns "may this buffer be written" (F-2). The Add-level tests stay as command-level behaviour tests. Do not add a discovery unit test that repeats them.
- No other test may change. The moved functions had no unit tests of their own: they were tested through Add, and those tests stay. If any test must change, stop and report why.

## notes.md edits (append only)

Under `## Audit remediation (RV-002)`, after R2a, add `### R2b — ADR-003 ownership`. Give per F-n the names moved or added, the new and changed tests, the red evidence (F-15, F-2), the closure grep results, the Add message/order change, and the gate counts.

Under `## Design deltas for /reconcile`, append (all four are "User ruled" in the ledger):
- § 5.2 core classify table (RV-002 F-15, user ruling 2026-10-01): a new row `IW_<valid id>+` -> `(accumulate . ID)` before the `invalid` row. `IW_AFTER_…+` stays `reserved`, and `IW_<anything else>+` stays `invalid`. § 5.4 step 4's accumulate rule is now core's classification. `org-iw-discovery--line-class` is gone.
- § 4 / § 5.2 write preflight / § 5.4 Add step 4 (RV-002 F-2, user ruling 2026-10-01): the second-drawer guard is in write preflight, after the compare-and-set. put-rank refuses "FILE: entry has a property drawer Org doesn't recognise" for every caller, and step 4 leaves Add's list. Consequences: Add's message names the file and comes after the rank-limit refusal (step 7). Steps 5 and 6 cannot precede it.
- § 5.1 / § 5.2 discovery / § 5.4 Add (RV-002 F-11 and logged delta G10, user ruling 2026-10-01): discovery's public API gains `org-iw-discovery-entry-id`, `-queue-lines QUEUE`, `-excluded-id-p SCAN ID`, `-problem-types SCAN ID` (symbols), `-shared-id-p SCAN ID FILE` and `-unrecognised-drawer-p`. They share one problem-by-ID filter, `org-iw-discovery--id-problems`. Add steps 5 and 6 read through them, and § 5.4 step 4's "Write preflight and Add step 4 use it" now reads "use it through `org-iw-discovery-queue-lines`". G10 is closed: no file calls another file's `--` private. This supersedes the earlier deltas suggesting promotion (the PHASE-05 "§ 5.2 says `org-iw-write.el` requires …" bullet and the G10 bullet).

## Exit gate (all must hold)

1. `just lint`: zero warnings.
2. `just test-all </dev/null`: green on Emacs 31.1 and 30.2 (expect 147).
3. Optional: `just test-each </dev/null`.
4. The step-5 closure greps are empty.
5. `git status`: only `org-iw-core.el`, `org-iw-discovery.el`, `org-iw-write.el`, `org-iw.el`, `test/org-iw-core-test.el`, `test/org-iw-write-test.el` and `.doctrine/slice/001/notes.md` changed. Not committed.

## If blocked

- If a ruling cannot be met as written, or it conflicts with R2a's tree, stop and report with a proposed default.
- Out of scope: F-1 (read-only refusal; it will also extend preflight, so keep preflight's checks as a flat sequence it can join), F-3, F-5/IMP-002, and `org-iw--visit`'s POS/TOTAL arguments.

## Hand-back (required)

- Per F-n (F-15, F-11, F-2, G10): done / not done, names moved, added or removed, test names, and red evidence (command, failing assertion, observed result).
- The closure grep output (empty), gate tails (`just lint`, `just test-all` lines and counts for 31.1 and 30.2), and files changed.
- Deviations with reasons. The Add message/order change, confirmed or amended. Friction.
- Model echo: your model name/id.
