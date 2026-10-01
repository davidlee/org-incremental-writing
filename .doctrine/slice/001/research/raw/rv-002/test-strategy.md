# org-iw test strategy: SL-002 onwards

Author: RV-002 reviewer 3 (test-suite lens). Date: 2026-10-01. Baseline: `e3c5f16`.
Status: proposal (tier-4 judgement). It informs the planners of SL-002 to SL-007 and does not bind them.

## 0. Where the suite stands

| Measure | Value |
|---|---|
| Tests | 135 ERT, 4 files plus one helper library (314 lines) |
| Wall time | 1.0–1.2 s in ERT; about 5 s for `just test` including Emacs start-up |
| Line coverage (undercover) | core 100%, write 100%, discovery 99%, org-iw 99% |
| Source mutants run | 71 hand-written mutants against high-risk logic |
| Killed | 57 |
| Equivalent or near-equivalent | 6 (W8, D17, D18, A12, A15, B4) |
| Real survivors | 8 (C4, D10, D12, A1, A14, A16, B2, B3), so about 88% of non-equivalent mutants are killed |
| Oracle mutants (test helpers) | 4 run, 3 survive (H1, H2, H4) |
| Order dependence | 1 test fails when run alone (`org-iw-discovery-test-scan-without-buffers`) |

The harness, the mutant lists and the probe tests are in `/home/scratch/sl-001-review/mutation/`.

The suite is strong on the hard parts:
- The write path: compare-and-set, the indirect base buffer, atomicity, undo and the save policy.
- Refusal-changes-nothing checks.
- The I8 fixture.

Its weaknesses are structural, and they will grow with the package:

1. **Fixture corpora are minimal.** One to three level-1 headings, rarely with neighbours, nesting, folding or a narrowing on the "other side". Every real survivor that matters (A1, B2, B3, D12) lives in a context the fixtures never build.
2. **The oracles are not tested.** `org-iw-test-state` and `org-iw-test-snapshot` carry every "changes nothing" claim (I1, I7). Replacing either with a constant leaves the suite green.
3. **State capture has three overlapping helpers** (`-snapshot`, `-state`, `org-iw-cmd-test--disks`). Line diffing has one helper (`-changed-lines`), which merges separate changes into one hunk. That will not stretch to multi-file redistribution (SL-006).
4. **verify-vt shapes the tests.** Some keywords are satisfied only by comments and docstrings. Some are user-facing message strings, which couples the plan to the copy. One VT is satisfied by the helper's own definitions instead of a test.
5. **Coverage is saturated and no longer informative.** Mutation found what coverage could not, for example the A1 branch, which is "covered" at 100%.

The recommendations below are prioritised:
- **NOW**: before or during SL-002 design, cheap, and blocking quality drift.
- **SOON**: land with the slice that first needs it.
- **LATER**: nice to have, or only once the shape is proven.

Each has a rationale, a cost and its trade-offs.

---

## 1. Principles to adopt (cost: nil; write them into a standard or the plan template)

1. **Behaviour through the public command or layer API. Private functions only for pure leaves.**
   - A test may call `org-iw-…--x` only if `--x` is a pure function with no I/O (for example `--classify-lines`, `--mode-line`), or if the behaviour cannot be reached otherwise (a stale scan for `--visit`).
   - Every other private call is debt.
2. **Every oracle has a self-test.** That covers any helper whose output a `should` compares (state capture, diffs, I8). This is already true of I8 and `-changed-lines`. Extend it to everything.
3. **Every stub proves it was hit.** `cl-letf`, `advice-add` and hook injections must assert a call count above zero. Otherwise a rename silently makes the test vacuous (today: `org-iw--scan` stubbed in `continue-refuses-without-session`, `org-mode` advised in `scan-org-mode-only-on-iw-line`).
4. **Each test runs alone.** No test may depend on Emacs state warmed by an earlier test.
5. **Contexts are data, not copy-paste.** "Works in a narrowed or indirect or folded buffer" should be one behaviour run over a context matrix (§ 2.3), not a hand-built variant per test.
6. **Assert user-facing text in one place per message.** Assert structure everywhere else (§ 2.6).
7. **Mutation is the strength metric; coverage is a floor.** A slice's VT is not "done" while a catalogued mutant of its new logic survives (§ 2.1).

