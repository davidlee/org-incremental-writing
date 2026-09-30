;;; org-iw-test.el --- Tests for the org-iw commands  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 David Lee

;; Author: David Lee <david.lee@inlight.com.au>
;; URL: https://github.com/davidlee/org-incremental-writing

;; SPDX-License-Identifier: GPL-3.0-or-later

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; ERT tests for the command layer: `org-iw-add' and the private
;; helpers the commands share.  Every prompt is stubbed, so that no
;; test reads from standard input.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-iw-test-helpers)
(require 'org-iw)

;;;; Helpers

(defun org-iw-cmd-test--add-at (marker queue)
  "Call `org-iw-add' for QUEUE with point at MARKER, in its buffer.
Return its result."
  (with-current-buffer (marker-buffer marker)
    (goto-char marker)
    (org-iw-add queue)))

(defun org-iw-cmd-test--add (name title queue)
  "Add the heading TITLE of corpus file NAME to QUEUE; return the result."
  (org-iw-cmd-test--add-at (org-iw-test-marker name title) queue))

(defvar org-iw-cmd-test--prompts nil
  "The `completing-read' calls seen by `org-iw-cmd-test--with-prompt'.")

(defmacro org-iw-cmd-test--with-prompt (answer &rest body)
  "Run BODY with `completing-read' stubbed to return ANSWER.
Each call is recorded in `org-iw-cmd-test--prompts' as a plist
\(:collection :require-match :annotate).  ANSWER nil fails the test
at the prompt, proving BODY never prompts."
  (declare (indent 1) (debug t))
  `(let ((org-iw-cmd-test--prompts nil))
     (cl-letf (((symbol-function 'completing-read)
                (lambda (_prompt collection &optional _predicate require-match
                                 &rest _)
                  (push (list :collection collection
                              :require-match require-match
                              :annotate (plist-get completion-extra-properties
                                                   :annotation-function))
                        org-iw-cmd-test--prompts)
                  (or ,answer (ert-fail "Prompted for a queue")))))
       ,@body)))

;;;; Private helpers

(ert-deftest org-iw-cmd-test-files-honour-exclude-regexp ()
  "A file matching `org-iw-exclude-regexp' is not a source file."
  (org-iw-test-with-corpus '(("a.org" . "* A\n") ("skip.org" . "* S\n"))
    (let ((org-iw-exclude-regexp "skip"))
      (should (equal (org-iw--files) (list (org-iw-test-path "a.org")))))))

(ert-deftest org-iw-cmd-test-source-file-p ()
  "Corpus files and their indirect buffers are sources; others are not."
  (org-iw-test-with-corpus '(("a.org" . "* A\n") ("b.org" . "* B\n"))
    (let ((marker (org-iw-test-marker "a.org" "A")))
      (with-current-buffer (marker-buffer marker)
        (should (org-iw--source-file-p)))
      (org-iw-test-call-with-indirect
       marker (lambda (_) (should (org-iw--source-file-p))))
      (with-temp-buffer
        (org-mode)
        (should-not (org-iw--source-file-p)))
      (with-current-buffer (marker-buffer marker)
        (let ((org-iw-exclude-regexp "a\\.org"))
          (should-not (org-iw--source-file-p))))
      (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
        (with-current-buffer (org-iw-test-visit "b.org")
          (should-not (org-iw--source-file-p)))))))

(ert-deftest org-iw-cmd-test-queue-name ()
  "A configured :name is found whatever the key's case; else the ID."
  (let ((org-iw-queues '(("essays" :name "Essays") ("Ideas"))))
    (should (equal (org-iw--queue-name "ESSAYS") "Essays"))
    (should (equal (org-iw--queue-name "IDEAS") "IDEAS"))
    (should (equal (org-iw--queue-name "DRAFTS") "DRAFTS"))))

;;;; Add: success (VT-1, I2, I4, I5)

(defconst org-iw-cmd-test--target
  (concat (org-iw-test-heading "Target" "t1" ":IW_OTHER: 5"
                               ":IW_AFTER_ESSAYS: x" ":CUSTOM: keep")
          (org-iw-test-org "Body." "* Next" "Text."))
  "A file whose heading Target has an ID and other IW lines.")

(defconst org-iw-cmd-test--member
  (org-iw-test-heading "Member" "m1" ":IW_ESSAYS: 2048")
  "A file whose heading Member is in ESSAYS at 2048.")

(defconst org-iw-cmd-test--corpus
  `(("a.org" . ,org-iw-cmd-test--target)
    ("b.org" . ,org-iw-cmd-test--member))
  "Target, not yet queued, and a queue ESSAYS holding Member.")

(defun org-iw-cmd-test--order (queue)
  "Return the IDs of QUEUE's members in queue order, scanned afresh."
  (mapcar #'org-iw-entry-id
          (org-iw-core-queue-order (org-iw-scan-entries (org-iw--scan))
                                   queue)))

(ert-deftest org-iw-cmd-test-add-appends ()
  "Add appends; on disk only the new IW_ESSAYS line appears (I2, I4)."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((org-iw-queues '(("essays" :name "Essays"))))
      (should (equal (org-iw-cmd-test--add "a.org" "Target" "essays")
                     "Added to Essays at 2/2 (saved)"))
      (should (equal (org-iw-test-changed-lines
                      org-iw-cmd-test--target
                      (org-iw-test-file-string "a.org"))
                     '(nil ":IW_ESSAYS: 3072")))
      (should-not (buffer-modified-p (org-iw-test-visit "a.org")))
      (should (equal (org-iw-cmd-test--order "ESSAYS") '("m1" "t1"))))))

(ert-deftest org-iw-cmd-test-add-creates-drawer-and-id ()
  "A heading without drawer or ID gets both, and joins an empty queue."
  (let ((text (org-iw-test-org "* New" "Body.")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "New")))
        (should (equal (org-iw-cmd-test--add-at marker "ESSAYS")
                       "Added to ESSAYS at 1/1 (saved)"))
        (org-iw-test-should-add-drawer text marker "* New")))))

(ert-deftest org-iw-cmd-test-add-leaves-dirty-buffer-unsaved ()
  "A buffer with unsaved edits is changed but not saved (I5)."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-edit-elsewhere marker)
      (should (string-search "queue change not saved"
                             (org-iw-cmd-test--add-at marker "ESSAYS")))
      (should (buffer-modified-p (marker-buffer marker)))
      (should (equal (org-iw-test-file-string "a.org")
                     org-iw-cmd-test--target)))))

(ert-deftest org-iw-cmd-test-add-reports-failed-save ()
  "A failing save is reported with its error; the edit stands."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((write-file-functions (list (lambda () (error "Disk full")))))
      (should (equal (org-iw-cmd-test--add "a.org" "Target" "ESSAYS")
                     (concat "Added to ESSAYS at 2/2 (queue change applied"
                             " but not saved: Disk full)")))
      (should (buffer-modified-p (org-iw-test-visit "a.org")))
      (should (equal (org-iw-test-file-string "a.org")
                     org-iw-cmd-test--target)))))

;;;; Add: already a member (VT-1)

(defun org-iw-cmd-test--queue-of-three (target-line)
  "Return a corpus: ESSAYS holds A, Target (by TARGET-LINE) and C."
  `(("a.org" . ,(concat (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1024")
                        (org-iw-test-heading "Target" "t1" target-line)))
    ("c.org" . ,(org-iw-test-heading "C" "c1" ":IW_ESSAYS: 3072"))))

(defun org-iw-cmd-test--should-be-no-op (target-line)
  "Assert Add of a member by TARGET-LINE reports it and changes nothing."
  (org-iw-test-with-corpus (org-iw-cmd-test--queue-of-three target-line)
    (let* ((marker (org-iw-test-marker "a.org" "Target"))
           (before (org-iw-test-state)))
      (should (equal (org-iw-cmd-test--add-at marker "ESSAYS")
                     "Already in ESSAYS at 2/3"))
      (should (equal (org-iw-test-state) before)))))

(ert-deftest org-iw-cmd-test-add-member-is-no-op ()
  "Adding a member reports its position; nothing is written or saved."
  (org-iw-cmd-test--should-be-no-op ":IW_ESSAYS: 2048"))

(ert-deftest org-iw-cmd-test-add-lowercase-member-is-no-op ()
  "A member by a lowercase iw_essays key is a member too."
  (org-iw-cmd-test--should-be-no-op ":iw_essays: 2048"))

;;;; Add: refusals (VT-2, I7)

(defun org-iw-cmd-test--at (name title)
  "Return a marker at heading TITLE of corpus file NAME.
TITLE nil means the start of the file, before any heading."
  (if title
      (org-iw-test-marker name title)
    (with-current-buffer (org-iw-test-visit name)
      (copy-marker (point-min)))))

(defun org-iw-cmd-test--should-refuse (marker queue substring)
  "Assert Add at MARKER to QUEUE refuses with SUBSTRING, changing nothing.
The refusal must be an `org-iw-refusal', and the corpus files and
buffers must be as before.  Return the refusal message."
  (let* ((before (org-iw-test-state))
         (reason (cadr (should-error (org-iw-cmd-test--add-at marker queue)
                                     :type 'org-iw-refusal))))
    (should (string-search substring reason))
    (should (equal (org-iw-test-state) before))
    reason))

(defun org-iw-cmd-test--refuses (text queue substring &optional title)
  "Assert Add refuses with SUBSTRING in a corpus holding a.org as TEXT.
Add is at heading TITLE of a.org, or its start if TITLE is nil, to
QUEUE.  Return the refusal message."
  (org-iw-test-with-corpus `(("a.org" . ,text))
    (org-iw-cmd-test--should-refuse (org-iw-cmd-test--at "a.org" title)
                                    queue substring)))

(defconst org-iw-cmd-test--intro
  (org-iw-test-org "Intro." "* H")
  "A file with text before its first heading H.")

(ert-deftest org-iw-cmd-test-add-refuses-outside-sources ()
  "Add refuses a file outside the sources and a buffer with no file."
  (org-iw-test-with-corpus '(("a.org" . "* A\n") ("b.org" . "* B\n"))
    (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
      (org-iw-cmd-test--should-refuse (org-iw-test-marker "b.org" "B")
                                      "ESSAYS" "not under org-iw-sources"))
    (with-temp-buffer
      (insert "* H\n")
      (org-mode)
      (org-iw-cmd-test--should-refuse (copy-marker (point-min))
                                      "ESSAYS" "not under org-iw-sources"))))

(ert-deftest org-iw-cmd-test-add-refuses-document-target ()
  "Add refuses point before the first heading."
  (org-iw-cmd-test--refuses org-iw-cmd-test--intro "ESSAYS"
                            "document targets are not yet supported"))

(ert-deftest org-iw-cmd-test-add-refuses-invalid-queue ()
  "Add refuses a typed queue ID that is not valid, quoting it."
  (dolist (queue '("ess_ays" "" "straße"))
    (should (string-search (format "%S" queue)
                           (org-iw-cmd-test--refuses
                            "* H\n" queue "invalid queue ID" "H")))))

(defconst org-iw-cmd-test--malformed
  (org-iw-test-org "* H" "Body." ":PROPERTIES:" ":ID: h1" ":END:")
  "A heading H whose drawer follows body text, so Org ignores it.")

(ert-deftest org-iw-cmd-test-add-refuses-malformed-drawer ()
  "Add refuses a drawer Org does not see, last heading or not."
  (dolist (text (list org-iw-cmd-test--malformed
                      (concat org-iw-cmd-test--malformed "* Next\n")))
    (org-iw-cmd-test--refuses text "ESSAYS"
                              "property drawer Org doesn't recognise" "H")))

(ert-deftest org-iw-cmd-test-add-ignores-drawer-text-in-block ()
  "A :PROPERTIES: line in a block is text; Add makes a real drawer."
  (let ((text (org-iw-test-org "* H" "#+begin_example" ":PROPERTIES:"
                               ":END:" "#+end_example")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "H")))
        (org-iw-cmd-test--add-at marker "ESSAYS")
        (org-iw-test-should-add-drawer text marker "* H")))))

(ert-deftest org-iw-cmd-test-add-refuses-excluded-property ()
  "Add refuses a heading whose IW_ESSAYS the scan excluded, naming why."
  (pcase-dolist (`(,id ,lines ,type)
                 '(("h1" (":IW_ESSAYS: soon") "invalid-rank")
                   ("h1" (":IW_ESSAYS: 1" ":iw_essays: 2")
                    "duplicate-property")
                   ("h1" (":IW_ESSAYS+: 1") "invalid-property")
                   (nil (":IW_ESSAYS: 1") "missing-id")))
    (org-iw-cmd-test--refuses (apply #'org-iw-test-heading "H" id lines)
                              "ESSAYS" (format "excluded (%s)" type) "H")))

(ert-deftest org-iw-cmd-test-add-refuses-at-rank-limit ()
  "Add refuses when the last rank leaves no room below the limit."
  (org-iw-cmd-test--refuses
   (concat (org-iw-test-heading "Last" "l1" ":IW_ESSAYS: 9007199254740991")
           (org-iw-test-heading "H" "h1"))
   "ESSAYS" "rank limit" "H"))

(ert-deftest org-iw-cmd-test-add-refusal-order ()
  "When two refusals apply, the earlier in the design's order wins."
  (org-iw-test-with-corpus `(("a.org" . "* A\n")
                             ("b.org" . ,org-iw-cmd-test--intro))
    (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
      (org-iw-cmd-test--should-refuse (org-iw-cmd-test--at "b.org" nil)
                                      "ESSAYS" "not under org-iw-sources")))
  (org-iw-cmd-test--refuses org-iw-cmd-test--intro "ess_ays"
                            "document targets")
  (org-iw-cmd-test--refuses org-iw-cmd-test--malformed "ess_ays"
                            "invalid queue ID" "H"))

(ert-deftest org-iw-cmd-test-add-refuses-before-prompting ()
  "Interactively, a non-source buffer or a document target never prompts."
  (org-iw-cmd-test--with-prompt nil
    (with-temp-buffer
      (insert "* H\n")
      (org-mode)
      (should-error (call-interactively #'org-iw-add)
                    :type 'org-iw-refusal))
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--intro))
      (with-current-buffer (org-iw-test-visit "a.org")
        (goto-char (point-min))
        (should (string-search "document targets"
                               (cadr (should-error
                                      (call-interactively #'org-iw-add)
                                      :type 'org-iw-refusal))))))))

;;;; Add: shared IDs (EX-3, RV-001 F-2)

(defun org-iw-cmd-test--copy (&rest lines)
  "Return a heading Copy with Member's ID m1 and drawer LINES."
  (apply #'org-iw-test-heading "Copy" "m1" lines))

(defun org-iw-cmd-test--should-refuse-shared (files)
  "Assert Add of Copy in a.org refuses as sharing an ID, given FILES.
The scan must be the same before and after.  Return the scan."
  (org-iw-test-with-corpus files
    (let ((scan (org-iw--scan)))
      (org-iw-cmd-test--should-refuse (org-iw-test-marker "a.org" "Copy")
                                      "ESSAYS"
                                      "ID shared with another heading")
      (should (equal (org-iw--scan) scan))
      scan)))

(ert-deftest org-iw-cmd-test-add-refuses-id-shared-in-file ()
  "Add refuses a heading whose ID a member in the same file has.
The scan already excludes both copies as duplicates; Add adds no
third, and Member's line is untouched."
  (let ((scan (org-iw-cmd-test--should-refuse-shared
               `(("a.org" . ,(concat org-iw-cmd-test--member
                                     (org-iw-cmd-test--copy)))))))
    (should-not (org-iw-scan-entries scan))))

(ert-deftest org-iw-cmd-test-add-refuses-id-shared-across-files ()
  "Add refuses a heading whose ID a member in another file has.
The member stays in the queue at its rank."
  (let ((scan (org-iw-cmd-test--should-refuse-shared
               `(("a.org" . ,(org-iw-cmd-test--copy))
                 ("b.org" . ,org-iw-cmd-test--member)))))
    (should (equal (mapcar (lambda (entry)
                             (org-iw-core-rank entry "ESSAYS"))
                           (org-iw-core-queue-order
                            (org-iw-scan-entries scan) "ESSAYS"))
                   '(2048)))))

(ert-deftest org-iw-cmd-test-add-refuses-id-excluded-as-duplicate ()
  "Add refuses an ID the scan excluded as shared by two other files."
  (org-iw-cmd-test--should-refuse-shared
   `(("a.org" . ,(org-iw-cmd-test--copy))
     ("b.org" . ,org-iw-cmd-test--member)
     ("c.org" . ,(org-iw-test-heading "Other" "m1" ":IW_ESSAYS: 1")))))

(ert-deftest org-iw-cmd-test-add-shared-id-refusal-order ()
  "An excluded property wins over a shared ID, which wins over the limit."
  (org-iw-test-with-corpus `(("a.org" . ,(org-iw-cmd-test--copy
                                          ":IW_ESSAYS: soon"))
                             ("b.org" . ,org-iw-cmd-test--member))
    (org-iw-cmd-test--should-refuse (org-iw-test-marker "a.org" "Copy")
                                    "ESSAYS" "excluded"))
  (org-iw-cmd-test--should-refuse-shared
   `(("a.org" . ,(org-iw-cmd-test--copy))
     ("b.org" . ,(org-iw-test-heading "Member" "m1"
                                      ":IW_ESSAYS: 9007199254740991")))))

;;;; Add: indirect and narrowed buffers (EX-4, RV-001 F-5)

(defun org-iw-cmd-test--should-have-added (marker)
  "Assert Target at MARKER was added to ESSAYS at 2/2 and saved.
The base buffer is unmodified and holds the disk text, which differs
from the original only by the new IW_ESSAYS line."
  (should-not (buffer-modified-p (org-iw-test-base marker)))
  (should (equal (org-iw-test-text marker) (org-iw-test-file-string "a.org")))
  (should (equal (org-iw-test-changed-lines org-iw-cmd-test--target
                                            (org-iw-test-file-string "a.org"))
                 '(nil ":IW_ESSAYS: 3072"))))

(ert-deftest org-iw-cmd-test-add-from-indirect-buffer ()
  "Add works in an indirect buffer, made by `make-indirect-buffer'.
The edit goes through the base buffer, which is saved."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (org-iw-test-call-with-indirect
     (org-iw-test-marker "a.org" "Target")
     (lambda (indirect-marker)
       (should (equal (org-iw-cmd-test--add-at indirect-marker "ESSAYS")
                      "Added to ESSAYS at 2/2 (saved)"))
       (org-iw-cmd-test--should-have-added indirect-marker)))))

(ert-deftest org-iw-cmd-test-add-in-narrowed-buffer ()
  "Add works under `narrow-to-region' and keeps the narrowing.
The base buffer is narrowed to the subtree, and an indirect buffer to
the body alone, leaving the heading line outside."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (with-current-buffer (marker-buffer marker)
        (goto-char marker)
        (narrow-to-region marker (save-excursion (org-end-of-subtree t t)))
        (org-iw-cmd-test--add-at marker "ESSAYS")
        (should (equal (concat (buffer-string) "* Next\nText.\n")
                       (org-iw-test-file-string "a.org"))))
      (org-iw-cmd-test--should-have-added marker)))
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (org-iw-test-call-with-indirect
     (org-iw-test-marker "a.org" "Target")
     (lambda (indirect-marker)
       (goto-char (point-min))
       (search-forward "Body.")
       (narrow-to-region (line-beginning-position) (line-end-position))
       (org-iw-add "ESSAYS")
       (should (equal (buffer-string) "Body."))
       (org-iw-cmd-test--should-have-added indirect-marker)))))

;;;; Messages

(ert-deftest org-iw-cmd-test-add-counts-source-problems ()
  "The message counts the scan's problems; with none there is no count.
Without problems, see `org-iw-cmd-test-add-appends'."
  (org-iw-test-with-corpus
      `(,@org-iw-cmd-test--corpus
        ("c.org" . ,(org-iw-test-heading "No ID" nil ":IW_ESSAYS: 1")))
    (should (equal (org-iw-cmd-test--add "a.org" "Target" "ESSAYS")
                   "Added to ESSAYS at 2/2 (saved) [1 source problems ignored]"))))

;;;; Queue completion (EX-2, DEC-002)

(ert-deftest org-iw-cmd-test-read-queue-offers-known-queues ()
  "Completion offers configured and discovered queues, names annotated.
Invalid configured IDs are dropped; a new queue may be typed."
  (let ((text (concat (org-iw-test-heading "E" "e1" ":IW_ESSAYS: 1")
                      (org-iw-test-heading "D" "d1" ":IW_drafts: 1"))))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((org-iw-queues '(("essays" :name "Essays") ("Ideas" :name "Ideas")
                             ("bad_id" :name "Bad"))))
        (org-iw-cmd-test--with-prompt "new-queue"
          (should (equal (org-iw--read-queue (org-iw--scan)) "new-queue"))
          (pcase-let ((`((:collection ,ids :require-match ,match
                                      :annotate ,annotate))
                       org-iw-cmd-test--prompts))
            (should (equal ids '("DRAFTS" "ESSAYS" "IDEAS")))
            (should-not match)
            (should (string-search "Essays" (funcall annotate "ESSAYS")))
            (should-not (funcall annotate "DRAFTS"))))))))

(ert-deftest org-iw-cmd-test-add-interactively ()
  "Called interactively, Add prompts for the queue and adds the heading."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-cmd-test--with-prompt "essays"
        (with-current-buffer (marker-buffer marker)
          (goto-char marker)
          (call-interactively #'org-iw-add)))
      (should (equal (org-iw-cmd-test--order "ESSAYS") '("m1" "t1"))))))

(provide 'org-iw-test)
;;; org-iw-test.el ends here
