;;; org-iw-write-test.el --- Tests for org-iw-write  -*- lexical-binding: t; -*-

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

;; ERT tests for `org-iw-write-put-rank' and `org-iw-write-delete-rank':
;; the preflight refusals, the atomic edit and the save policy.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-iw-test-helpers)
(require 'org-iw-write)

;;;; Helpers

(defun org-iw-write-test--should-refuse-by (verb marker queue &rest keys)
  "Assert that VERB at MARKER in QUEUE refuses, changing nothing.
VERB is called as (VERB MARKER QUEUE . KEYS), KEYS being keyword
arguments.  The refusal must be an `org-iw-refusal' naming the file;
the buffer text, `buffer-modified-p' and disk contents must be
unchanged.  Return the refusal message."
  (let* ((before (org-iw-test-snapshot marker))
         (err (should-error (apply verb marker queue keys)
                            :type 'org-iw-refusal))
         (reason (cadr err)))
    (should (equal (org-iw-test-snapshot marker) before))
    (should (string-search
             (buffer-file-name (org-iw-test-base marker)) reason))
    reason))

(defun org-iw-write-test--put-4096 (marker queue &rest keys)
  "Put rank 4096 at MARKER in QUEUE, with keyword arguments KEYS."
  (apply #'org-iw-write-put-rank marker queue 4096 keys))

(defun org-iw-write-test--should-refuse (marker queue &rest keys)
  "Assert that put-rank at MARKER in QUEUE refuses, changing nothing.
KEYS are the keyword arguments; see
`org-iw-write-test--should-refuse-by'."
  (apply #'org-iw-write-test--should-refuse-by #'org-iw-write-test--put-4096
         marker queue keys))

(defconst org-iw-write-test--target
  (org-iw-test-org
   "* Target"
   ":PROPERTIES:"
   ":ID: t1"
   ":IW_OTHER: 5"
   ":IW_ESSAYS: 2048"
   ":IW_AFTER_ESSAYS: x"
   ":CUSTOM: keep"
   ":END:"
   "Body."
   "* Next"
   "Text.")
  "A file whose heading Target is a member of ESSAYS at 2048.")

(defconst org-iw-write-test--rank-change
  '((":IW_ESSAYS: 2048") ":IW_ESSAYS: 3072")
  "The change of `org-iw-write-test--put-target', as (REMOVED . ADDED).")

(defun org-iw-write-test--put-target (marker &rest keys)
  "Move the Target at MARKER from 2048 to 3072 in ESSAYS.
KEYS are extra keyword arguments.  Return the put-rank result."
  (apply #'org-iw-write-put-rank marker "ESSAYS" 3072 :expected 2048 keys))

;;;; Success

(ert-deftest org-iw-write-test-saves-clean-buffer ()
  "A clean buffer is saved; only the IW_ESSAYS line changes (I4)."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (should (eq (org-iw-write-put-rank marker "ESSAYS" 3072
                                         :expected 2048)
                  'saved))
      (should-not (buffer-modified-p (marker-buffer marker)))
      (should (equal (org-iw-test-changed-lines
                      org-iw-write-test--target
                      (org-iw-test-file-string "a.org"))
                     org-iw-write-test--rank-change))
      (should (equal (org-iw-test-text marker)
                     (org-iw-test-file-string "a.org"))))))

(ert-deftest org-iw-write-test-lowercase-key ()
  "A lowercase iw_essays key is the queue's line; only it changes.
`org-entry-put' rewrites the key as IW_ESSAYS, on the same line."
  (let ((text (org-iw-test-heading "Target" "t1" ":iw_essays: 2048"
                                   ":IW_OTHER: 5")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (should (eq (org-iw-write-put-rank
                   (org-iw-test-marker "a.org" "Target")
                   "ESSAYS" 3072 :expected 2048)
                  'saved))
      (should (equal (org-iw-test-changed-lines
                      text (org-iw-test-file-string "a.org"))
                     '((":iw_essays: 2048") ":IW_ESSAYS: 3072"))))))

(ert-deftest org-iw-write-test-leaves-dirty-buffer-unsaved ()
  "A buffer with unsaved edits is changed but not saved (I5)."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-edit-elsewhere marker)
      (should (eq (org-iw-write-test--put-target marker)
                  'unsaved))
      (should (buffer-modified-p (marker-buffer marker)))
      (should (equal (org-iw-test-changed-lines
                      (concat org-iw-write-test--target "User edit.\n")
                      (org-iw-test-text marker))
                     org-iw-write-test--rank-change))
      (should (equal (org-iw-test-file-string "a.org")
                     org-iw-write-test--target)))))

(ert-deftest org-iw-write-test-ensure-id-adds-one-id ()
  "With :ensure-id, a heading without an ID gets one, drawer and all.
The drawer goes after the planning line; nothing else changes."
  (let ((text (org-iw-test-org "* New" "SCHEDULED: <2026-10-01 Thu>"
                               "Body.")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "New")))
        (should (eq (org-iw-write-put-rank marker "ESSAYS" 1024
                                           :expected :absent :ensure-id t)
                    'saved))
        (org-iw-test-should-add-drawer
         text marker "SCHEDULED: <2026-10-01 Thu>")))))

(ert-deftest org-iw-write-test-ensure-id-keeps-existing-id ()
  "With :ensure-id, an existing ID is kept; only the rank line changes."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (should (eq (org-iw-write-test--put-target
                 (org-iw-test-marker "a.org" "Target") :ensure-id t)
                'saved))
    (should (equal (org-iw-test-changed-lines
                    org-iw-write-test--target
                    (org-iw-test-file-string "a.org"))
                   org-iw-write-test--rank-change))))

(defun org-iw-write-test--undo-once (buffer)
  "Undo the last change group in BUFFER, as one command would."
  (with-current-buffer buffer
    (undo-boundary)
    (let ((last-command nil))
      (undo))))

(ert-deftest org-iw-write-test-undo-restores-rank ()
  "One undo after a saved put-rank restores the previous rank."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (should (eq (org-iw-write-test--put-target marker)
                  'saved))
      (org-iw-write-test--undo-once (marker-buffer marker))
      (should (equal (org-iw-test-text marker)
                     org-iw-write-test--target)))))

(ert-deftest org-iw-write-test-undo-reverts-ensure-id ()
  "One undo reverts the whole put-rank, the ID insertion included."
  (let ((text (org-iw-test-org "* New" "Body.")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "New")))
        (should (eq (org-iw-write-put-rank marker "ESSAYS" 1024
                                           :expected :absent :ensure-id t)
                    'saved))
        (org-iw-write-test--undo-once (marker-buffer marker))
        (should (equal (org-iw-test-text marker) text))))))

;;;; Compare-and-set

(defun org-iw-write-test--check-refuses (drawer-lines expected &optional verb)
  "Assert VERB refuses :expected EXPECTED in ESSAYS over DRAWER-LINES.
DRAWER-LINES are the IW lines of a heading with an ID.  VERB is as
for `org-iw-write-test--should-refuse-by'; nil means put-rank."
  (org-iw-test-with-corpus
      `(("a.org" . ,(apply #'org-iw-test-heading "H" "h1" drawer-lines)))
    (org-iw-write-test--should-refuse-by
     (or verb #'org-iw-write-test--put-4096)
     (org-iw-test-marker "a.org" "H") "ESSAYS"
     :expected expected)))

(ert-deftest org-iw-write-test-refuses-stale-expected ()
  "A rank other than :expected refuses, naming the queue."
  (should (string-search
           "ESSAYS"
           (org-iw-write-test--check-refuses '(":IW_ESSAYS: 2048") 1024))))

(ert-deftest org-iw-write-test-refuses-absent-mismatch ()
  ":absent refuses a member; an integer refuses a non-member."
  (org-iw-write-test--check-refuses '(":IW_ESSAYS: 2048") :absent)
  (org-iw-write-test--check-refuses '(":IW_OTHER: 1") 1024))

(ert-deftest org-iw-write-test-refuses-repeated-key ()
  "A duplicated or accumulated key refuses, whatever is expected."
  (org-iw-write-test--check-refuses '(":IW_ESSAYS: 1" ":iw_essays: 1") 1)
  (org-iw-write-test--check-refuses '(":IW_ESSAYS: 1" ":IW_ESSAYS+: 2") 1)
  (org-iw-write-test--check-refuses '(":IW_ESSAYS+: 2") :absent))

(ert-deftest org-iw-write-test-refuses-unrecognised-drawer ()
  ":absent refuses an entry whose drawer Org does not see.
Writing would add a second drawer and strand its ID.  An integer
EXPECTED refuses there too, at the compare: Org sees no rank."
  (let ((text (org-iw-test-org "* H" "body" ":PROPERTIES:" ":ID: x1" ":END:")))
    (dolist (keys '((:expected :absent) (:expected :absent :ensure-id t)
                    (:expected 1)))
      (org-iw-test-with-corpus `(("a.org" . ,text))
        (let ((reason (apply #'org-iw-write-test--should-refuse
                             (org-iw-test-marker "a.org" "H") "ESSAYS" keys)))
          (when (eq (plist-get keys :expected) :absent)
            (should (string-search "property drawer Org doesn't recognise"
                                   reason))))))))

(ert-deftest org-iw-write-test-refuses-lowercase-unrecognised-drawer ()
  "A lowercase :properties: line after body text is caught, like uppercase.
Org's property drawer must directly follow the heading, so it sees none."
  (let ((text (org-iw-test-org "* H" "body" ":properties:" ":ID: x1" ":END:")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (should (string-search
               "property drawer Org doesn't recognise"
               (org-iw-write-test--should-refuse
                (org-iw-test-marker "a.org" "H") "ESSAYS"
                :expected :absent))))))

(ert-deftest org-iw-write-test-queue-is-checked ()
  "QUEUE must be a canonical queue ID; anything else is an error.
The error comes before anything changes."
  (dolist (queue '("ESS_AYS" "essays" nil))
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
      (let* ((marker (org-iw-test-marker "a.org" "Target"))
             (before (org-iw-test-snapshot marker)))
        (should-error (org-iw-write-put-rank marker queue 3072
                                             :expected 2048)
                      :type 'wrong-type-argument)
        (should (equal (org-iw-test-snapshot marker) before))))))

(ert-deftest org-iw-write-test-expected-is-checked ()
  "EXPECTED must be an integer or :absent; omitting it is an error."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (should-error (org-iw-write-put-rank
                   (org-iw-test-marker "a.org" "Target") "ESSAYS" 1)
                  :type 'wrong-type-argument)))

(ert-deftest org-iw-write-test-rank-is-checked ()
  "RANK must be an integer within the limit; anything else is an error.
The error comes before anything changes."
  (dolist (rank '(1.5 "3072" nil 9007199254740992))
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
      (let* ((marker (org-iw-test-marker "a.org" "Target"))
             (before (org-iw-test-snapshot marker)))
        (should-error (org-iw-write-put-rank marker "ESSAYS" rank
                                             :expected 2048)
                      :type 'wrong-type-argument)
        (should (equal (org-iw-test-snapshot marker) before))))))

(ert-deftest org-iw-write-test-expected-compares-parsed-rank ()
  "A stored 007 equals :expected 7."
  (let ((text (org-iw-test-heading "H" "h1" ":IW_ESSAYS: 007")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (should (eq (org-iw-write-put-rank
                   (org-iw-test-marker "a.org" "H") "ESSAYS" 8
                   :expected 7)
                  'saved)))))

(ert-deftest org-iw-write-test-other-queues-ignored ()
  "Other IW_ and IW_AFTER_ lines do not count as QUEUE's."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (should (eq (org-iw-write-put-rank
                 (org-iw-test-marker "a.org" "Target") "NOTES" 1024
                 :expected :absent)
                'saved))))

;;;; File checks (RV-001 F-4)

;; Both write verbs share the preflight, so each file condition is
;; checked once over both.

(defun org-iw-write-test--should-refuse-each (marker reason)
  "Assert each write verb refuses at MARKER with REASON, changing nothing.
The verbs are put-rank and delete-rank, at ESSAYS :expected 2048; see
`org-iw-write-test--should-refuse-by'."
  (dolist (verb (list #'org-iw-write-test--put-4096 #'org-iw-write-delete-rank))
    (should (string-search reason (org-iw-write-test--should-refuse-by
                                   verb marker "ESSAYS" :expected 2048)))))

(ert-deftest org-iw-write-test-refuses-changed-on-disk ()
  "A file changed on disk refuses, directly and through an indirect buffer.
The check is on the base buffer: an indirect buffer has no file, so a
check on it would pass.  The indirect buffer is made by
`make-indirect-buffer' (via `org-iw-test-call-with-indirect').  There
is no prompt."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-rewrite-behind
       "a.org" (concat org-iw-write-test--target "* Added outside\n"))
      (org-iw-write-test--should-refuse-each marker "changed on disk")
      (org-iw-test-call-with-indirect
       marker
       (lambda (indirect-marker)
         (org-iw-write-test--should-refuse-each
          indirect-marker "changed on disk"))))))

(ert-deftest org-iw-write-test-refuses-unwritable-file ()
  "A read-only file refuses (its modes set, via `set-file-modes')."
  (org-iw-test-unless-root
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
      (org-iw-test-set-modes "a.org" #o444)
      (org-iw-write-test--should-refuse-each
       (org-iw-test-marker "a.org" "Target") "not writable"))))

(ert-deftest org-iw-write-test-refuses-read-only-buffer ()
  "A read-only base buffer refuses, directly and from a writable indirect.
RV-002 F-1: `org-entry-put' and `org-entry-delete' would otherwise
write through `org-no-read-only'.  The check is on the base buffer,
not the one holding the marker."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (with-current-buffer (org-iw-test-base marker)
        (setq buffer-read-only t))
      (org-iw-write-test--should-refuse-each marker "buffer is read-only")
      (org-iw-test-call-with-indirect
       marker
       (lambda (indirect-marker)
         (setq buffer-read-only nil)
         (org-iw-write-test--should-refuse-each
          indirect-marker "buffer is read-only"))))))

(ert-deftest org-iw-write-test-refuses-read-only-indirect ()
  "A read-only indirect buffer over a writable base refuses (RV-006 F-1).
Writing from it would otherwise go through `org-no-read-only', or
signal `buffer-read-only'."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (org-iw-test-call-with-indirect
     (org-iw-test-marker "a.org" "Target")
     (lambda (indirect-marker)
       (setq buffer-read-only t)
       (org-iw-write-test--should-refuse-each
        indirect-marker "buffer is read-only")))))

(ert-deftest org-iw-write-test-writes-through-indirect-buffer ()
  "From a narrowed indirect buffer the edit lands in the base and saves.
The indirect buffer's narrowing, excluding the target, is kept.
The indirect buffer is made by `make-indirect-buffer' (via
`org-iw-test-call-with-indirect')."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-call-with-indirect
       marker
       (lambda (indirect-marker)
         (goto-char (point-min))
         (re-search-forward "^\\* Next$")
         (narrow-to-region (line-beginning-position) (point-max))
         (let ((restriction (cons (point-min) (point-max))))
           (should (eq (org-iw-write-test--put-target indirect-marker)
                       'saved))
           (should (equal (cons (point-min) (point-max)) restriction)))
         (should-not (buffer-modified-p (marker-buffer marker)))
         (should (equal (org-iw-test-changed-lines
                         org-iw-write-test--target
                         (org-iw-test-file-string "a.org"))
                        org-iw-write-test--rank-change))
         (should (equal (org-iw-test-text marker)
                        (org-iw-test-file-string "a.org"))))))))

(ert-deftest org-iw-write-test-ensure-id-through-narrowed-indirect ()
  ":ensure-id works from an indirect buffer narrowed away from the target.
The new drawer goes under the target, not at the narrowing."
  (let ((text (org-iw-test-org "* Other" "Text." "* New" "Body.")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "New")))
        (org-iw-test-call-with-indirect
         marker
         (lambda (indirect-marker)
           (narrow-to-region (point-min) (1- (marker-position marker)))
           (should (eq (org-iw-write-put-rank indirect-marker "ESSAYS" 1024
                                              :expected :absent
                                              :ensure-id t)
                       'saved))
           (org-iw-test-should-add-drawer
            text indirect-marker "* New")))))))

;;;; Atomicity (I7) and save failure

(define-error 'org-iw-write-test-injected "Injected failure")

(defun org-iw-write-test--call-failing-rank-put (fn)
  "Call FN with `org-entry-put' failing for IW_ properties.
Other properties, such as the ID `org-id-get-create' writes, are put
first.  The failure signals `org-iw-write-test-injected', after
asserting that the entry already has its ID."
  (let ((put (symbol-function 'org-entry-put)))
    (cl-letf (((symbol-function 'org-entry-put)
               (lambda (epom property &rest args)
                 (if (not (string-prefix-p "IW_" property))
                     (apply put epom property args)
                   (should (org-entry-get epom "ID"))
                   (signal 'org-iw-write-test-injected nil)))))
      (funcall fn))))

(defun org-iw-write-test--check-rollback (text title dirty type call)
  "Assert that CALL fails with error TYPE and restores everything.
TEXT is file a.org and CALL is called with a marker at its heading
TITLE; DIRTY non-nil first edits the buffer elsewhere.  The error
symbol must be TYPE exactly, and the buffer text,
`buffer-modified-p' and disk must equal their state before the call.
A buffer left clean holds no lock file.  Return the error."
  (org-iw-test-with-corpus `(("a.org" . ,text))
    (let ((marker (org-iw-test-marker "a.org" title)))
      (when dirty
        (org-iw-test-edit-elsewhere marker))
      (let* ((before (org-iw-test-snapshot marker))
             (err (should-error (funcall call marker))))
        (should (eq (car err) type))
        (should (equal (org-iw-test-snapshot marker) before))
        (unless dirty
          (should-not (file-symlink-p (org-iw-test-path ".#a.org"))))
        err))))

(defun org-iw-write-test--check-atomic (dirty)
  "Assert that a failing put-rank restores everything; DIRTY first edits.
The rank put fails after the ID was added; see
`org-iw-write-test--check-rollback'."
  (org-iw-write-test--check-rollback
   (org-iw-test-org "* New" "Body.") "New" dirty 'org-iw-write-test-injected
   (lambda (marker)
     (org-iw-write-test--call-failing-rank-put
      (lambda ()
        (org-iw-write-put-rank marker "ESSAYS" 1024
                               :expected :absent :ensure-id t))))))

(ert-deftest org-iw-write-test-failed-edit-restores-clean-buffer ()
  "An error inside the edit restores text and an unmodified flag (I7)."
  (org-iw-write-test--check-atomic nil))

(ert-deftest org-iw-write-test-failed-edit-restores-dirty-buffer ()
  "An error inside the edit leaves a dirty buffer as it was (I7)."
  (org-iw-write-test--check-atomic t))

(defun org-iw-write-test--failing-hook ()
  "Signal `org-iw-write-test-injected' with data (disk)."
  (signal 'org-iw-write-test-injected '(disk)))

(ert-deftest org-iw-write-test-save-failure-keeps-edit ()
  "A failing save returns save-failed with its error; the edit stands.
The save fails through `write-file-functions', whose errors reach the
caller of `save-buffer'."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target"))
          (write-file-functions (list #'org-iw-write-test--failing-hook)))
      (should (equal (org-iw-write-test--put-target marker)
                     '(save-failed org-iw-write-test-injected disk)))
      (should (buffer-modified-p (marker-buffer marker)))
      (should (equal (org-iw-test-changed-lines
                      org-iw-write-test--target
                      (org-iw-test-text marker))
                     org-iw-write-test--rank-change))
      (should (equal (org-iw-test-file-string "a.org")
                     org-iw-write-test--target)))))

(ert-deftest org-iw-write-test-before-save-hook-error-is-demoted ()
  "A failing `before-save-hook' does not fail the save.
Emacs 30 and 31 demote its errors to a message, so put-rank reports
saved and the disk holds the edit."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target"))
          (before-save-hook (list #'org-iw-write-test--failing-hook)))
      (should (eq (org-iw-write-test--put-target marker)
                  'saved))
      (should-not (buffer-modified-p (marker-buffer marker)))
      (should (equal (org-iw-test-changed-lines
                      org-iw-write-test--target
                      (org-iw-test-file-string "a.org"))
                     org-iw-write-test--rank-change)))))

;;;; delete-rank

(defun org-iw-write-test--should-delete-line (text title line expected)
  "Assert delete-rank removes LINE alone from TEXT and saves it.
TEXT is file a.org; the entry is the heading TITLE, or the document
entry if TITLE is nil, a member of ESSAYS at EXPECTED.  The file must
differ from TEXT by LINE alone, and the buffer be clean and equal to
it.  Return the file's new contents."
  (org-iw-test-with-corpus `(("a.org" . ,text))
    (let ((marker (if title
                      (org-iw-test-marker "a.org" title)
                    (with-current-buffer (org-iw-test-visit "a.org")
                      (point-min-marker)))))
      (should (eq (org-iw-write-delete-rank marker "ESSAYS"
                                            :expected expected)
                  'saved))
      (should-not (buffer-modified-p (marker-buffer marker)))
      (let ((disk (org-iw-test-file-string "a.org")))
        (should (equal (org-iw-test-changed-lines text disk)
                       (list (list line))))
        (should (equal (org-iw-test-text marker) disk))
        disk))))

(ert-deftest org-iw-write-test-delete-rank-removes-one-line ()
  "Only the IW_ESSAYS line is removed (I11).
The drawer and its ID, other IW_ and IW_AFTER_ lines, other
properties, the body and the next heading are untouched."
  (should (string-search
           ":PROPERTIES:\n:ID: t1\n:IW_OTHER: 5\n:IW_AFTER_ESSAYS: x\n"
           (org-iw-write-test--should-delete-line
            org-iw-write-test--target "Target" ":IW_ESSAYS: 2048" 2048))))

(ert-deftest org-iw-write-test-delete-rank-keeps-id-only-drawer ()
  "A drawer of the ID and the rank keeps the ID; Org would drop it empty."
  (org-iw-write-test--should-delete-line
   (org-iw-test-heading "H" "h1" ":IW_ESSAYS: 2048") "H"
   ":IW_ESSAYS: 2048" 2048))

(ert-deftest org-iw-write-test-delete-rank-lowercase-key ()
  "A lowercase iw_essays line is the queue's, and is deleted.
So it is for a caller that binds `case-fold-search' to nil."
  (let ((case-fold-search nil))
    (org-iw-write-test--should-delete-line
     (org-iw-test-heading "Target" "t1" ":iw_essays: 2048" ":IW_OTHER: 5")
     "Target" ":iw_essays: 2048" 2048)))

(ert-deftest org-iw-write-test-delete-rank-keeps-heading-and-planning ()
  "The TODO state, priority, tags and planning line are untouched."
  (org-iw-write-test--should-delete-line
   (org-iw-test-org "* TODO [#A] Target :tag:"
                    "SCHEDULED: <2026-10-01 Thu>"
                    ":PROPERTIES:" ":ID: t1" ":IW_ESSAYS: 2048" ":END:"
                    "Body.")
   "TODO [#A] Target :tag:" ":IW_ESSAYS: 2048" 2048))

(ert-deftest org-iw-write-test-delete-rank-keeps-other-entries ()
  "Another entry's IW_ESSAYS line, after the target's body, is untouched."
  (org-iw-write-test--should-delete-line
   (concat (org-iw-test-heading "Target" "t1" ":IW_ESSAYS: 2048")
           (org-iw-test-org "Body.")
           (org-iw-test-heading "Sibling" "s1" ":IW_ESSAYS: 1024"))
   "Target" ":IW_ESSAYS: 2048" 2048))

(ert-deftest org-iw-write-test-delete-rank-document-entry ()
  "A document entry's rank is deleted; its ID, drawer and headings stay."
  (org-iw-write-test--should-delete-line
   (org-iw-test-org ":PROPERTIES:" ":ID: d1" ":IW_ESSAYS: 2048" ":END:"
                    "* First" "Text.")
   nil ":IW_ESSAYS: 2048" 2048))

(ert-deftest org-iw-write-test-delete-rank-compares-parsed-rank ()
  "A stored 007 is deleted with :expected 7."
  (org-iw-write-test--should-delete-line
   (org-iw-test-heading "H" "h1" ":IW_ESSAYS: 007") "H"
   ":IW_ESSAYS: 007" 7))

(ert-deftest org-iw-write-test-delete-rank-through-indirect-buffer ()
  "From a narrowed indirect buffer the line goes from the base, saved.
The indirect buffer stays narrowed to the same text, past the target."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-call-with-indirect
       marker
       (lambda (indirect-marker)
         (goto-char (point-min))
         (re-search-forward "^\\* Next$")
         (narrow-to-region (line-beginning-position) (point-max))
         (let ((visible (buffer-string)))
           (should (eq (org-iw-write-delete-rank indirect-marker "ESSAYS"
                                                 :expected 2048)
                       'saved))
           (should (equal (buffer-string) visible)))
         (should-not (buffer-modified-p (marker-buffer marker)))
         (should (equal (org-iw-test-changed-lines
                         org-iw-write-test--target
                         (org-iw-test-file-string "a.org"))
                        '((":IW_ESSAYS: 2048")))))))))

;; STD-001 item 5: from a folded view.
(ert-deftest org-iw-write-test-delete-rank-folded ()
  "From a folded heading with a folded drawer, the one line goes; folds stay."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (with-current-buffer (marker-buffer marker)
        (org-overview)
        (goto-char marker)
        (org-fold-hide-drawer-all)
        (should (org-invisible-p (line-end-position))))
      (should (eq (org-iw-write-delete-rank marker "ESSAYS" :expected 2048)
                  'saved))
      (should (equal (org-iw-test-changed-lines
                      org-iw-write-test--target
                      (org-iw-test-file-string "a.org"))
                     '((":IW_ESSAYS: 2048"))))
      (with-current-buffer (marker-buffer marker)
        (goto-char marker)
        (should (org-invisible-p (line-end-position)))))))

(defun org-iw-write-test--delete-should-refuse (marker)
  "Assert delete-rank of ESSAYS at 2048 at MARKER refuses; return why."
  (org-iw-write-test--should-refuse-by #'org-iw-write-delete-rank
                                       marker "ESSAYS" :expected 2048))

(ert-deftest org-iw-write-test-delete-rank-refuses-unexpected-lines ()
  "A stale rank, a non-member, or a duplicated or accumulated key refuses.
`org-entry-delete' would delete every IW_ESSAYS and IW_ESSAYS+ line."
  (should (string-search
           "ESSAYS"
           (org-iw-write-test--check-refuses
            '(":IW_ESSAYS: 2048") 1024 #'org-iw-write-delete-rank)))
  (pcase-dolist (`(,lines ,expected)
                 '(((":IW_OTHER: 1") 1)
                   ((":IW_ESSAYS: 1" ":iw_essays: 1") 1)
                   ((":IW_ESSAYS: 1" ":IW_ESSAYS+: 2") 1)
                   ((":IW_ESSAYS+: 2") 2)))
    (org-iw-write-test--check-refuses lines expected
                                      #'org-iw-write-delete-rank)))

(ert-deftest org-iw-write-test-delete-rank-refuses-unrecognised-drawer ()
  "An entry whose drawer Org does not see refuses: Org sees no rank."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-org "* H" "body" ":PROPERTIES:" ":ID: x1"
                                     ":IW_ESSAYS: 2048" ":END:")))
    (org-iw-write-test--delete-should-refuse
     (org-iw-test-marker "a.org" "H"))))

(ert-deftest org-iw-write-test-delete-rank-arguments-are-checked ()
  "QUEUE must be canonical and EXPECTED an integer, :absent included.
The error comes before anything changes."
  (dolist (args '(("ESS_AYS" :expected 2048) ("essays" :expected 2048)
                  (nil :expected 2048) ("ESSAYS" :expected :absent)
                  ("ESSAYS" :expected 1.5) ("ESSAYS" :expected "1")
                  ("ESSAYS" :expected nil) ("ESSAYS")))
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
      (let* ((marker (org-iw-test-marker "a.org" "Target"))
             (before (org-iw-test-snapshot marker)))
        (should-error (apply #'org-iw-write-delete-rank marker args)
                      :type 'wrong-type-argument)
        (should (equal (org-iw-test-snapshot marker) before))))))

(defun org-iw-write-test--delete-target-with-nothing-deleted (marker)
  "Delete-rank the Target at MARKER with `org-entry-delete' doing nothing.
Assert `org-entry-delete' was called once, for IW_ESSAYS at MARKER."
  (let ((calls nil))
    (unwind-protect
        (cl-letf (((symbol-function 'org-entry-delete)
                   (lambda (&rest args) (push args calls) nil)))
          (org-iw-write-delete-rank marker "ESSAYS" :expected 2048))
      (should (equal calls (list (list marker "IW_ESSAYS")))))))

(ert-deftest org-iw-write-test-delete-rank-nothing-deleted-is-error ()
  "If nothing is deleted, an error restores clean and dirty buffers.
It is a plain error, not a refusal: preflight passed."
  (dolist (dirty '(nil t))
    (should (equal (org-iw-write-test--check-rollback
                    org-iw-write-test--target "Target" dirty 'error
                    #'org-iw-write-test--delete-target-with-nothing-deleted)
                   '(error "IW_ESSAYS not deleted alone")))))

(ert-deftest org-iw-write-test-delete-rank-rank-only-drawer-is-error ()
  "A drawer holding only the rank is an error, with nothing changed.
Org deletes the drawer the deletion emptied; that is rolled back.  The
heading before has a drawer, which must not pass for the target's."
  (should (equal (org-iw-write-test--check-rollback
                  (concat (org-iw-test-heading "P" "p1")
                          (org-iw-test-heading "H" nil ":IW_ESSAYS: 2048"))
                  "H" nil 'error
                  (lambda (marker)
                    (org-iw-write-delete-rank marker "ESSAYS"
                                              :expected 2048)))
                 '(error "IW_ESSAYS not deleted alone"))))

(ert-deftest org-iw-write-test-delete-rank-leaves-dirty-buffer-unsaved ()
  "A buffer with unsaved edits loses the line but is not saved."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-edit-elsewhere marker)
      (should (eq (org-iw-write-delete-rank marker "ESSAYS" :expected 2048)
                  'unsaved))
      (should (buffer-modified-p (marker-buffer marker)))
      (should (equal (org-iw-test-changed-lines
                      (concat org-iw-write-test--target "User edit.\n")
                      (org-iw-test-text marker))
                     '((":IW_ESSAYS: 2048"))))
      (should (equal (org-iw-test-file-string "a.org")
                     org-iw-write-test--target)))))

;;;; Document entries

(defconst org-iw-write-test--new-document-drawer
  (concat "\\`:PROPERTIES:\n"
          "\\(?::ID: +\\([^ \n]+\\)\n\\)?"
          ":IW_ESSAYS: 1024\n:END:\n")
  "A regexp for the drawer put-rank inserts for a new document entry.
Its group 1 is the new ID, if the drawer has one.")

(defun org-iw-write-test--should-put-new-document (text ensure-id advance)
  "Assert put-rank :document makes the heading-first TEXT a member.
TEXT is file a.org.  The rank 1024 and, with ENSURE-ID, a new ID go
into a drawer inserted before the first heading; the file is saved,
TEXT follows the drawer unchanged, the ID is the document's, and one
undo restores TEXT.  ADVANCE non-nil makes the marker advance past
text inserted at it, as `set-marker-insertion-type' t does."
  (org-iw-test-with-corpus `(("a.org" . ,text))
    (let ((marker (org-iw-test-marker "a.org" nil)))
      (set-marker-insertion-type marker advance)
      (should (eq (org-iw-write-put-rank marker "ESSAYS" 1024
                                         :expected :absent
                                         :ensure-id ensure-id
                                         :document t)
                  'saved))
      (let ((disk (org-iw-test-file-string "a.org")))
        (should (string-match org-iw-write-test--new-document-drawer disk))
        (let ((id (match-string 1 disk))
              (rest (substring disk (match-end 0))))
          (should (equal rest text))
          (should (eq (and id t) (and ensure-id t)))
          (with-current-buffer (marker-buffer marker)
            (should (equal (org-iw-discovery-document-id
                            (buffer-file-name))
                           id))))
        (should (equal (org-iw-test-text marker) disk)))
      (org-iw-write-test--undo-once (marker-buffer marker))
      (should (equal (org-iw-test-text marker) text)))))

(ert-deftest org-iw-write-test-document-heading-first ()
  "With :document, a file with no text before its first heading joins.
A drawer goes before the heading, holding the rank and, with
:ensure-id, a new ID; the heading is untouched, its own ID and
membership in the queue included.  So it is whichever way the
caller's marker moves when the drawer is inserted at it."
  (dolist (text (list (org-iw-test-org "* H" "Body.")
                      (org-iw-test-heading "H" "h1")
                      (org-iw-test-heading "H" "h1" ":IW_ESSAYS: 2048")))
    (dolist (ensure-id '(nil t))
      (dolist (advance '(nil t))
        (org-iw-write-test--should-put-new-document text ensure-id
                                                    advance)))))

(defun org-iw-write-test--should-fail-plainly (marker call)
  "Assert calling CALL is a plain `error', changing nothing at MARKER.
Such an error is a caller's mistake, not a refusal.  Return the
error."
  (let* ((before (org-iw-test-snapshot marker))
         (err (should-error (funcall call))))
    (should (eq (car err) 'error))
    (should (equal (org-iw-test-snapshot marker) before))
    err))

(defun org-iw-write-test--should-misplace-document (marker)
  "Assert put-rank :document at MARKER is a plain error, changing nothing.
MARKER is not at the start of its buffer, widened."
  (org-iw-write-test--should-fail-plainly
   marker (lambda ()
            (org-iw-write-test--put-4096 marker "ESSAYS"
                                         :expected :absent :document t))))

(ert-deftest org-iw-write-test-document-marker-is-checked ()
  "With :document, a marker other than the widened start is an error.
So it is at the first heading after a preamble, inside a heading, or
at the start of a buffer narrowed to its last heading, with a
preamble or without."
  (let ((preamble (org-iw-test-org "#+title: X" "Intro." "* H" "Body."))
        (heading-first (org-iw-test-org "* H" "Body." "* I" "More.")))
    (org-iw-test-with-corpus `(("a.org" . ,preamble)
                               ("b.org" . ,heading-first))
      (let ((a (org-iw-test-visit "a.org"))
            (b (org-iw-test-visit "b.org")))
        (org-iw-write-test--should-misplace-document
         (org-iw-test-marker "a.org" "H"))
        (org-iw-write-test--should-misplace-document
         (with-current-buffer b (copy-marker (1+ (length "* H\n")))))
        (dolist (buffer (list a b))
          (with-current-buffer buffer
            (goto-char (point-max))
            (re-search-backward "^\\* ")
            (narrow-to-region (point) (point-max))
            (org-iw-write-test--should-misplace-document (point-min-marker))
            (widen)))))))

(ert-deftest org-iw-write-test-document-new-drawer-expects-absent ()
  "With :document and no text before the first heading, only :absent goes.
The file has no document entry to hold a rank, whatever the first
heading holds."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-heading "H" "h1" ":IW_ESSAYS: 2048")))
    (let ((marker (org-iw-test-marker "a.org" nil)))
      (org-iw-write-test--should-fail-plainly
       marker (lambda ()
                (org-iw-write-test--put-4096 marker "ESSAYS"
                                             :expected 2048 :document t))))))

(ert-deftest org-iw-write-test-document-new-drawer-checks-file ()
  "With :document and no text before the first heading, file checks hold.
A read-only buffer, a file changed on disk and an unwritable file
refuse, changing nothing."
  (let ((text (org-iw-test-org "* H" "Body.")))
    (dolist (setup (list (lambda (marker)
                           (with-current-buffer (marker-buffer marker)
                             (setq buffer-read-only t))
                           "buffer is read-only")
                         (lambda (_marker)
                           (org-iw-test-rewrite-behind "a.org" "* Other\n")
                           "changed on disk")
                         (lambda (_marker)
                           (unless (zerop (user-uid))
                             (org-iw-test-set-modes "a.org" #o444)
                             "not writable"))))
      (org-iw-test-with-corpus `(("a.org" . ,text))
        (let* ((marker (org-iw-test-marker "a.org" nil))
               (reason (funcall setup marker)))
          (when reason
            (should (string-search
                     reason
                     (org-iw-write-test--should-refuse
                      marker "ESSAYS" :expected :absent :document t)))))))))

(ert-deftest org-iw-write-test-document-with-slot-is-unchanged ()
  "With text before the first heading, :document changes nothing.
The file comes out as it does without :document."
  (pcase-dolist (`(,text ,expected)
                 `((,(org-iw-test-org "#+title: X" "Intro." "* H") :absent)
                   (,(org-iw-test-org ":PROPERTIES:" ":ID: d1" ":END:" "* H")
                    :absent)
                   (,(org-iw-test-org ":PROPERTIES:" ":ID: d1"
                                      ":IW_ESSAYS: 2048" ":END:" "* H")
                    2048)))
    (let ((results
           (mapcar
            (lambda (document)
              (org-iw-test-with-corpus `(("a.org" . ,text))
                (should (eq (org-iw-write-put-rank
                             (org-iw-test-marker "a.org" nil)
                             "ESSAYS" 1024 :expected expected
                             :document document)
                            'saved))
                (org-iw-test-file-string "a.org")))
            '(nil t))))
      (should-not (equal (car results) text))
      (should (equal (car results) (cadr results))))))

(defun org-iw-write-test--delete-document (marker)
  "Delete the rank 1024 in ESSAYS of the document entry at MARKER."
  (org-iw-write-delete-rank marker "ESSAYS" :expected 1024))

(ert-deftest org-iw-write-test-delete-document-drawer ()
  "A document entry's last line takes its emptied drawer with it.
Joining and leaving restore the file, with text before the first
heading or without; a drawer that was the only text before it goes
too, and one undo brings it back.  Nothing deleted is still an error."
  (pcase-dolist (`(,text ,document)
                 `((,(org-iw-test-org "* H" "Body.") t)
                   (,(org-iw-test-org "#+title: X" "Intro." "* H") nil)))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" nil)))
        (should (eq (org-iw-write-put-rank marker "ESSAYS" 1024
                                           :expected :absent
                                           :document document)
                    'saved))
        (should (eq (org-iw-write-test--delete-document marker) 'saved))
        (should (equal (org-iw-test-file-string "a.org") text)))))
  (let ((text (org-iw-test-org ":PROPERTIES:" ":IW_ESSAYS: 1024" ":END:"
                               "* H")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" nil)))
        (should (eq (org-iw-write-test--delete-document marker) 'saved))
        (should (equal (org-iw-test-file-string "a.org") "* H\n"))
        (org-iw-write-test--undo-once (marker-buffer marker))
        (should (equal (org-iw-test-text marker) text)))))
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-org ":PROPERTIES:" ":IW_ESSAYS: 2048" ":END:"
                                     "* H")))
    (let ((marker (org-iw-test-marker "a.org" nil)))
      (should (equal (org-iw-write-test--should-fail-plainly
                      marker
                      (lambda ()
                        (org-iw-write-test--delete-target-with-nothing-deleted
                         marker)))
                     '(error "IW_ESSAYS not deleted alone"))))))

(ert-deftest org-iw-write-test-delete-rank-heading-rank-only-drawer ()
  "A heading's drawer holding only the rank still may not go.
So it is for a heading at the start of the file, and for one after
text before it, where the file's document entry is."
  (dolist (text (list (org-iw-test-heading "H" nil ":IW_ESSAYS: 2048")
                      (concat (org-iw-test-org "#+title: X")
                              (org-iw-test-heading "H" nil
                                                   ":IW_ESSAYS: 2048"))))
    (should (equal (org-iw-write-test--check-rollback
                    text "H" nil 'error
                    (lambda (marker)
                      (org-iw-write-delete-rank marker "ESSAYS"
                                                :expected 2048)))
                   '(error "IW_ESSAYS not deleted alone")))))

;;;; File problems

(defun org-iw-write-test--problems (name &optional buffer)
  "Return the file problems of corpus file NAME, with BUFFER if given."
  (org-iw-write-file-problems (file-truename (org-iw-test-path name)) buffer))

(defun org-iw-write-test--literal-buffer (name)
  "Return a buffer visiting corpus file NAME in fundamental mode."
  (find-file-literally (org-iw-test-path name)))

(ert-deftest org-iw-write-test-file-problems-clean ()
  "A clean visited file, found by default, has no problems."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (org-iw-test-visit "a.org")
    (should-not (org-iw-write-test--problems "a.org"))))

(ert-deftest org-iw-write-test-file-problems-each-alone ()
  "Each problem is reported alone when it alone holds."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target)
                             ("b.org" . ,org-iw-write-test--target)
                             ("c.org" . ,org-iw-write-test--target))
    (org-iw-test-visit "a.org")
    (org-iw-test-rewrite-behind "a.org" "* Else\n")
    (should (equal (org-iw-write-test--problems "a.org") '(changed-on-disk)))
    (with-current-buffer (org-iw-test-visit "b.org")
      (setq buffer-read-only t))
    (should (equal (org-iw-write-test--problems "b.org") '(read-only)))
    (org-iw-test-edit-elsewhere (org-iw-test-marker "c.org" "Target"))
    (should (equal (org-iw-write-test--problems "c.org") '(modified)))))

(ert-deftest org-iw-write-test-file-problems-not-writable-unvisited ()
  "Without a buffer only `not-writable' can hold, and nothing is visited."
  (org-iw-test-unless-root
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
      (let ((before (org-iw-test-state)))
        (should-not (org-iw-write-test--problems "a.org"))
        (org-iw-test-set-modes "a.org" #o444)
        (should (equal (org-iw-write-test--problems "a.org") '(not-writable)))
        (should-not (find-buffer-visiting (org-iw-test-path "a.org")))
        (should (equal (org-iw-test-state) before))))))

(ert-deftest org-iw-write-test-file-problems-not-org ()
  "A buffer not in Org mode reports `not-org', with discovery's text."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (org-iw-write-test--literal-buffer "a.org")
    (should (equal (org-iw-write-test--problems "a.org") '(not-org)))
    (should (equal (org-iw-write-problem-text 'not-org)
                   "buffer not in Org mode"))))

(ert-deftest org-iw-write-test-file-problems-indirect-read-only ()
  "Read-only holds once, if the base or the indirect buffer is read-only."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target"))
          (base-read-only
           (lambda (value)
             (with-current-buffer (org-iw-test-visit "a.org")
               (setq buffer-read-only value)))))
      (org-iw-test-call-with-indirect
       marker
       (lambda (_)
         (let ((indirect (current-buffer)))
           (should-not (org-iw-write-test--problems "a.org" indirect))
           (setq buffer-read-only t)
           (should (equal (org-iw-write-test--problems "a.org" indirect)
                          '(read-only)))
           (funcall base-read-only t)
           (should (equal (org-iw-write-test--problems "a.org" indirect)
                          '(read-only)))
           (setq buffer-read-only nil)
           (should (equal (org-iw-write-test--problems "a.org" indirect)
                          '(read-only)))))))))

(ert-deftest org-iw-write-test-file-problems-order ()
  "Problems come in the documented order, whatever the order they arose."
  (org-iw-test-unless-root
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
      (with-current-buffer (org-iw-write-test--literal-buffer "a.org")
        (insert "User edit.\n")
        (setq buffer-read-only t))
      (org-iw-test-rewrite-behind "a.org" "* Else\n")
      (org-iw-test-set-modes "a.org" #o444)
      (should (equal (org-iw-write-test--problems "a.org")
                     '(changed-on-disk not-writable read-only not-org
                                       modified))))))

(ert-deftest org-iw-write-test-file-problems-visits-nothing ()
  "Asking about an unvisited file visits and changes nothing."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((before (org-iw-test-state)))
      (should-not (org-iw-write-test--problems "a.org"))
      (should-not (find-buffer-visiting (org-iw-test-path "a.org")))
      (should (equal (org-iw-test-state) before)))))

(ert-deftest org-iw-write-test-problem-text ()
  "Each problem has its text; an unknown one is a programmer error."
  (should (equal (mapcar #'org-iw-write-problem-text
                         '(changed-on-disk not-writable read-only not-org
                                           modified))
                 '("changed on disk; revert first" "not writable"
                   "buffer is read-only" "buffer not in Org mode"
                   "unsaved changes")))
  (should-error (org-iw-write-problem-text 'bogus) :type 'error))

(ert-deftest org-iw-write-test-refuses-not-org-buffer ()
  "Writing through a buffer not in Org mode refuses, naming the file."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (with-current-buffer
                      (org-iw-write-test--literal-buffer "a.org")
                    (copy-marker (point-min)))))
      (org-iw-write-test--should-refuse-each marker "buffer not in Org mode"))))

(provide 'org-iw-write-test)
;;; org-iw-write-test.el ends here
