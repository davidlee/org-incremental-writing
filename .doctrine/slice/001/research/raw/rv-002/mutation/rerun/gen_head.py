# Builds m-head.json (baseline set re-anchored to 62e981c) and m-new.json (new-code mutants).
import json
W="org-iw-write.el"; C="org-iw-core.el"; D="org-iw-discovery.el"; A="org-iw.el"; H="test/org-iw-test-helpers.el"
base = {x[0]: x for f in ("m1","m2") for x in json.load(open(f"/tmp/mut/{f}.json"))}
# id -> (status, file, old, new, note)  ; absent = KEPT
RE = {
 "W10": ("REANCHORED", W, "(org-with-point-at marker (funcall fn))", "(save-excursion (goto-char marker) (funcall fn))",
         "apply: org-with-point-at (which widens) replaced the save-restriction/widen/goto; fault = no widen"),
 "W14": ("REANCHORED", W, "(org-iw-write--preflight marker queue expected)", "nil", "queue-id local gone; arg is now QUEUE"),
 "C1": ("REANCHORED", C, "(and (org-iw-core-rank-p rank) rank)))\n\n(provide", "(and (< rank org-iw-core-rank-limit) rank)))\n\n(provide",
        "append-rank call site, strict bound"),
 "C2": ("REANCHORED", C, "(and (org-iw-core-rank-p rank) rank))))))", "(and (< (abs rank) org-iw-core-rank-limit) rank))))))",
        "parse-rank call site, strict bound"),
 "C6": ("REANCHORED", C, "(and (org-iw-core-rank-p rank) rank))))))", "(and (<= rank org-iw-core-rank-limit) rank))))))",
        "parse-rank call site, no abs"),
 "D6": ("REANCHORED", D, "(eq (org-iw-problem-type problem) 'duplicate-id))\n            (org-iw-discovery--id-problems scan id)))",
        "nil)\n            (org-iw-discovery--id-problems scan id)))", "excluded-id-p never true"),
 "D13": ("REANCHORED", D, "(with-current-buffer (org-iw-discovery-base-buffer)\n    (org-with-wide-buffer", "(progn\n    (progn",
         "id-positions: base-buffer expr is now the shared owner call"),
 "A1": ("REANCHORED", D, "(or (/= (org-iw-discovery-id-count id) 1)", "(or nil", "moved to discovery shared-id-p"),
 "A2": ("REANCHORED", D, "(and (equal (org-iw-entry-id entry) id)\n                       (not (equal (org-iw-entry-file entry) file))))", "nil)", "moved to discovery shared-id-p"),
 "A3": ("REANCHORED", D, "(org-iw-discovery-excluded-id-p scan id)))\n\n(defun org-iw-discovery-resolve", "nil))\n\n(defun org-iw-discovery-resolve", "moved to shared-id-p"),
 "A4": ("REANCHORED", W, "(when (org-iw-discovery-unrecognised-drawer-p)", "(when nil", "guard moved from add's check-heading to write preflight (F-2)"),
 "A13": ("REANCHORED", A, "(org-iw-core-refuse \"document targets are not yet supported\"))", "nil)", "refuse renamed"),
 "A17": ("REANCHORED", A, "(and (equal (org-iw-entry-id entry) id)\n                                 (equal (org-iw-entry-file entry) file)))", "(equal (org-iw-entry-id entry) id))", "indentation"),
 "A20": ("REANCHORED", A, "(org-iw-core-refuse\n           \"heading has IW_%s but it is excluded (%s)\" queue\n           (org-iw--problem-types-text\n            (org-iw-discovery-problem-types scan id)))", "nil", "refuse renamed, problem-types split"),
 "B2": ("REANCHORED", D, "(end (save-excursion (outline-next-heading) (point)))", "(end (point-max))", "moved to discovery unrecognised-drawer-p"),
 "B12": ("REANCHORED", W, "(cl-check-type queue (satisfies org-iw-core-canonical-queue-id-p))\n", "",
         "put-rank no longer canonicalises or refuses: it type-checks a canonical QUEUE; fault = unchecked queue reaches the write"),
 "B14": ("REANCHORED", A, "(org-iw-core-refuse \"no session; run org-iw-visit-next first\")", "(setq org-iw--session (org-iw--session-create :queue \"ESSAYS\" :id \"a1\" :title \"A\"))", "refuse renamed"),
}
RET = {
 "W6": "org-iw-write--base deleted; sole owner is org-iw-discovery-base-buffer (equivalent mutant NW6o in m-new.json)",
}
out=[]; status={}
for mid,(m) in base.items():
    if mid in RET: status[mid]=("RETIRED",RET[mid]); continue
    if mid in RE:
        s,f,o,n,note = RE[mid]; out.append([mid,f,o,n]); status[mid]=(s,note,f,o,n)
    else:
        out.append(list(m)); status[mid]=("KEPT",)