---

## 2. NOW

### 2.1 A mutation catalogue and `just mutate`

**What.**
- Add `tools/mutate.py`: about 50 lines; the reviewer's harness is ready to adapt. It is driven by `test/mutants.eld`, a curated list of `(ID FILE OLD NEW WHY)` entries.
- Each mutant is one exact-string replacement that must be unique in the file.
- The tool copies `*.el` and `test/` into a temp directory per mutant and runs the suite in parallel (stdin `/dev/null`, 180 s timeout).
- It reports KILLED, SURVIVED or BADPATTERN.
- It fails if any mutant not marked `:equivalent` survives.

**Why.**
- Coverage is 99–100% and cannot rank the suite any more.
- 71 mutants ran in about 9 s on 12 workers and found 4 real behavioural gaps.
- A curated catalogue doubles as executable documentation of which defences matter: "remove the base-buffer lookup", "drop the shared-ID clause", and so on.
- The phase notes already describe exactly this practice ("red proof: …"). The catalogue makes those proofs durable instead of one-off.

**Rules.**
- Each phase adds mutants for its own guard clauses: every `unless`, `when`, `or` or `cond` arm that refuses or protects.
- The patterns are exact strings, so a refactor that breaks a pattern shows as BADPATTERN. That is a prompt to re-target the mutant, not noise.
- Mark equivalent mutants `:equivalent "reason"`, so the list does not rot.
- Run it at phase end, alongside `/audit`, not in `just check`.

**Generic operator mutation (LATER, optional).**
- An Elisp-native mutator: `read` each top-level form, walk it, and emit variants: `<`↔`<=`, `and`→`or`, `(when C …)`→`(when nil …)`, delete one body form, `string=`→`string-equal-ignore-case`, `t`↔`nil`. Each variant is printed back with `prin1` into a copy.
- It finds what humans forget to catalogue.
- Its cost is a day, and the output is noisy: printing loses comments, and there are many equivalent mutants.
- I know of no maintained Elisp mutation-testing tool, so treat this as home-grown either way.
- Do the curated catalogue first.

**Cost.** About 2 hours to land the harness, a justfile recipe and the first catalogue (seed it with `m1.py` and `m2.py` from the scratch dir). After that, about 10 minutes per phase.

### 2.2 Oracle self-tests, and a test-library split

**What.**
- Add `test/org-iw-test-helpers-test.el` (or one `-test.el` per helper module, below).
- Move the five fixture self-tests out of `org-iw-discovery-test.el` (§ "Fixture") into it.
- Add self-tests proving that `org-iw-test-state` and `org-iw-test-snapshot` (or the § 2.4 replacement) detect each of these:
  - a disk change;
  - a buffer text change outside the narrowing;
  - a modified-flag flip with identical text;
  - a newly visited buffer;
  - a killed buffer;
  - a narrowing change, once captured.

**Why.** H1 (state returns nil), H2 (snapshot returns a constant) and H4 (state ignores buffers) all leave the suite green. With H1 in place, the I1 test `org-iw-cmd-test-visit-next-writes-nothing` passes against a Visit that inserts text (shown: source mutant V2 plus H1).

**Split helpers by responsibility before they pass about 500 lines.**

| File | Owns |
|---|---|
| `test/org-iw-test-corpus.el` | the fixture, path helpers, corpus builders (§ 2.3) |
| `test/org-iw-test-assert.el` | capture and diff assertions (§ 2.4), refusal assertions |
| `test/org-iw-test-interact.el` | prompt stubs, key simulation (§ 3.2) |
| `test/org-iw-test-helpers.el` | stays as a one-line umbrella `require` of the three |

Each module gets its own self-test file.

