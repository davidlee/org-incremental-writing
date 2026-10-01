import subprocess
D = {
"F-1":("fix-now","User ruled (2026-10-01): refuse. Add a buffer-read-only refusal on the base buffer to write preflight, plus tests for Add and Continue. Design §5.2 preflight list gains it at /reconcile (brief)."),
"F-2":("fix-now","User ruled (2026-10-01): fix now. The second-drawer guard for :expected :absent moves into write preflight, so every caller of the one write path is protected. Design §4/§5.4 reconciled at /reconcile (brief)."),
"F-3":("fix-now","User ruled (2026-10-01): refuse. Resolve refuses an entry whose visiting buffer is not in org-mode (derived modes count); message names the file. Design §5.2/§5.4 gain the rule at /reconcile (brief)."),
"F-4":("follow-up","Diagnostics are SL-005's (design §4); behaviour matches its docstring. Captured as IMP-004, related SL-005."),
"F-5":("follow-up","Removing the double scan means carrying the interactive scan into the command body, and SL-004 re-measures scan cost (DEC-003 provisional) anyway; not deferred for size. Captured as IMP-002, related SL-004, with a scan-counter test."),
"F-6":("fix-now","cl-check-type on RANK in put-rank plus a limit check via a core predicate shared with append-rank/parse-rank (POL-002). Docstring already promises an integer; no contract change."),
"F-7":("fix-now","User ruled (2026-10-01): POL-002, fix now. Add org-iw-core-refuse beside the define-error; layer helpers keep only their message prefix."),
"F-8":("fix-now","User ruled (2026-10-01): fix now. One owner for canonicalise-or-refuse; put-rank's QUEUE contract narrows to canonical IDs (public API change, no caller affected). Design §5.2 delta at /reconcile (brief)."),
"F-9":("fix-now","User ruled (2026-10-01): POL-002, fix now. One public discovery base-buffer helper used by write and the commands."),
"F-10":("fix-now","Use org-with-point-at where it is an exact equivalent (write:77-80, org-iw.el:270-272); at write:92-95 keep the outer with-current-buffer for atomic-change-group. Behaviour-neutral."),
"F-11":("fix-now","User ruled (2026-10-01): fix now. Org-structure and scan readers (--unrecognised-drawer-p, --shared-id-p, --problem-types) move to public discovery functions, sharing one problem-by-ID filter; also closes logged delta G10 (commands calling discovery privates). Design §5.2/§5.4 reconciled at /reconcile (brief)."),
"F-12":("fix-now","Extract a session start/end pair that owns org-iw--session and the global-mode-string item; org-iw--visit and org-iw-end-session call it."),
"F-13":("fix-now","Make the docstring self-contained (list the checks), or split lookup from refusal."),
"F-14":("fix-now","One-line comment on the interactive spec: --add-target is called to refuse before prompting (Add steps 1-3). Double scan itself is F-5 / IMP-002."),
"F-15":("fix-now","User ruled (2026-10-01): fix now. org-iw-core-classify-property returns (accumulate . Q) itself; --line-class goes. Design §5.2 classify table updated at /reconcile (brief)."),
"F-16":("fix-now","Rename `moved` to say it holds the save status; string-match-p in core. Renaming public org-iw-discovery-buffer is tolerated: named in design §5.2, docstring clear."),
"F-17":("fix-now","Compare corpus-visiting buffers only (the fixture's predicate), so the test passes alone; add a recipe that runs each test in its own Emacs."),
"F-18":("fix-now","Port the four probes (A1, B2, B3, D12) from /home/scratch/sl-001-review/mutation/org-iw-probe-test.el into the suite."),
"F-19":("fix-now","Self-tests for org-iw-test-snapshot and org-iw-test-state: a known edit, modified flag and disk change must each change the capture. They are the oracle for I1/I7."),
"F-20":("tolerated","For SL-001 only: plan.toml VT keywords are immutable and off the reconcile surface, and the behaviour is genuinely tested via wrappers; no test is missing. Future slices: a VT-evidence standard (keywords name ert-deftest names or code symbols; test_file contains tests), proposed in the RV-002 synthesis."),
"F-21":("fix-now","Pin the limit as the literal 2^53-1 (probe-c4)."),
"F-22":("fix-now","Drive the visit-message test through org-iw-visit-next so the position is computed, not supplied."),
"F-23":("tolerated","Design §5.4 Messages specifies the text, so exact assertions pin a designed contract. SL-005 rewrites messages and should centralise expected strings then."),
"F-24":("follow-up","Test-helper consolidation, sequenced after F-19; no defect behind it beyond overlap. Captured as IMP-003."),
"F-25":("fix-now","Add a FIFO-in-source-dir selection test for the regular-file rule (D10). A14 is equivalent in practice (echo overwritten, logged G4); A16 is F-5."),
}
for f,(d,r) in D.items():
    p=subprocess.run(["doctrine","review","dispose","RV-002","--finding",f,"--disposition",d,"--as","responder","--response","-"],input=r,capture_output=True,text=True,cwd="/workspace/org-incremental-writing")
    print(f,d,(p.stdout+p.stderr).strip().splitlines()[-1])
