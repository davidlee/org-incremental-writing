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
;; queue-ID and property classification, rank parsing, queue order and
;; rank allocation.  No Org, no buffers.

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
  memberships); alist (CANONICAL-QUEUE-ID . INTEGER-RANK)

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

(defun org-iw-core-append-rank (ordered queue)
  "Return a rank placing a new member after ORDERED in QUEUE.
ORDERED is a list of entries in queue order.  The result is
`org-iw-core-rank-spacing' if ORDERED is empty, else the last rank
plus the spacing.  Return nil if the result would exceed
`org-iw-core-rank-limit'."
  (let ((rank (if ordered
                  (+ (org-iw-core-rank (car (last ordered)) queue)
                     org-iw-core-rank-spacing)
                org-iw-core-rank-spacing)))
    (and (org-iw-core-rank-p rank) rank)))

(provide 'org-iw-core)
;;; org-iw-core.el ends here