**Naming.**
- Rename `test/org-iw-test.el` (which holds `org-iw-cmd-test-*`) to `test/org-iw-cmd-test.el`, so that the file name, the feature and the prefix agree.
- The `org-iw-test-` prefix then unambiguously means "shared test library".

**Cost.** About 2 hours. The rename touches VT `test_file` rows for PHASE-06 and PHASE-07; do it at SL-001 close or as the first SL-002 chore.

### 2.3 A corpus DSL and a context matrix

**What, part 1: a nested outline builder.** It replaces hand-concatenated `org-iw-test-heading` strings.

```elisp
(org-iw-test-outline
 '(:doc (:id "d1" :iw (("ESSAYS" . 7)) :title "Doc")    ; optional document drawer
   (heading "Parent" :body "Parent text."
            (heading "Target" :id "t1" :iw (("ESSAYS" . 1024))
                     :planning "SCHEDULED: <2026-10-01 Thu>" :body "Body."))
   (heading "Later" :id "l1" :props ((":CUSTOM:" . "x")))
   (block example ":ID: t1")))                          ; quoted text
```

- It renders deterministic Org text, so it stays golden-diffable.
- Escape hatches: `(raw "...")` for malformed input.
- Keep `org-iw-test-heading` and `org-iw-test-org` as the primitives the DSL renders through.

**What, part 2: a context matrix.** Run one behavioural assertion under each named buffer context.

```elisp
(org-iw-test-in-contexts
    (unvisited clean dirty narrowed-before narrowed-after narrowed-to-subtree
     indirect indirect-narrowed-away folded-parent)
    corpus "a.org" "Target"
  (lambda (marker ctx) …assert…))
```

- Each context is a small function: `(setup MARKER) -> MARKER'` plus a teardown.
- `ert-info` labels each context, so a failure names it.

**Why.** The real survivors were all context gaps:

| Mutant | Gap | Silent wrong behaviour shown by probe |
|---|---|---|
| B2 | the drawer search bounded to `point-max` instead of the section | Add on a drawerless heading followed by a heading with a drawer is falsely refused. No fixture has that, though it is the common shape of a real file. |
| B3 | the widen test ignores `marker < point-min` | Visit with the buffer narrowed to a *later* subtree lands on the wrong heading. Fixtures only narrow to an earlier one. |
| D12 | resolve without invisible-ok | Visit of a child heading under a folded parent lands on the parent. Every queued fixture heading is level 1. |
| A1 | the in-file shared-ID clause | Two non-member headings sharing an ID: Add succeeds and the next scan silently drops the new member. No fixture has duplicate IDs without IW lines. |

SL-003 (the view, move and remove from a source entry), SL-004 (document targets from anywhere) and SL-005 (refile) all multiply contexts. Without a matrix, each slice will hand-pick a few and miss the rest.

**Trade-offs.**
- The matrix multiplies run time. Today's 1 s budget has room for about 10× growth.
- Keep a context set per operation: write-path contexts are not visit contexts.
- Failures are slightly less direct to read; `ert-info` labels mitigate this.

**Cost.** Half a day for the DSL, half a day for the matrix. Retrofit the existing narrowed and indirect tests opportunistically, not as a big bang.

### 2.4 One capture, one diff assertion

**What.** Replace `-snapshot`, `-state` and `org-iw-cmd-test--disks` with one capture. Pair it with a hunk-level, multi-file expected-change assertion in the shape of `git diff`.

```elisp
(let ((before (org-iw-test-capture)))   ; files on disk; per corpus buffer:
  (org-iw-continue)                     ;   text, modified, restriction, point;
  (org-iw-test-should-change before     ; session; selected window's buffer
    :disk '(("a.org" (":IW_ESSAYS: 1024" . ":IW_ESSAYS: 4096")))  ; exactly this hunk
    :buffers :same-as-disk              ; or an explicit per-buffer spec
    :session '(:id "b1")))              ; everything unmentioned: unchanged
```

