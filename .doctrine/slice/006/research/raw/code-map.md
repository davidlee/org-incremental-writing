<!-- Thread 2 raw output: read-only general-purpose subagent (Opus 5.5), 2026-10-06, at HEAD ae1ba9f. Content as returned; bullets reflowed by the assembler. -->
## Thread 2 — code map

### Hotspots (files likely to change)
- `org-iw-core.el` (243 lines) — `org-iw-core-place` returns `(no-gap DEPTH)` (`:201,210`); no redistribution/normalisation function exists. A pure plan of new ranks belongs here, next to `org-iw-core-rank-at` (`:172`).
- `org-iw-write.el` (227) — single-entry writes only (`org-iw-write-put-rank` `:129`, `org-iw-write-delete-rank` `:192`); `org-iw-write--apply` (`:111`) is atomic for one entry and saves once per call. A multi-entry, multi-file apply extends this layer.
- `org-iw.el` (1530) — `org-iw--refuse-no-room` (`:229`) and its two callers `org-iw--add-entry` (`:477-480`) and `org-iw--move` (`:880-884`); every command reaches no-room through those two. Handoff, preview/confirm UI and normalise command live here.
- Tests: `test/org-iw-test.el` (4588), `test/org-iw-core-test.el` (674), `test/org-iw-write-test.el` (907), `test/org-iw-test-helpers.el` (414). Tests asserting "redistribution is not yet available" must change (`test/org-iw-test.el:175-189,2871,2877`).

### Cited facts

#### 1. Rank model
- `(defconst org-iw-core-rank-spacing 1024 …)` `org-iw-core.el:35-36`; `(defconst org-iw-core-rank-limit (1- (expt 2 53)) …)` `:38-39`, symmetric ±limit; `org-iw-core-rank-p` `:99-102` (`integerp`, `(<= (abs object) limit)`).
- `org-iw-core-parse-rank` `:104-113` (trims, rejects beyond limit).
- `org-iw-core-queue-order (entries queue)` `:119-130`: rank, then ID `string<`. Ties legal; no gap between tied ranks.
- `org-iw-core-rank-at (others queue depth)` `:172-189`: "The rank is `org-iw-core-rank-spacing' when OTHERS is empty, a spacing past the last or before the first, and otherwise the floor of the mean of the neighbours' ranks. Return nil if that rank is not strictly between the neighbours or exceeds `org-iw-core-rank-limit'."
- No-gap detection: between neighbours `(and (< 1 (- after before)) (floor ...))` `:185`; ends fail `org-iw-core-rank-p` past ±limit `:186-189`.
- `org-iw-core-place (order target queue placement)` `:193-210` → `(unchanged DEPTH)`, `(moved DEPTH RANK)`, `(no-gap DEPTH)`; "A nil TARGET is never unchanged."; DEPTH counted among ORDER without TARGET `:204-205`.
- `org-iw-core-reorder (order target depth)` `:212-217` — new order without writing.
- `org-iw-core-placement-depth` `:157-168`, `org-iw-core-beside` `:221-233`, `org-iw-core-step` `:235-240` — pure placement producers.
- No redistribution/normalise/plan functions or stubs; "redistribution" appears only in the refusal at `org-iw.el:232` and tests.

