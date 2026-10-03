;;; org-iw-core.el --- Pure ordering core for org-iw  -*- lexical-binding: t; -*-

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

;; Pure data and ordering rules for org-iw queues: entry structs,
;; queue-ID and property classification, rank parsing, queue order,
;; placements and rank allocation.  No Org, no buffers.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defconst org-iw-core-rank-spacing 1024
  "Gap between successively allocated ranks.")

(defconst org-iw-core-rank-limit (1- (expt 2 53))
  "Largest permitted rank magnitude, for both signs.")

(define-error 'org-iw-refusal "org-iw refused" 'user-error)

(defun org-iw-core-refuse (format-string &rest args)
  "Signal `org-iw-refusal' with FORMAT-STRING formatted with ARGS.
Uses `format', not `format-message', which would curl apostrophes."
  (signal 'org-iw-refusal (list (apply #'format format-string args))))

(cl-defstruct (org-iw-entry (:constructor org-iw-entry-create)
                            (:copier nil))
  "A queue entry: an Org heading or document with an ID."
  id          ; string, Org ID, compared case-sensitively
  title       ; string for display
  file        ; absolute truename
  memberships ; alist (CANONICAL-QUEUE-ID . INTEGER-RANK)
  outline)    ; ancestor heading strings, outermost first; nil at top
              ; level and for a document entry

(cl-defstruct (org-iw-problem (:constructor org-iw-problem-create)
                              (:copier nil))
  "A problem found while scanning for entries."
  type        ; symbol naming the problem
  file        ; truename
  id)         ; entry ID or nil

(defun org-iw-core-queue-id (string)
  "Return STRING as a canonical (upcased) queue ID, or nil if invalid.
Validity is judged on the raw string, so that upcasing cannot admit
characters such as ß."
  (let ((case-fold-search nil))
    (and (stringp string)
         (string-match-p "\\`[A-Za-z0-9-]+\\'" string)
         (upcase string))))