**How.**
- Compute real per-file hunks with a small LCS line diff (about 40 lines of Elisp), or by shelling to `diff -U0`. Today's head-and-tail trim (`-changed-lines`) reports two separated edits as one block with the lines between them.
- The default is "nothing else changed". Naming a change is opt-in.
- I2 ("exactly one line in one file") becomes `:disk '(("a.org" (OLD . NEW)))`.
- I1 and I7 become `(org-iw-test-should-change before)` with no keys.

**Why.** SL-006 redistribution writes N lines across M files and must report saved, modified and untouched files. SL-003 reorders with up and down. Both need multi-hunk, multi-file assertions that read like the `git diff` the human trial checks. One capture also removes three overlapping notions of state (POL-002 applies to tests too).

**Cost.** Half a day, plus its self-tests (§ 2.2).

### 2.5 Isolation and order independence

- **Fix the current order dependence.** In `scan-without-buffers`, compare only buffers whose names do not start with a space, or `(mapc #'get-buffer-create '(" *code-conversion-work*"))` in the fixture. The first option is better, since it states the intent: "no user-visible buffer".
- **Add `just test-each`.** It runs each test in its own Emacs, in parallel (`xargs -P`). Shown here: 135 processes in about 20 s. Run it at phase end, not per commit.
- **Fixture binding audit.** The fixture binds options, org-id state, session and `global-mode-string`. Add bindings for:
  - `kill-ring` and `org-id-method` (determinism of generated IDs, if a test ever pins one);
  - `create-lockfiles` and `make-backup-files`: state them explicitly, since tests assert lock files exist;
  - `window-configuration`: save and restore it, since visit tests change the selected window;
  - `completion-extra-properties`.
- **Fixture self-test for leaks.** After each test, assert no buffer survives whose name matches `org-iw` or whose `default-directory` is under the corpus.

**Cost.** About an hour.

### 2.6 Message contract in one place

**What.**
- About 24 assertions in `org-iw-test.el` compare full user-facing messages.
- Keep exactly one table-driven test per command for message formats, for example `org-iw-cmd-test-messages`: rows of corpus, action and expected message.
- Elsewhere, assert outcome (disk, session, shown) and at most a stable fragment.
- Better still, have each command return or record a structured outcome alongside the string (`(:added :queue "ESSAYS" :pos 2 :total 2 :status saved :problems 0)`). Tests assert the plist, and one formatting test covers the plist→text function.

**Why.**
- SL-002 changes Continue's messages (vocabulary, chooser).
- SL-005 changes the problems suffix (diagnostics with locations).
- Today every such change ripples through about 20 tests and through `plan.toml` VT keywords.
- A grammar fix ("1 source problems") touches 6 tests.

**Trade-offs.**
- A structured outcome is a small design change to the command layer, and the commands return messages by design (G7). Raise it in SL-002 `/design`.
- The table-only route is test-side and free.

**Cost.** 1–2 hours test-side; the structured outcome is a design decision.

### 2.7 How to write VT criteria so verify-vt helps instead of distorting

Observed distortions in SL-001:

| Distortion | Where |
|---|---|
| Keywords satisfied only in prose (a comment or docstring) | PHASE-03 VT-1 `make-symbolic-link` (`discovery-test.el:146`, a comment only); PHASE-05 VT-2 `make-indirect-buffer` and `set-file-modes` (`write-test.el:249`, `:264`, `:276`, docstrings only); PHASE-06 VT-1 `make-indirect-buffer` (`org-iw-test.el:388`, docstring) |
| Keyword pressure fixing the test's implementation | `discovery-test.el:593` and `:695` must keep a raw `make-indirect-buffer` plus `unwind-protect` instead of using `org-iw-test-call-with-indirect`, or PHASE-04 VT-2 regresses (this already happened once, PHASE-06 notes) |
| A VT satisfied by the thing under test, not a test | PHASE-03 VT-5's `test_file` is the helper library, so its keywords match the fixture's own `let` bindings and docstring. It would pass with zero self-tests. |
| User copy pinned in the plan | PHASE-06 VT-2 and PHASE-07 VT-2/VT-3 keywords are refusal and report strings. A rewording means editing `plan.toml`. |

