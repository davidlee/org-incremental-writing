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

(ert-deftest org-iw-core-test-canonical-queue-id-p ()
  "Only an already-canonical queue ID string is canonical."
  (dolist (good '("ESSAYS" "AFTER-X"))
    (should (org-iw-core-canonical-queue-id-p good)))
  (dolist (bad '("essays" "Essays" "ESS_AYS" "" nil))
    (should-not (org-iw-core-canonical-queue-id-p bad))))

(ert-deftest org-iw-core-test-queue-id ()
  "Queue IDs are validated raw, then upcased."
  (should (equal (org-iw-core-queue-id "essays") "ESSAYS"))
  (should (equal (org-iw-core-queue-id "A-1") "A-1"))
  (dolist (bad '("" "a_b" "a b" "straße" 5 nil))
    (should-not (org-iw-core-queue-id bad))))

(ert-deftest org-iw-core-test-classify-property ()
  "Property names classify as member, accumulate, reserved, invalid or nil."
  (should (equal (org-iw-core-classify-property "IW_ESSAYS")
                 '(member . "ESSAYS")))
  (should (equal (org-iw-core-classify-property "iw_essays")
                 '(member . "ESSAYS")))
  (should (equal (org-iw-core-classify-property "IW_AFTER-X")
                 '(member . "AFTER-X")))
  (should (equal (org-iw-core-classify-property "IW_AFTER")
                 '(member . "AFTER")))
  (should (equal (org-iw-core-classify-property "IW_ESSAYS+")
                 '(accumulate . "ESSAYS")))
  (should (equal (org-iw-core-classify-property "iw_essays+")
                 '(accumulate . "ESSAYS")))
  (should (equal (org-iw-core-classify-property "IW_AFTER+")
                 '(accumulate . "AFTER")))
  (dolist (name '("IW_AFTER_ESSAYS" "iw_after_x" "IW_AFTER_" "IW_AFTER_X+"))
    (should (eq (org-iw-core-classify-property name) 'reserved)))
  (dolist (name '("IW_ess_ays" "IW_straße" "IW_" "IW_+" "IW_ess_ays+"
                  "IW_ESSAYS++"))
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

(ert-deftest org-iw-core-test-rank-p ()
  "A rank is an integer of magnitude at most the literal limit."
  (dolist (good '(0 -5 9007199254740991 -9007199254740991))
    (should (org-iw-core-rank-p good)))
  (dolist (bad '(9007199254740992 -9007199254740992 1.5 "1024" nil))
    (should-not (org-iw-core-rank-p bad))))

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

;;;; Placements

(ert-deftest org-iw-core-test-placement-p ()
  "Each placement form is accepted at its bounds; malformed ones are not."
  (dolist (good '((after 0) (after 2) (fraction 0 1) (fraction 1 2)
                  (fraction 1 1) (percent 0) (percent 29) (percent 100) end))
    (should (org-iw-core-placement-p good)))
  (dolist (bad '((after -1) (after 1.5) (after) (after 1 2)
                 (fraction 1 0) (fraction 0 0) (fraction 3 2) (fraction 0.5 1)
                 (fraction -1 2) (fraction 1) (fraction 1 2 3)
                 (percent 101) (percent -1) (percent 50.0) (percent 1 2)
                 soon (end) after nil "end" (soon 1)))
    (should-not (org-iw-core-placement-p bad))))

(ert-deftest org-iw-core-test-placement-depth ()
  "Depth counts the others ahead of the target, clamped to COUNT."
  (pcase-dolist (`(,placement ,count ,depth)
                 '(((after 2) 5 2) ((fraction 1 2) 5 2) ((after 10) 3 3)
                   ((after 0) 5 0) ((percent 29) 100 29) ((fraction 1 3) 3 1)
                   (end 0 0) (end 7 7) ((fraction 1 1) 4 4)
                   ((fraction 0 1) 4 0) ((percent 0) 9 0) ((percent 100) 9 9)
                   ((percent 50) 3 1) ((after 2) 0 0)))
    (should (equal (list placement count
                         (org-iw-core-placement-depth placement count))
                   (list placement count depth)))))

(ert-deftest org-iw-core-test-placement-depth-rejects-invalid ()
  "An invalid placement is a programming error, not a refusal."
  (dolist (bad '(soon (after -1) (fraction 1 0)))
    (should-error (org-iw-core-placement-depth bad 3)
                  :type 'wrong-type-argument)))

;;;; Allocation

(defun org-iw-core-test--queue (&rest ranks)
  "Return entries q1, q2, … of queue Q with RANKS, in that order."
  (seq-map-indexed (lambda (rank i)
                     (org-iw-core-test--entry (format "q%d" (1+ i))
                                              (cons "Q" rank)))
                   ranks))

(defun org-iw-core-test--rank-at (depth &rest ranks)
  "Return `org-iw-core-rank-at' at DEPTH among others ranked RANKS in Q."
  (org-iw-core-rank-at (apply #'org-iw-core-test--queue ranks) "Q" depth))

(ert-deftest org-iw-core-test-rank-at ()
  "Each ADR-004 allocation case, with the spacing as a literal."
  (should (= (org-iw-core-test--rank-at 0) 1024))
  (should (= (org-iw-core-test--rank-at 0 3072 4096) 2048))
  (should (= (org-iw-core-test--rank-at 2 3072 4096) 5120))
  (should (= (org-iw-core-test--rank-at 1 3072 4096) 3584))
  (should (= (org-iw-core-test--rank-at 1 -2048 -1024) -1536))
  (should (= (org-iw-core-test--rank-at 1 -3 0) -2))
  (should (= (org-iw-core-test--rank-at 1 5 7) 6)))

(ert-deftest org-iw-core-test-rank-at-reads-its-queue ()
  "Ranks in other queues are ignored."
  (should (= (org-iw-core-rank-at
              (list (org-iw-core-test--entry "a" '("Z" . 99) '("Q" . 5)))
              "Q" 1)
             1029)))

(ert-deftest org-iw-core-test-rank-at-no-gap ()
  "No rank for adjacent or tied neighbours, or past either limit."
  (let ((limit 9007199254740991))
    (should-not (org-iw-core-test--rank-at 1 5 6))
    (should-not (org-iw-core-test--rank-at 1 7 7))
    (should (= (org-iw-core-test--rank-at 1 (- limit 1024)) limit))
    (should-not (org-iw-core-test--rank-at 1 (- limit 1023)))
    (should (= (org-iw-core-test--rank-at 0 (- 1024 limit)) (- limit)))
    (should-not (org-iw-core-test--rank-at 0 (- 1023 limit)))))

;;;; Placing

(ert-deftest org-iw-core-test-place-unchanged ()
  "A target already at its depth is unchanged, whatever its rank."
  (let ((order (org-iw-core-test--queue 1024 2048 3072 4096)))
    (should (equal (org-iw-core-place order (nth 3 order) "Q" 'end)
                   '(unchanged 3)))
    (should (equal (org-iw-core-place order (car order) "Q" '(after 0))
                   '(unchanged 0)))
    (should (equal (org-iw-core-place order (nth 2 order) "Q" '(after 2))
                   '(unchanged 2))))
  (let ((tied (org-iw-core-test--queue 5 5 6)))
    (should (equal (org-iw-core-place tied (nth 1 tied) "Q" '(after 1))
                   '(unchanged 1)))))

(ert-deftest org-iw-core-test-place-moved ()
  "A target elsewhere moves to the rank between its new neighbours."
  (let ((order (org-iw-core-test--queue 1024 2048 3072 4096)))
    (should (equal (org-iw-core-place order (car order) "Q" '(after 2))
                   '(moved 2 3584)))
    (should (equal (org-iw-core-place order (car order) "Q" 'end)
                   '(moved 3 5120)))
    (should (equal (org-iw-core-place order (nth 3 order) "Q" '(after 0))
                   '(moved 0 0)))
    (should (equal (org-iw-core-place order (car order) "Q"
                                      '(fraction 1 2))
                   '(moved 1 2560)))))

(ert-deftest org-iw-core-test-place-new-member ()
  "A nil target joins the queue and is never unchanged."
  (should (equal (org-iw-core-place nil nil "Q" 'end) '(moved 0 1024)))
  (should (equal (org-iw-core-place nil nil "Q" '(after 0)) '(moved 0 1024)))
  (let ((order (org-iw-core-test--queue 1024 2048)))
    (should (equal (org-iw-core-place order nil "Q" 'end) '(moved 2 3072)))
    (should (equal (org-iw-core-place order nil "Q" '(after 1))
                   '(moved 1 1536)))))

(ert-deftest org-iw-core-test-place-no-gap ()
  "No allowed rank at the depth is no-gap, never a move."
  (let ((order (org-iw-core-test--queue 5 6 1024)))
    (should (equal (org-iw-core-place order (nth 2 order) "Q" '(after 1))
                   '(no-gap 1))))
  (let ((order (org-iw-core-test--queue 5 6)))
    (should (equal (org-iw-core-place order nil "Q" '(after 1))
                   '(no-gap 1))))
  (let ((order (org-iw-core-test--queue 1 9007199254740991)))
    (should (equal (org-iw-core-place order (car order) "Q" 'end)
                   '(no-gap 1)))))

(ert-deftest org-iw-core-test-reorder ()
  "Reorder moves the target to a depth among the others, copying ORDER."
  (let* ((order (org-iw-core-test--queue 1 2 3 4))
         (copy (copy-sequence order))
         (target (nth 1 order)))
    (should (equal (org-iw-core-test--ids
                    (org-iw-core-reorder order target 0))
                   '("q2" "q1" "q3" "q4")))
    (should (equal (org-iw-core-test--ids
                    (org-iw-core-reorder order target 2))
                   '("q1" "q3" "q2" "q4")))
    (should (equal (org-iw-core-test--ids
                    (org-iw-core-reorder order target 3))
                   '("q1" "q3" "q4" "q2")))
    (should (equal order copy))))

;;;; Placing: property

(defun org-iw-core-test--pick (list)
  "Return a random element of LIST."
  (nth (random (length list)) list))

(defun org-iw-core-test--random-rank ()
  "Return a random rank: small, spaced, or near either limit."
  (let ((limit 9007199254740991))
    (pcase (random 3)
      (0 (- (random 7) 3))
      (1 (* 1024 (- (random 9) 4)))
      (_ (* (org-iw-core-test--pick '(1 -1))
            (- limit (org-iw-core-test--pick '(0 1 1023 1024 1025 2048))))))))

(defun org-iw-core-test--random-placement ()
  "Return a random placement, clamping cases included."
  (pcase (random 4)
    (0 (list 'after (random 9)))
    (1 (let ((den (1+ (random 4)))) (list 'fraction (random (1+ den)) den)))
    (2 (list 'percent (random 101)))
    (_ 'end)))

(defun org-iw-core-test--random-case ()
  "Return a random (ORDER TARGET PLACEMENT) for `org-iw-core-place'.
ORDER has up to six members of Q, ties included; TARGET is one of
them or nil."
  (let* ((order (org-iw-core-queue-order
                 (mapcar (lambda (i)
                           (org-iw-core-test--entry
                            (format "e%d" i)
                            (cons "Q" (org-iw-core-test--random-rank))))
                         (number-sequence 1 (random 7)))
                 "Q"))
         (target (org-iw-core-test--pick (cons nil order))))
    (list order target (org-iw-core-test--random-placement))))

(defun org-iw-core-test--allowed-p (others depth)
  "Return non-nil if ADR-004 allows a rank at DEPTH among OTHERS of Q.
Restated independently of `org-iw-core-rank-at'."
  (let ((ranks (mapcar (lambda (e) (org-iw-core-rank e "Q")) others)))
    (cond ((null ranks) t)
          ((= depth (length ranks))
           (org-iw-core-rank-p (+ (car (last ranks)) 1024)))
          ((= depth 0) (org-iw-core-rank-p (- (car ranks) 1024)))
          (t (> (- (nth depth ranks) (nth (1- depth) ranks)) 1)))))

(defun org-iw-core-test--check-place (order target placement result)
  "Return nil if RESULT is right for placing TARGET at PLACEMENT in ORDER.
Otherwise return a string saying what is wrong.  The outcomes are
checked in precedence order: unchanged, then no-gap, then moved."
  (let* ((others (remq target order))
         (depth (org-iw-core-placement-depth placement (length others)))
         (entry (or target (org-iw-core-test--entry "new")))
         (wanted (org-iw-core-reorder (cons entry others) entry depth)))
    (cond
     ((and target (equal (org-iw-core-reorder order target depth) order))
      (unless (equal result (list 'unchanged depth)) "should be unchanged"))
     ((not (org-iw-core-test--allowed-p others depth))
      (unless (equal result (list 'no-gap depth)) "should be no-gap"))
     (t
      (pcase result
        (`(moved ,(pred (eql depth)) ,(and (pred org-iw-core-rank-p) rank))
         (let ((moved (org-iw-core-test--entry (org-iw-entry-id entry)
                                               (cons "Q" rank))))
           (unless (equal (org-iw-core-test--ids
                           (org-iw-core-queue-order (cons moved others) "Q"))
                          (org-iw-core-test--ids wanted))
             "moved rank does not sort to the depth")))
        (_ "should be moved at the depth"))))))

(defun org-iw-core-test--place-cases ()
  "Return 500 seeded random cases for `org-iw-core-place'."
  (random "org-iw-core-test-place")
  (mapcar (lambda (_) (org-iw-core-test--random-case))
          (number-sequence 1 500)))

(defun org-iw-core-test--rejections (place)
  "Return how many seeded cases the checker rejects for PLACE.
PLACE is called like `org-iw-core-place'."
  (seq-count (pcase-lambda (`(,order ,target ,placement))
               (org-iw-core-test--check-place
                order target placement
                (funcall place order target "Q" placement)))
             (org-iw-core-test--place-cases)))

(ert-deftest org-iw-core-test-place-property ()
  "Place is right on 500 seeded random cases, each outcome among them."
  (let ((outcomes nil))
    (pcase-dolist (`(,order ,target ,placement)
                   (org-iw-core-test--place-cases))
      (let ((result (org-iw-core-place order target "Q" placement)))
        (push (car result) outcomes)
        (should-not (org-iw-core-test--check-place
                     order target placement result))))
    (dolist (outcome '(unchanged moved no-gap))
      (should (< 20 (seq-count (apply-partially #'eq outcome) outcomes))))))

(defun org-iw-core-test--ranks (order)
  "Return the ranks in Q of the entries of ORDER."
  (mapcar (lambda (entry) (org-iw-core-rank entry "Q")) order))

(ert-deftest org-iw-core-test-place-cases-reach-edges ()
  "The seeded cases include each edge the property must hold at.
Each edge is called with a case's ORDER, TARGET and PLACEMENT."
  (let ((cases (org-iw-core-test--place-cases)))
    (pcase-dolist
        (`(,wanted ,edge)
         `((20 ,(lambda (order target _) (and order (null target))))
           (20 ,(lambda (order _ _) (nthcdr 3 order)))
           (20 ,(lambda (_ _ placement) (eq placement 'end)))
           (20 ,(lambda (_ _ placement) (eq (car-safe placement) 'after)))
           (20 ,(lambda (_ _ placement) (eq (car-safe placement) 'fraction)))
           (20 ,(lambda (_ _ placement) (eq (car-safe placement) 'percent)))
           (20 ,(lambda (order _ _)
                  (seq-some #'cl-minusp (org-iw-core-test--ranks order))))
           (20 ,(lambda (order _ _)
                  (let ((ranks (org-iw-core-test--ranks order)))
                    (/= (length ranks) (length (seq-uniq ranks))))))
           (5 ,(lambda (order _ _)
                 (let ((ranks (org-iw-core-test--ranks order)))
                   (cl-some (lambda (a b) (= (- b a) 1)) ranks (cdr ranks)))))
           (5 ,(lambda (order _ _)
                 (memql 9007199254740991
                        (mapcar #'abs (org-iw-core-test--ranks order)))))))
      (should (< wanted (seq-count (lambda (case) (apply edge case)) cases))))))

(ert-deftest org-iw-core-test-place-checker-self-test ()
  "The property checker rejects each kind of wrong result."
  (let ((wrong
         (list
          (lambda (&rest _) '(unchanged 0))
          (lambda (&rest args)
            (pcase-let ((`(,tag ,depth . ,rest) (apply #'org-iw-core-place args)))
              `(,tag ,(1+ depth) ,@rest)))
          (lambda (&rest args)
            (pcase (apply #'org-iw-core-place args)
              (`(moved ,depth ,_) (list 'no-gap depth))
              (result result)))
          (lambda (&rest args)
            (pcase (apply #'org-iw-core-place args)
              (`(unchanged ,depth) (list 'no-gap depth))
              (result result)))
          (lambda (&rest args)
            (pcase (apply #'org-iw-core-place args)
              (`(moved ,depth ,rank) (list 'moved (1+ depth) rank))
              (result result)))
          (lambda (&rest args)
            (pcase (apply #'org-iw-core-place args)
              (`(moved ,depth ,_) (list 'moved depth 0))
              (result result)))
          ;; Into an empty queue any rank sorts right, so only the
          ;; limit check can reject this one.
          (lambda (order &rest args)
            (pcase (apply #'org-iw-core-place order args)
              (`(moved ,depth ,rank)
               (list 'moved depth
                     (if order rank (+ rank 9007199254740991))))
              (result result))))))
    (should (zerop (org-iw-core-test--rejections #'org-iw-core-place)))
    (dolist (place wrong)
      (should (< 0 (org-iw-core-test--rejections place))))))

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