(defun org-iw-core-canonical-queue-id-p (object)
  "Return non-nil if OBJECT is a canonical queue ID string.
That is, a valid queue ID that `org-iw-core-queue-id' leaves unchanged."
  (and (stringp object)
       (equal (org-iw-core-queue-id object) object)))

(defun org-iw-core-classify-property (name)
  "Classify the property NAME.
Return (member . QUEUE-ID) for a queue membership, and
\(accumulate . QUEUE-ID) for its IW_<QUEUE-ID>+ form in Org's
accumulate syntax.  Return `reserved' for an IW_AFTER_ name,
`invalid' for any other IW_ name, and nil for names outside the IW_
namespace.  Prefixes match case-insensitively."
  (let ((case-fold-search t))
    (cond
     ((not (string-match-p "\\`IW_" name)) nil)
     ((string-match-p "\\`IW_AFTER_" name) 'reserved)
     ((string-suffix-p "+" name)
      (if-let* ((id (org-iw-core-queue-id (substring name 3 -1))))
          (cons 'accumulate id)
        'invalid))
     (t (if-let* ((id (org-iw-core-queue-id (substring name 3))))
            (cons 'member id)
          'invalid)))))

(defun org-iw-core-rank-p (object)
  "Return non-nil if OBJECT is an integer rank within the limit.
The magnitude may be at most `org-iw-core-rank-limit'."
  (and (integerp object) (<= (abs object) org-iw-core-rank-limit)))

(defun org-iw-core-parse-rank (value)
  "Return VALUE, a string, as an integer rank, or nil if unacceptable.
Surrounding whitespace is ignored.  Magnitudes beyond
`org-iw-core-rank-limit' are rejected."
  (when (stringp value)
    (let ((case-fold-search nil)
          (text (string-trim value)))
      (when (string-match-p "\\`[+-]?[0-9]+\\'" text)
        (let ((rank (string-to-number text)))
          (and (org-iw-core-rank-p rank) rank))))))

(defun org-iw-core-rank (entry queue)
  "Return the rank of ENTRY in QUEUE, or nil if not a member."
  (alist-get queue (org-iw-entry-memberships entry) nil nil #'string=))

(defun org-iw-core-queue-order (entries queue)
  "Return the members of QUEUE among ENTRIES, in queue order.
Order is by rank, then by entry ID with `string<'.  ENTRIES is not
modified."
  (seq-sort
   (lambda (a b)
     (let ((ra (org-iw-core-rank a queue))
           (rb (org-iw-core-rank b queue)))
       (if (= ra rb)
           (string< (org-iw-entry-id a) (org-iw-entry-id b))
         (< ra rb))))
   (seq-filter (lambda (entry) (org-iw-core-rank entry queue)) entries)))

(defun org-iw-core-queue-ids (entries)
  "Return the sorted, unique queue IDs present among ENTRIES."
  (sort (seq-uniq
         (seq-mapcat (lambda (entry)
                       (mapcar #'car (org-iw-entry-memberships entry)))
                     entries)
         #'string=)
        #'string<))

;;;; Placements

(defun org-iw-core-placement-p (object)
  "Return non-nil if OBJECT is a placement.
A placement says where a member goes among the others of its queue:
\(after N) after N others, N a natural number; (fraction NUM DEN)
NUM/DEN of the way back, natural numbers with 0 < DEN and NUM <= DEN;
\(percent P) P percent of the way back, a natural number P <= 100;
or `end', after all the others."
  (pcase object
    ('end t)
    (`(after ,(pred natnump)) t)
    (`(fraction ,(and (pred natnump) num) ,(and (pred natnump) den))
     (and (< 0 den) (<= num den)))
    (`(percent ,(and (pred natnump) p)) (<= p 100))))

(defun org-iw-core-placement-depth (placement count)
  "Return how many of COUNT others precede a member at PLACEMENT.
The result is in [0, COUNT].  A fraction rounds down, in exact integer
arithmetic.  Signal `wrong-type-argument' if PLACEMENT is not a
placement."
  (unless (org-iw-core-placement-p placement)
    (signal 'wrong-type-argument (list 'org-iw-core-placement-p placement)))
  (pcase placement
    ('end count)
    (`(after ,n) (min n count))
    (`(fraction ,num ,den) (floor (* count num) den))
    (`(percent ,p) (org-iw-core-placement-depth `(fraction ,p 100) count))))

;;;; Allocation

(defun org-iw-core-rank-at (others queue depth)
  "Return a rank placing a member at DEPTH among OTHERS in QUEUE, or nil.
OTHERS are members of QUEUE in queue order, and DEPTH, in [0, length
of OTHERS], is how many of them precede the member.  The rank is
`org-iw-core-rank-spacing' when OTHERS is empty, a spacing past the
last or before the first, and otherwise the floor of the mean of the
neighbours' ranks.  Return nil if that rank is not strictly between
the neighbours or exceeds `org-iw-core-rank-limit'."
  (let* ((ranks (mapcar (lambda (entry) (org-iw-core-rank entry queue))
                        others))
         (before (and (< 0 depth) (nth (1- depth) ranks)))
         (after (nth depth ranks))
         (rank (cond ((and before after)
                      (and (< 1 (- after before)) (floor (+ before after) 2)))
                     (before (+ before org-iw-core-rank-spacing))
                     (after (- after org-iw-core-rank-spacing))
                     (t org-iw-core-rank-spacing))))
    (and (org-iw-core-rank-p rank) rank)))

;;;; Placing

(defun org-iw-core-place (order target queue placement)
  "Decide how to put TARGET at PLACEMENT among ORDER, members of QUEUE.
ORDER is in queue order.  TARGET is an element of ORDER, compared with
`eq', or nil for an entry joining QUEUE.  DEPTH below is the
placement's depth among ORDER without TARGET.  Return one of:

  (unchanged DEPTH)   TARGET is already at DEPTH; write nothing.
  (moved DEPTH RANK)  write RANK to TARGET.
  (no-gap DEPTH)      no rank is allowed there; write nothing.

A nil TARGET is never unchanged."
  (let* ((others (remq target order))
         (depth (org-iw-core-placement-depth placement (length others))))
    (if (eql (seq-position order target #'eq) depth)
        (list 'unchanged depth)
      (if-let* ((rank (org-iw-core-rank-at others queue depth)))
          (list 'moved depth rank)
        (list 'no-gap depth)))))

(defun org-iw-core-reorder (order target depth)
  "Return ORDER with TARGET moved to DEPTH among the others.
TARGET is an element of ORDER, compared with `eq'.  ORDER is not
modified."
  (let ((others (remq target order)))
    (append (seq-take others depth) (list target) (seq-drop others depth))))

;;;; Relative moves

(defun org-iw-core-beside (order target anchor side)
  "Return the placement of TARGET on SIDE of ANCHOR among ORDER.
SIDE is `before' or `after'.  TARGET and ANCHOR are elements of ORDER,
compared with `eq'.  The anchor's index is counted among ORDER without
TARGET, as `org-iw-core-place' counts depth.  When ANCHOR is TARGET the
placement is TARGET's own index, which leaves it unchanged."
  (if (eq anchor target)
      (list 'after (seq-position order target #'eq))
    (let ((anchor-index (seq-position (remq target order) anchor #'eq)))
      (list 'after (cl-ecase side
                     (before anchor-index)
                     (after (1+ anchor-index)))))))

(defun org-iw-core-step (order target delta)
  "Return the placement of TARGET DELTA places along ORDER.
TARGET is an element of ORDER, compared with `eq'.  A step past either
end stops at that end."
  (list 'after (max 0 (min (1- (length order))
                           (+ (seq-position order target #'eq) delta)))))

(provide 'org-iw-core)
;;; org-iw-core.el ends here
