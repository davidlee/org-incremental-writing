;;; org-iw-core-test.el --- Tests for org-iw-core  -*- lexical-binding: t; -*-

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

;; ERT tests for the pure ordering core.

;;; Code:

(require 'ert)
(require 'org-iw-core)

(defconst org-iw-core-test--file (or load-file-name buffer-file-name)
  "Path of this test file, captured at load time.")

(defun org-iw-core-test--entry (id &rest memberships)
  "Make an entry with ID and MEMBERSHIPS, a list of (QUEUE . RANK)."
  (org-iw-entry-create :id id :title id :file "/f.org"
                       :memberships memberships))

(defun org-iw-core-test--ids (entries)
  "Return the IDs of ENTRIES."
  (mapcar #'org-iw-entry-id entries))

(defun org-iw-core-test--append (queue rank)
  "Append rank in QUEUE after a single entry ranked RANK."
  (org-iw-core-append-rank
   (list (org-iw-core-test--entry "a" (cons queue rank))) queue))

(ert-deftest org-iw-core-test-queue-id ()
  "Queue IDs are validated raw, then upcased."
  (should (equal (org-iw-core-queue-id "essays") "ESSAYS"))
  (should (equal (org-iw-core-queue-id "A-1") "A-1"))
  (dolist (bad '("" "a_b" "a b" "straße" 5 nil))
    (should-not (org-iw-core-queue-id bad))))

(ert-deftest org-iw-core-test-classify-property ()
  "Property names classify as member, reserved, invalid or nil."
  (should (equal (org-iw-core-classify-property "IW_ESSAYS")
                 '(member . "ESSAYS")))
  (should (equal (org-iw-core-classify-property "iw_essays")
                 '(member . "ESSAYS")))
  (should (equal (org-iw-core-classify-property "IW_AFTER-X")
                 '(member . "AFTER-X")))
  (should (equal (org-iw-core-classify-property "IW_AFTER")
                 '(member . "AFTER")))
  (dolist (name '("IW_AFTER_ESSAYS" "iw_after_x" "IW_AFTER_"))
    (should (eq (org-iw-core-classify-property name) 'reserved)))
  (dolist (name '("IW_ess_ays" "IW_straße" "IW_ESSAYS+" "IW_"))
    (should (eq (org-iw-core-classify-property name) 'invalid)))
  (dolist (name '("ID" "IWX" ""))
    (should-not (org-iw-core-classify-property name))))

(ert-deftest org-iw-core-test-parse-rank-accepts ()
  "Well-formed integers parse, including the limits."
  (should (= (org-iw-core-parse-rank "-5") -5))
  (should (= (org-iw-core-parse-rank "+5") 5))
  (should (= (org-iw-core-parse-rank "007") 7))
  (should (= (org-iw-core-parse-rank " 12 ") 12))
  (should (= (org-iw-core-parse-rank
              (number-to-string org-iw-core-rank-limit))
             org-iw-core-rank-limit))
  (should (= (org-iw-core-parse-rank
              (number-to-string (- org-iw-core-rank-limit)))
             (- org-iw-core-rank-limit))))

(ert-deftest org-iw-core-test-parse-rank-rejects ()
  "Non-integers and out-of-range values are rejected."
  (dolist (bad (list "1.5" "soon" "" "1e3" "- 5" nil
                     (number-to-string (1+ org-iw-core-rank-limit))
                     (number-to-string (- (1+ org-iw-core-rank-limit)))))
    (should-not (org-iw-core-parse-rank bad))))

(ert-deftest org-iw-core-test-rank-limit-literal ()
  "The rank limit is exactly 2^53-1, in both signs, as the file format says."
  (should (= org-iw-core-rank-limit 9007199254740991))
  (should (= (org-iw-core-parse-rank "9007199254740991") 9007199254740991))
  (should (= (org-iw-core-parse-rank "-9007199254740991") -9007199254740991))
  (should-not (org-iw-core-parse-rank "9007199254740992"))
  (should-not (org-iw-core-parse-rank "-9007199254740992")))

(ert-deftest org-iw-core-test-rank ()
  "Rank reads the membership for one queue."
  (let ((e (org-iw-core-test--entry "a" '("X" . 3) '("Y" . -1))))
    (should (= (org-iw-core-rank e "Y") -1))
    (should-not (org-iw-core-rank e "Z"))))

(ert-deftest org-iw-core-test-queue-order ()
  "Members sort by rank then ID; non-members drop; input is untouched."
  (let* ((entries (list (org-iw-core-test--entry "c" '("Q" . 10))
                        (org-iw-core-test--entry "b" '("Q" . 10))
                        (org-iw-core-test--entry "n" '("OTHER" . 1))
                        (org-iw-core-test--entry
                         "a" '("Q" . 20) '("OTHER" . 0))
                        (org-iw-core-test--entry "neg" '("Q" . -7))))
         (copy (copy-sequence entries)))
    (should (equal (org-iw-core-test--ids
                    (org-iw-core-queue-order entries "Q"))
                   '("neg" "b" "c" "a")))
    (should (equal entries copy))
    (should-not (org-iw-core-queue-order entries "NONE"))))

(ert-deftest org-iw-core-test-queue-ids ()
  "Queue IDs are unique and sorted."
  (should-not (org-iw-core-queue-ids nil))
  (should (equal (org-iw-core-queue-ids
                  (list (org-iw-core-test--entry "a" '("B" . 1) '("A" . 2))
                        (org-iw-core-test--entry "b" '("B" . 3))))
                 '("A" "B"))))

(ert-deftest org-iw-core-test-append-rank ()
  "Append allocates past the last rank in the queue."
  (should (= (org-iw-core-append-rank nil "Q") 1024))
  (should (= (org-iw-core-test--append "Q" 1024) 2048))
  (should (= (org-iw-core-test--append "Q" -2048) -1024))
  (should (= (org-iw-core-append-rank
              (list (org-iw-core-test--entry "a" '("Q" . 5) '("Z" . 99)))
              "Q")
             1029)))

(ert-deftest org-iw-core-test-append-rank-limit ()
  "Append returns the limit itself, but nil beyond it."
  (let ((limit org-iw-core-rank-limit))
    (should (= (org-iw-core-test--append "Q" (- limit 1024)) limit))
    (should-not (org-iw-core-test--append "Q" (- limit 1023)))
    (should-not (org-iw-core-test--append "Q" limit))))

(ert-deftest org-iw-core-test-refusal-is-user-error ()
  "The refusal condition is a user-error."
  (should-error (signal 'org-iw-refusal '("no")) :type 'user-error))

(ert-deftest org-iw-core-test-no-org-loaded ()
  "Loading the core in a fresh Emacs never loads Org (I6)."
  :tags '(org-iw-i6)
  (let* ((root (file-name-directory
                (directory-file-name
                 (file-name-directory org-iw-core-test--file))))
         (form (concat "(let ((stats (ert-run-tests-batch"
                       " '(not (tag org-iw-i6)))))"
                       " (kill-emacs (cond ((featurep 'org) 3)"
                       " ((> (ert-stats-completed-unexpected stats) 0) 1)"
                       " (t 0))))"))
         (status nil)
         (output
          (with-temp-buffer
            (setq status
                  (call-process
                   (expand-file-name invocation-name invocation-directory)
                   nil t nil "-Q" "--batch"
                   "-L" root "-L" (expand-file-name "test" root)
                   "-l" org-iw-core-test--file "--eval" form))
            (buffer-string))))
    (unless (eql status 0)
      (ert-fail (list :exit status :output output)))))

(provide 'org-iw-core-test)
;;; org-iw-core-test.el ends here
