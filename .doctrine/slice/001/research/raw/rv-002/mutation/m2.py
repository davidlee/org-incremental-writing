import json
W="org-iw-write.el"; C="org-iw-core.el"; D="org-iw-discovery.el"; A="org-iw.el"; H="test/org-iw-test-helpers.el"
m = [
 ("B1",W,"(org-id-get-create))\n","(org-id-get-create)\n         (undo-boundary))\n"),
 ("B2",A,"(end (save-excursion (outline-next-heading) (point)))","(end (point-max))"),
 ("B3",A,"(unless (and (<= (point-min) marker) (< marker (point-max)))","(unless (< marker (point-max))"),
 ("B4",A,"    (org-fold-reveal)\n","\n"),
 ("B5",A,"(retained (or (seq-find (lambda (entry)\n                                   (equal (org-iw-entry-id entry) id))\n                                 order)","(retained (or (car order)"),
 ("B6",D,"((org-iw-discovery--has-iw-line-p)","(t"),
 ("B7",D,"(file-accessible-directory-p directory)))","t))"),
 ("B8",D,"(org-get-heading t t t t)","(org-get-heading)"),
 ("B9",A,"(pop-to-buffer-same-window (marker-buffer marker))","(set-buffer (marker-buffer marker))"),
 ("B10",A,"(sort (seq-uniq\n            (append","(sort (identity\n            (append"),
 ("B11",D,"(push (org-iw-problem-create :type 'misplaced-property :file file)\n                problems)","nil"),
 ("B12",W,"(org-iw-core-queue-id queue)","(and (stringp queue) queue)"),
 ("B13",A,"(if (null rest)","(if nil"),
 ("B14",A,"(org-iw--refuse \"no session; run org-iw-visit-next first\")","(setq org-iw--session (org-iw--session-create :queue \"ESSAYS\" :id \"a1\" :title \"A\"))"),
 ("B15",D,"(if (org-at-heading-p)\n      (org-get-heading t t t t)","(if t\n      (org-get-heading t t t t)"),
 ("B16",A,"(when-let* ((name (org-iw--configured-name queue)))\n                   (concat \" \" name))","nil"),
 # helper (oracle) mutations
 ("H1",H,"(defun org-iw-test-state ()\n  \"Return","(defun org-iw-test-state () nil)\n(defun org-iw-test--state-orig ()\n  \"Return"),
 ("H2",H,"(list (org-iw-test-text marker)\n          (buffer-modified-p base)\n          (org-iw-test-file-string (buffer-file-name base)))","(list nil)"),
 ("H3",H,"(unless (equal after expected)","(unless t"),
 ("H4",H,"(seq-filter #'org-iw-test--corpus-buffer-p (buffer-list)))\n         (lambda","(list))\n         (lambda"),
]
json.dump(m, open("/tmp/mut/m2.json","w"))