#### 2. No-gap / no-room handling
- `org-iw--refuse-no-room (where name)` `org-iw.el:229-233` → `org-iw-core-refuse "no room %s in %s; redistribution is not yet available"`; only refuser. `no-gap` consumed only at `:478` and `:881`.
- Add / Add-document: `org-iw--add-entry` → `org-iw-core-place order nil queue placement` `:477`; `(no-gap ,_)` → `org-iw--refuse-no-room (or where "at the end")` `:478-480`; `org-iw--add-at` passes "at LABEL" `:499`.
- Batch add: `org-iw--batch-add` → `org-iw--add-entry … 'end t` `:700-702`; refusal caught by `org-iw--batch-outcome` as `(failed REASON)`, "FILE: " stripped `:671-674`; batch continues `:708-713`; summary counts failed `:612`; report line "FILE: no room at the end in …" (`test/org-iw-test.el:1221,1237`).
- Move `org-iw-move` `:1069-1109` → `org-iw--move … (format "at %s" label)` `:1104-1105`; `(no-gap ,depth)` refuses with WHERE or default "at position %d/%d" `:881-884`.
- Continue → `org-iw--continue-place` → `org-iw--move` with "at LABEL" `:936-937`; refuses before `org-iw--visit` `:942` (test `continue-refuses-without-gap`, `test/org-iw-test.el:2775-2786`).
- View M-up/M-down `org-iw--view-step` `:1370-1376` → `org-iw--view-move` without WHERE → "no room at position N/M …" `:1344-1352`.
- View place before/after `org-iw--view-place` `:1399-1413`; WHERE "before TITLE"/"after TITLE" `:1412`; mark cleared only after success `:1410-1413`.

#### 3. Continue and Move
- `org-iw-continue` `:964-1017`: session, choice (`org-iw--placement`, before scan `:1006-1007`), scan, order `:1009-1010`, `org-iw--find-member` `:1013-1014`, dispatch `:1015-1017`.
- `org-iw--continue-place` `:925-945`: single-entry queue left alone `:933-935`; `org-iw--move` `:936`; `new-order` via `org-iw-core-reorder` `:938-941`; `org-iw--visit scan (car new-order) queue 1 total` `:942`. Navigate onward = visit the new head (`:783-805`, session start `:803`).
- `org-iw--move` `:871-887` maps place result to `(unchanged DEPTH)` / `(moved DEPTH STATUS)`, writing via `org-iw--put-rank` `:857-862` (fresh marker, expects scanned rank).
- `org-iw-move` `:1069-1109` writes and reports only (docstring `:1082-1083`).
- Hook points: the `(no-gap ,depth)` branches at `:881-884` and `:478-480`, with scan, order, queue, DEPTH in hand → `(org-iw-core-reorder order entry depth)` as desired order. `org-iw--continue-place` must not reach `:942` on failed redistribution.

#### 4. Write layer
- `org-iw-write--check-file (marker)` `:63-76`: `verify-visited-file-modtime` ("changed on disk; revert first"), `file-writable-p` ("not writable"), `buffer-read-only` ("buffer is read-only").
- `org-iw-write--check-entry (marker queue expected)` `:78-88`: expected value ("IW_%s changed since scan", `org-iw-write--expected-p` `:52-61`), unrecognised drawers.
- `org-iw-write--preflight` `:90-95`; refusals name the file via `org-iw-write--refuse` `:44-50`.
- `org-iw-write--apply (marker fn)` `:111-127`: "Call FN at MARKER atomically; save the base buffer if it was clean … Return `saved', `unsaved', or (save-failed . ERROR)". `atomic-change-group` around one FN `:120-121`; `was-clean` read before edit `:118`; dirty never saved `:122-123`.
- `org-iw-write-put-rank` `:129-190` (type checks `:165-167`); `org-iw-write-delete-rank` `:192-224`.
- No multi-entry/multi-file write. N `put-rank` calls in one clean file save N times (`:118`); atomicity per entry, not per file.
- Reusable: `--check-file`/`--check-entry` as an all-files preflight pass (both "Nothing is changed"); the change-group/was-clean/save pattern generalised to one group and one save per base buffer.

