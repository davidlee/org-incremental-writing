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

(ert-deftest org-iw-write-test-refuses-changed-on-disk ()
  "A clean buffer whose file changed on disk refuses, with no prompt."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-rewrite-behind
       "a.org" (concat org-iw-write-test--target "* Added outside\n"))
      (should (string-search "changed on disk"
                             (org-iw-write-test--should-refuse
                              marker "ESSAYS" :expected 2048))))))

(ert-deftest org-iw-write-test-refuses-changed-on-disk-indirect ()
  "The check is on the base buffer, reached through an indirect buffer.
An indirect buffer has no file, so a check on it would pass.
The indirect buffer is made by `make-indirect-buffer' (via
`org-iw-test-call-with-indirect')."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-rewrite-behind
       "a.org" (concat org-iw-write-test--target "* Added outside\n"))
      (org-iw-test-call-with-indirect
       marker
       (lambda (indirect-marker)
         (should (string-search "changed on disk"
                                (org-iw-write-test--should-refuse
                                 indirect-marker "ESSAYS"
                                 :expected 2048))))))))

(ert-deftest org-iw-write-test-refuses-unwritable-file ()
  "A read-only file refuses (its modes set, via `set-file-modes')."
  (org-iw-test-unless-root
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
      (org-iw-test-set-modes "a.org" #o444)
      (should (string-search "not writable"
                             (org-iw-write-test--should-refuse
                              (org-iw-test-marker "a.org" "Target")
                              "ESSAYS" :expected 2048))))))

(ert-deftest org-iw-write-test-refuses-read-only-buffer ()
  "A read-only base buffer refuses (RV-002 F-1); nothing is written.
`org-entry-put' would otherwise write through `org-no-read-only'."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (with-current-buffer (org-iw-test-base marker)
        (setq buffer-read-only t))
      (should (string-search "buffer is read-only"
                             (org-iw-write-test--should-refuse
                              marker "ESSAYS" :expected 2048))))))

(ert-deftest org-iw-write-test-refuses-read-only-base-through-indirect ()
  "A read-only base refuses from a writable indirect buffer (RV-002 F-1).
The check is on the base buffer, not the one holding the marker."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (with-current-buffer (org-iw-test-base marker)
        (setq buffer-read-only t))
      (org-iw-test-call-with-indirect
       marker
       (lambda (indirect-marker)
         (setq buffer-read-only nil)
         (should (string-search "buffer is read-only"
                                (org-iw-write-test--should-refuse
                                 indirect-marker "ESSAYS"
                                 :expected 2048))))))))

(ert-deftest org-iw-write-test-refuses-read-only-indirect ()
  "A read-only indirect buffer over a writable base refuses (RV-006 F-1).
`org-entry-put' would otherwise write through `org-no-read-only'."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (org-iw-test-call-with-indirect
     (org-iw-test-marker "a.org" "Target")
     (lambda (indirect-marker)
       (setq buffer-read-only t)
       (should (string-search "buffer is read-only"
                              (org-iw-write-test--should-refuse
                               indirect-marker "ESSAYS"
                               :expected 2048)))))))

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

(defun org-iw-write-test--delete-should-refuse (marker)
  "Assert delete-rank of ESSAYS at 2048 at MARKER refuses; return why."
  (org-iw-write-test--should-refuse-by #'org-iw-write-delete-rank
                                       marker "ESSAYS" :expected 2048))

(ert-deftest org-iw-write-test-delete-rank-refuses-changed-on-disk ()
  "A file changed on disk refuses, directly and through an indirect buffer."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-rewrite-behind
       "a.org" (concat org-iw-write-test--target "* Added outside\n"))
      (should (string-search "changed on disk"
                             (org-iw-write-test--delete-should-refuse marker)))
      (org-iw-test-call-with-indirect
       marker
       (lambda (indirect-marker)
         (should (string-search "changed on disk"
                                (org-iw-write-test--delete-should-refuse
                                 indirect-marker))))))))

(ert-deftest org-iw-write-test-delete-rank-refuses-unwritable-file ()
  "A read-only file refuses."
  (org-iw-test-unless-root
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
      (org-iw-test-set-modes "a.org" #o444)
      (should (string-search "not writable"
                             (org-iw-write-test--delete-should-refuse
                              (org-iw-test-marker "a.org" "Target")))))))

(ert-deftest org-iw-write-test-delete-rank-refuses-read-only-buffer ()
  "A read-only base buffer refuses, directly and from a writable indirect.
`org-entry-delete' would otherwise delete through `org-no-read-only'."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (with-current-buffer (org-iw-test-base marker)
        (setq buffer-read-only t))
      (should (string-search "buffer is read-only"
                             (org-iw-write-test--delete-should-refuse marker)))
      (org-iw-test-call-with-indirect
       marker
       (lambda (indirect-marker)
         (setq buffer-read-only nil)
         (should (string-search "buffer is read-only"
                                (org-iw-write-test--delete-should-refuse
                                 indirect-marker))))))))

(ert-deftest org-iw-write-test-delete-rank-refuses-read-only-indirect ()
  "A read-only indirect buffer over a writable base refuses (RV-006 F-1).
Deleting from it would otherwise signal `buffer-read-only'."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-write-test--target))
    (org-iw-test-call-with-indirect
     (org-iw-test-marker "a.org" "Target")
     (lambda (indirect-marker)
       (setq buffer-read-only t)
       (should (string-search "buffer is read-only"
                              (org-iw-write-test--delete-should-refuse
                               indirect-marker)))))))

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

(provide 'org-iw-write-test)
;;; org-iw-write-test.el ends here