Rules for SL-002 onwards:

1. **Key a VT on test names, not API literals.**
   - Use `keywords = ["org-iw-write-test-refuses-changed-on-disk-indirect", …]`, or `patterns = ["\\(ert-deftest org-iw-place-test-between-.*"]`.
   - A deftest name occurs once, in code, names a behaviour, and survives refactors of the test body.
   - This is the single most effective change.
2. **`test_file` is always a `*-test.el` file**, never the helper library.
3. **No user-facing strings as keywords.** If wording is the requirement, the VT names the message-table test (§ 2.6).
4. **The planner drafts the test names when authoring the VT.** That doubles as the behaviour list for `/phase-plan`, and makes test naming deliberate rather than retrofitted.
5. **Upstream ask** (doctrine friction observation, user's call): verify-vt should ignore matches inside comments and docstrings, or offer a mode that requires `ert-deftest` names.
   - Until then, add a checkdoc-style lint in `tools/` that fails if a VT keyword occurs only on comment or docstring lines.
   - A starting point: `mutation/vt_prose_check.py` (about 20 lines). It reads `plan.toml` and lists keywords with no hit on a code line.
6. **Remove the existing docstring literals** once the VTs are re-keyed to test names. The four sites are listed above.

**Cost.** Re-keying the SL-001 VTs takes about an hour if wanted at close. The rule itself is free.

---

## 3. SOON (land with the slice that needs it)

### 3.1 Property-based and model-based tests (SL-002 and SL-003; essential for SL-006)

**Property tests on the pure core (SL-002 placement and rank allocation).**
- Use a hand-rolled generator, not a library. `propcheck` (MELPA) exists, but it adds a dependency and a nix input for little gain over about 60 lines:

```elisp
(defmacro org-iw-test-for-all (n seed bindings &rest body) …)
;; e.g. 300 cases, fixed seed, shrinking optional (print the failing case)
```

- Generators: rank lists (sorted, with duplicates, negatives, near ±limit), placements (fixed, fractional, end, depth 0, out of range), queue sizes 0 to 50.
- Properties:
  - Allocation keeps order.
  - The result lies strictly between its neighbours, or is nil when there is no gap.
  - The result never exceeds `org-iw-core-rank-limit`.
  - A no-op placement returns "no write".
  - Clamping is idempotent.
- Make the seed fixed and printed on failure (`(random "org-iw")`), so runs are deterministic. A `ORG_IW_SEED` environment variable allows exploratory runs.

**Model-based tests of the command layer (SL-003 and SL-006).**
- The model is a pure list of IDs per queue.
- Generate random operation sequences (add, continue, move up or down, place, remove, redistribute) over a small corpus.
- After each operation, assert:
  - the scanned order equals the model;
  - the § 2.4 diff touched only the lines the operation should touch (one line per single-entry operation);
  - no buffer is left dirty unless it started dirty.
- This is the cheapest way to find interaction bugs between placement, view reorders and redistribution. It also pins I2 and I3 under composition, not just single steps.

**Cost.** Half a day for the generator plus core properties (SL-002). One day for the model harness (SL-003). The model then extends per slice.

### 3.2 Interactive and UI testing (SL-002 chooser, SL-003 tabulated view)

- **Use the built-in `ert-x` facilities.** These exist on both 30.2 and 31.1 (verified):
  - `ert-simulate-command`, `ert-simulate-keys`, `ert-with-message-capture`, `ert-with-test-buffer`, `ert-with-buffer-selected`, `ert-with-temp-directory`, `ert-resource-file`.
  - `ert-play-keys` is 31-only; avoid it.
- **`with-simulated-input` (MELPA): not yet.** It makes multi-prompt minibuffer chains pleasant. But `ert-simulate-keys` plus the existing `completing-read` stub covers a single chooser. Add it only if SL-002's chooser grows multi-step prompts. It is not packaged in the dev shell today.
- **Keep the prompt stub, and promote it to the interact module** (§ 2.2). Extend it to queue answers for successive prompts, and record the prompt text as well as the collection.
- **Tabulated-list view (SL-003).**
  - Assert on `tabulated-list-entries` (data) and the action outcome (§ 2.4 diff) for most tests.
  - Have one golden rendering test (§ 3.3).
  - Drive actions through the keymap with `ert-simulate-command` in the view buffer, so the bindings themselves are tested.
- **`ert-with-message-capture`** replaces the "returned message" workaround (`current-message` is nil in batch), so commands need not return their message only for tests. Relevant to the § 2.6 design question.
- **The mode line.** `format-mode-line` returns "" in batch. Keep asserting the raw `org-iw--mode-line` string. If IMP-001 makes the session string public, test that public function instead of the private one.

### 3.3 Golden (snapshot) tests: narrowly (SL-003, SL-005, SL-006)

- Use them for rendered artefacts only:
  - the queue view buffer;
  - the diagnostics report;
  - the redistribution preview.
- Files live in `test/golden/NAME.txt`, compared with `ert-resource-file`-style lookup.
- `ORG_IW_UPDATE_GOLDEN=1 just test` rewrites them.
- Review golden diffs in commits like code.
- **Trade-off.** Goldens are brittle and invite blind regeneration. Never use them for behaviour that § 2.4 can state precisely, such as diffs of Org files.

### 3.4 Fault injection for multi-file writes (SL-006)

- Generalise today's `write-file-functions` and `set-file-modes` injections into `org-iw-test-with-faults`:

```elisp
(org-iw-test-with-faults '((save "b.org")            ; nth file's save signals
                           (unwritable "c.org")
                           (changed-on-disk "a.org" :after preview))
  …)
```

- It must restore everything on exit (as `-set-modes` does), and each fault asserts it fired (§ 1.3).
- SL-006 closure explicitly requires a "simulated write failure". This makes it one line per scenario. Pair it with the § 2.4 assertion for "saved / modified / untouched files".

### 3.5 Performance: a benchmark, not a gate (SL-004 owns the risk)

- **`just bench`**: generate a corpus deterministically (for example 40 files and 1,840 headings, with 0%, 10% and 100% members, plus a few large non-member files), then `benchmark-run` the scan, Add, Visit and Continue, 5 runs each.
- Print a table, and append it to `test/bench-history.tsv` (commit, Emacs, Org, timings).
- **Do not gate in `just check`.** Timing in a shared jail is noisy.
- **Optional loose gate in `just gate`**: fail when slower than 2× the committed baseline.
- Design § 8's scan-cost risk (0.65 s at 1,840 members) is currently guarded only by research notes. DEC-003 ("rescan on every operation") and DEC-004 are explicitly provisional "until SL-004 re-measures". The bench is how SL-004 re-measures, repeatably.
- **Scan-count guard.** The surviving mutant A16 (an extra scan per Add) shows nothing notices redundant scans. Expose a scan counter in the bench output per command, rather than writing an implementation-coupled unit test.

### 3.6 Coverage policy

- Keep `just coverage` non-gating.
- Optionally add a floor gate of 97% per file on Emacs 31. This catches a new file landing with a big untested region, not a missed line. undercover misattributes some lines (PHASE-07 notes), so 100% would be noise.
- Mutation (§ 2.1) is the quality signal; coverage only finds dead areas.

### 3.7 Emacs, Org and compilation matrix

| Run | Status | Recommendation |
|---|---|---|
| 31.1 / Org 9.8.10, from source | in gate | keep |
| 30.2 / Org 9.7.11, from source | in gate | keep |
| 31.1, byte-compiled sources | verified passing by reviewer; not in gate | add `just test-compiled`, cheap; catches compiled-only differences in macros, `cl-defun` keys and lexical capture |
| Latest Org from ELPA on 31 | none | add when SL-003 or SL-004 touch folding, `org-element` or tabulated views (most churn-prone APIs). `-L` an Org checkout pinned in the flake. About an hour of nix work. |
| Emacs 29 | none | out of scope: `Package-Requires` says 30.1 |

- Consider declaring `(org "9.7")` in `Package-Requires`, since the suite only proves 9.7 and later.

### 3.8 CI

- There is no CI (`.github/` is absent).
- A GitHub Actions workflow running `nix develop -c just gate` would protect the two-version gate from "works in my jail".
- This is outward-facing, so it is the user's call. Cost is about an hour, plus nix cache time on first runs.
- Without CI, keep `just gate` and `just test-each` as phase-end rituals recorded in notes (the current practice).

---

## 4. LATER

1. **An acceptance scenario suite (SL-007)** that mirrors the PRD-001 § 5 walkthrough.
   - Use a Git-initialised temp corpus, with `git diff --numstat` and `git diff -U0` as the oracle.
   - It is an automated pre-check of every VH step, so the human trial only judges feel and real data, not mechanics.
   - It reuses § 2.3 and § 2.4.
2. **Fuzzing the discovery reader.**
   - Generate random Org text: drawers in odd places, blocks, `IW_` lines with odd keys and values, CRLF, and huge lines.
   - Assert the invariants: the scan never signals, never creates a buffer, and entries and problems are consistent (no entry with an excluded ID).
   - Fixed seed. About a day. Most useful before SL-005's diagnostics expand the problem taxonomy.
3. **Buttercup instead of ERT: no.**
   - Nested `describe` and `it` would express contexts, but the § 2.3 matrix gives that in ERT.
   - Switching costs a runner, a dependency, and the ERT-native undercover and `ert-x` integration.
4. **el-mock or mocker: no.**
   - The suite's best tests inject faults through real Emacs extension points (`write-file-functions`, file modes, mtimes), which test the real code paths.
   - `cl-letf` covers the rest; keep it rare and counted (§ 1.3).
5. **An Elisp generic mutator** (§ 2.1), if the curated catalogue proves its worth.
6. **README examples as tests (SL-007).** Extract the `elisp` blocks from the README and evaluate them under the fixture, so documented configuration stays valid.

---

## 5. Budget and hygiene targets

- `just test` under 5 s of ERT time. Today it is about 1 s, which leaves room for the § 2.3 matrix and § 3.1 properties.
- No single test over 250 ms, except the I6 child-Emacs test. Print the slowest tests in `just test`: `ert-summarize-tests-batch-and-exit` (Emacs 30 and 31) can list the slowest N from a logged run.
- Batch output is quiet: commands that `message` on success currently print about 100 lines per run. With `ert-with-message-capture` (§ 3.2), real warnings stand out.
- Every phase end runs:
  - `just gate`;
  - `just test-each`;
  - `just mutate` (the slice's catalogue entries);
  - `just coverage`, as a look, not a gate.
- Record the results in the phase notes.

---

## 6. Suggested sequencing

| When | Item | Est. |
|---|---|---|
| SL-001 close, or the first SL-002 chore | § 2.5 order-dependence fix; § 2.2 oracle self-tests; probe tests for A1, B2, B3, D12, C4 (they exist in the scratch dir) | 2 h |
| SL-002 plan | § 1 principles into the plan template; § 2.7 VT rules; § 2.1 `just mutate` plus catalogue | 3 h |
| SL-002 PHASE-01 | § 2.3 DSL; § 2.4 capture and diff; helper split and rename (§ 2.2); § 3.1 core properties | 1.5 d |
| SL-002 | § 2.6 message table (plus the structured-outcome decision in `/design`); § 3.2 chooser via the prompt stub | 0.5 d |
| SL-003 | § 2.3 context matrix in full; § 3.1 model-based harness; § 3.2 view testing; § 3.3 one golden | 1.5 d |
| SL-004 | § 3.5 bench; § 3.7 latest-Org run | 1 d |
| SL-005 | § 4.2 fuzzing (optional); goldens for diagnostics | 0.5–1 d |
| SL-006 | § 3.4 fault injection; model harness extended to redistribution | 1 d |
| SL-007 | § 4.1 scenario suite; § 4.6 README checks | 1 d |