#### 5. Discovery / scan
- `org-iw-scan` fields `entries`, `problems` only (`org-iw-discovery.el:40-44`); memberships on `org-iw-entry` (`org-iw-core.el:48-55`: id, title, file truename, memberships alist, outline). File list from `org-iw--files` (`org-iw.el:144-146`).
- `org-iw-discovery-scan (files)` `:452-464`: "No file is visited and no buffer is changed."; reads visiting buffers' text including unsaved edits `:399-414`.
- `org-iw--order` `org-iw.el:212-214`.
- `org-iw--entry-marker` → `org-iw-discovery-resolve scan id file` (`org-iw.el:223-227`); resolve refuses on excluded duplicates, non-Org buffers, ID not exactly one identity; visits via `org-iw-discovery-buffer`; marker at heading or `point-min` (`org-iw-discovery.el:551-572`).
- `org-iw-discovery-buffer (file)` = `(or (find-buffer-visiting file) (find-file-noselect file))` `:475-482`; Move/Continue never kill opened buffers; only the batch does.
- `org-iw--batch-outcome (file fn)` `org-iw.el:655-680` (DEC-026): kill opened unless modified `:676-677`; `left-open` `:678-680`; refusal/file-error → `(failed REASON)` `:671-675`. Shaped per file with per-file failure capture; redistribution needs whole-plan preflight first.

#### 6. UI precedents
- `*org-iw batch*` `org-iw.el:583-584`; `org-iw--batch-report` `:635-653` (`special-mode`, `inhibit-read-only`, one `FILE: text` line, `display-buffer`, nil when nothing); `--batch-outcome-text` `:624-633`; `--batch-summary` `:602-622` ("not atomic; see *org-iw batch*").
- `org-iw--save-status` `:336-344`; `org-iw--report` `:346-353` (appends " [%d source problems ignored]").
- Progress reporter in `org-iw-add-files` `:758-771`; `unwind-protect` marks remaining `stopped` `:772-778`.
- Only prompt: `y-or-n-p` in `org-iw-view-remove` `:1460`; no `yes-or-no-p`.
- Queue view `org-iw-view-mode` (tabulated-list) `:1179-1191`; keymap `:1167-1177`; `org-iw--view-redraw-and-report` `:1337-1342`.

#### 7. Test infrastructure
- `org-iw-test-with-corpus` `test/org-iw-test-helpers.el:162-184` (cleanup `:96-110`, I8 no file appeared/vanished `:112-120`); `org-iw-test-org` `:248-250`; `org-iw-test-heading` `:252-259`.
- `org-iw-test-set-modes` `:205-209`; `org-iw-test-unless-root` `:406-411` (`test/org-iw-write-test.el:318-324`); `org-iw-test-rewrite-behind` `:222-229`; `org-iw-test-edit-elsewhere` `:361-366`.
- `org-iw-test-file-string` `:211-215`; `org-iw-test-snapshot` `:332-339`; `org-iw-test-state` `:341-359`; `org-iw-test-changed-lines` `:231-244`.
- `test/org-iw-test.el`: `--should-write-nothing` `:2342`, `--should-change-nothing` `:2363`, `--should-refuse-cleanly` `:2373`, `--disks` `:2550`, `--should-change-lines` `:2557` (one file), `--should-move` `:2571`, `--ranks` `:1048-1054`, `--open-all` `:2338`, `--visited` `:1056`.
- Prompt recorder `org-iw-cmd-test--with-prompt` `:76-129` (stubs `completing-read`, `y-or-n-p` :yes/:no); `--prompted` `:131`; `--call-at` fails on any y-or-n-p/yes-or-no-p `:44-54`; no `yes-or-no-p` recorder.
- Save failure: `write-file-functions` erroring (`test/org-iw-test.el:1504`); `org-iw-write-test--failing-hook`, `org-iw-write-test-injected` (`test/org-iw-write-test.el:400,455-468`); `org-iw-write-test--call-failing-rank-put` `:402-414`.
- Selective failure: `org-iw-cmd-test--diverting` `:1086-1094`, `--named-p` `:1096-1102`; `--counting` `:1069-1084`.
- No-room fixtures: neighbours 5/6 (`:2775-2786`, `:3324-3339`), rank at limit (`:2763-2773`); `org-iw-cmd-test--no-room` `:175-178`. Core: `org-iw-core-test--queue`, `--rank-at` (`test/org-iw-core-test.el:187-196`); randomized place checks `:341-440`.
- `--report-lines` `:1038-1046`; `--last-message` `:1060-1067`.

