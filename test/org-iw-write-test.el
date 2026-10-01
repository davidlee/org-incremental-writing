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

;; ERT tests for `org-iw-write-put-rank': the preflight refusals, the
;; atomic edit and the save policy.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-iw-test-helpers)
(require 'org-iw-write)

;;;; Helpers

(defun org-iw-write-test--should-refuse (marker queue &rest keys)
  "Assert that put-rank at MARKER in QUEUE refuses, changing nothing.
KEYS are the keyword arguments.  The refusal must be an
`org-iw-refusal' naming the file; the buffer text, `buffer-modified-p'
and disk contents must be unchanged.  Return the refusal message."
  (let* ((before (org-iw-test-snapshot marker))
         (err (should-error (apply #'org-iw-write-put-rank
                                   marker queue 4096 keys)
                            :type 'org-iw-refusal))
         (reason (cadr err)))
    (should (equal (org-iw-test-snapshot marker) before))
    (should (string-search
             (buffer-file-name (org-iw-test-base marker)) reason))
    reason))

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

(defun org-iw-write-test--check-refuses (drawer-lines expected)
  "Assert put-rank refuses :expected EXPECTED over DRAWER-LINES.
DRAWER-LINES are the IW lines of a heading with an ID."
  (org-iw-test-with-corpus
      `(("a.org" . ,(apply #'org-iw-test-heading "H" "h1" drawer-lines)))
    (org-iw-write-test--should-refuse
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

(defun org-iw-write-test--check-atomic (dirty)
  "Assert that a failing edit restores everything; DIRTY first edits.
The error must propagate as is, and the buffer text,
`buffer-modified-p' and disk must equal their state before the call.
A buffer left clean holds no lock file."
  (let ((text (org-iw-test-org "* New" "Body.")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "New")))
        (when dirty
          (org-iw-test-edit-elsewhere marker))
        (let ((before (org-iw-test-snapshot marker)))
          (org-iw-write-test--call-failing-rank-put
           (lambda ()
             (should-error (org-iw-write-put-rank marker "ESSAYS" 1024
                                                  :expected :absent
                                                  :ensure-id t)
                           :type 'org-iw-write-test-injected)))
          (should (equal (org-iw-test-snapshot marker) before))
          (unless dirty
            (should-not (file-symlink-p (org-iw-test-path ".#a.org")))))))))

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

(provide 'org-iw-write-test)
;;; org-iw-write-test.el ends here