json.dump(out, open("m-head.json","w"), indent=0)
json.dump(status, open("m-head-status.json","w"), indent=1)
new = [
 ("NF1a",W,"(when (buffer-local-value 'buffer-read-only base)","(when nil"),
 ("NF1b",W,"(buffer-local-value 'buffer-read-only base)","(buffer-local-value 'buffer-read-only (marker-buffer marker))"),
 ("NF3a",D,"(unless (derived-mode-p 'org-mode)","(unless t"),
 ("NF3b",D,"(unless (derived-mode-p 'org-mode)","(unless (eq major-mode 'org-mode)"),
 ("NF2b",D,"(unless (org-get-property-block)\n    (save-excursion","(progn\n    (save-excursion"),
 ("NF2c",D,"(setq found (save-excursion\n                        (goto-char (match-beginning 0))\n                        (not (org-iw-discovery--in-block-p)))))","(setq found t))"),
 ("NF2d",D,"(case-fold-search t)\n            (found nil))","(case-fold-search nil)\n            (found nil))"),
 ("NF6a",C,"(and (integerp object) (<= (abs object) org-iw-core-rank-limit))","(<= (abs object) org-iw-core-rank-limit)"),
 ("NF6b",C,"(and (integerp object) (<= (abs object) org-iw-core-rank-limit))","(and (integerp object) (< (abs object) org-iw-core-rank-limit))"),
 ("NF6c",C,"(and (integerp object) (<= (abs object) org-iw-core-rank-limit))","(and (integerp object) (<= object org-iw-core-rank-limit))"),
 ("NF8a",C,"(equal (org-iw-core-queue-id object) object)","t"),
 ("NF8b",W,"(cl-check-type rank (satisfies org-iw-core-rank-p))\n",""),
 ("NF15a",C,"((string-suffix-p \"+\" name)\n      (if-let*","(nil\n      (if-let*"),
 ("NF15b",C,"(substring name 3 -1)","(substring name 3)"),
 ("NF15c",C,"(cons 'accumulate id)","(cons 'member id)"),
 ("NW6o",D,"(or (buffer-base-buffer buffer) buffer)))","buffer))"),
 ("NID1",D,"(seq-filter (lambda (problem) (equal (org-iw-problem-id problem) id))","(seq-filter (lambda (problem) t)"),
 ("NID2",D,"(if (not id)\n      '(missing-id)","(if nil\n      '(missing-id)"),
 ("NPF1",W,"(org-with-point-at marker\n      (unless (org-iw-write--expected-p","(save-excursion (goto-char marker)\n      (unless (org-iw-write--expected-p"),
 ("NSE1",A,"(setq org-iw--session nil)\n    (when (listp global-mode-string)","(when (listp global-mode-string)"),
 ("NSS1",A,"(add-to-list 'global-mode-string org-iw--mode-line-construct)\n  (force-mode-line-update t))","(force-mode-line-update t))"),
]
json.dump([list(x) for x in new], open("m-new.json","w"), indent=0)
print(len(out), len(new))