#### 9. justfile
- `lint` = compile checkdoc package-lint relint, warnings as errors (`justfile:22-35,63`); `test bin=emacs` `:66-73`; `test-all` `:76`; `test-each` (not a gate) `:79-97`; `check` `:100`; `gate: lint test-all` `:103`; `coverage` `:106-115`.

#### 10. Size
core 243, discovery 575, write 227, org-iw.el 1530; tests core 674, discovery 1240, helpers 414, cmd 4588, write 907.

### Naming precedents
- Public `org-iw-<layer>-name` (`org-iw-core-place` `org-iw-core.el:193`, `org-iw-write-put-rank` `org-iw-write.el:129`, `org-iw-discovery-resolve` `org-iw-discovery.el:551`); private `org-iw-<layer>--name`; command privates `org-iw--name`; commands `org-iw-verb` + `;;;###autoload` (`org-iw.el:1068-1069`); view commands `org-iw-view-*` (`:1354`).
- Refusals: `(define-error 'org-iw-refusal "org-iw refused" 'user-error)` (`org-iw-core.el:41`); signaller `org-iw-core-refuse` (`:43-46`); wrappers `org-iw-write--refuse` (`org-iw-write.el:44`), `org-iw-discovery--refuse` (`org-iw-discovery.el:502`), `org-iw--refuse-no-room`/`--refuse-absent`/`--refuse-excluded` (`org-iw.el:229,840,433`).
- Tagged plain-list results via `pcase`: core `(unchanged D)`/`(moved D R)`/`(no-gap D)` (`org-iw-core.el:199-201`); command `(existing POS)`/`(added DEPTH STATUS ENTRY)` (`org-iw.el:452-456`); write status `saved | unsaved | (save-failed . ERR)` (`org-iw-write.el:115-116`).
- Batch outcomes `(FILE . OUTCOME)` with optional `left-open` (`org-iw.el:576-581`); predicates `org-iw--batch-<adj>-p` (`:586-600`).
- Text builders `org-iw--<thing>-text` (`:889`, `:900`, `:914`, `:807`); commands return the message shown (`:543`, `:999`).
- Docstrings carry "the one owner of …" claims (`org-iw-discovery.el:117,213,553`).

### Reuse candidates and gaps
- `org-iw-core-place` — reuse unchanged; `(no-gap DEPTH)` is the trigger. Gap: no pure function mapping a target order to evenly spaced ranks and diffing against current ranks.
- `org-iw-core-reorder` — desired order for a blocked move at DEPTH; one plan covers move + redistribution.
- `org-iw-write--check-file` / `--check-entry` — whole-plan preflight before any edit. Gap: they refuse on first problem; preview needs non-signalling reason-returning predicates, refusers wrapping them (POL-002).
- `org-iw-write--apply` — model for per-file multi-rank apply. Gap: one marker/FN, one save per call; no grouped variant, no multi-file driver returning saved/modified/untouched.
- `org-iw--put-rank` (`org-iw.el:857`) — usable only if the save is deferred.
- `org-iw--entry-marker` → `org-iw-discovery-resolve` — visits files; preview and apply need a buffer-kill rule.
- `org-iw--batch-outcome` — DEC-026 kill rule reusable; per-file failure capture doesn't match preflight-all-then-apply; extract the kill rule.
- `org-iw--batch-report` / `--batch-summary` / `--save-status` — precedent for the partition report; report hard-titled "Batch add to %s" (`:648`) → generalise.
- `special-mode` + `y-or-n-p` (`org-iw.el:645,1460`); progress reporter (`:758`). Nothing yet saves/reverts other buffers on request.
- Interception points: `org-iw.el:881-884`, `:478-480`; `org-iw--continue-place` (`:936-942`) must not visit on failure/cancel.
- Test reuse: corpus, prompt recorder, `write-file-functions` injection, `--diverting`+`--named-p`, `set-modes`, `rewrite-behind`, `edit-elsewhere`, `test-state`/`--should-change-nothing`, `--ranks`. Gap: multi-file "changed exactly these lines" oracle (`--should-change-lines` is single-file, `test/org-iw-test.el:2557`).
