;;; org-iw-write.el --- The one write path for org-iw  -*- lexical-binding: t; -*-

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

;; The write path for org-iw: `org-iw-write-put-rank' sets one entry's
;; rank in one queue through the buffer visiting its file.  It checks
;; the file and the scanned rank first, edits atomically, and saves
;; only a buffer that had no unsaved changes.  Every operation that
;; changes a queue writes through it.  This layer does not read the
;; user options of `org-iw'.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'org-iw-core)
(require 'org-iw-discovery)

(defun org-iw-write--base (marker)
  "Return the base buffer of MARKER's buffer.
An indirect buffer has no file of its own; its base visits the file."
  (let ((buffer (marker-buffer marker)))
    (or (buffer-base-buffer buffer) buffer)))

(defun org-iw-write--refuse (marker format-string &rest args)
  "Signal an `org-iw-refusal' naming the file of MARKER.
The message is FORMAT-STRING with ARGS, after the file name."
  (signal 'org-iw-refusal
          (list (format "%s: %s"
                        (buffer-file-name (org-iw-write--base marker))
                        (apply #'format format-string args)))))

(defun org-iw-write--expected-p (lines expected)
  "Return non-nil if the queue LINES hold the rank EXPECTED.
LINES are as from `org-iw-discovery--queue-lines'.  EXPECTED :absent
holds for no line at all, and an integer for a single membership
line whose value parses to it."
  (pcase lines
    ('() (eq expected :absent))
    (`((member . ,value))
     (and (integerp expected)
          (eql (org-iw-core-parse-rank value) expected)))))

(defun org-iw-write--preflight (marker queue expected)
  "Refuse unless writing QUEUE's rank at MARKER is safe.
The base buffer's file must be unchanged on disk since visited and
writable, and the entry at MARKER must hold the rank EXPECTED in
QUEUE, a canonical queue ID.  Nothing is changed."
  (let* ((base (org-iw-write--base marker))
         (file (buffer-file-name base)))
    (unless (verify-visited-file-modtime base)
      (org-iw-write--refuse marker "changed on disk; revert first"))
    (unless (file-writable-p file)
      (org-iw-write--refuse marker "not writable"))
    (unless (org-iw-write--expected-p
             (with-current-buffer (marker-buffer marker)
               (org-with-wide-buffer
                (goto-char marker)
                (org-iw-discovery--queue-lines queue)))
             expected)
      (org-iw-write--refuse marker "IW_%s changed since scan" queue))))

(defun org-iw-write--apply (marker fn)
  "Call FN at MARKER atomically; save the base buffer if it was clean.
FN runs in MARKER's buffer, widened, with point at MARKER.  If it
signals, its changes are undone, which also restores the modified
flag of a clean buffer, and the error propagates.  Return `saved',
`unsaved', or (save-failed . ERROR) if saving signalled ERROR."
  (let* ((base (org-iw-write--base marker))
         (was-clean (not (buffer-modified-p base))))
    (with-current-buffer (marker-buffer marker)
      (atomic-change-group
        (save-excursion
          (save-restriction (widen) (goto-char marker) (funcall fn)))))
    (if (not was-clean)
        'unsaved
      (condition-case err
          (progn (with-current-buffer base (save-buffer))
                 'saved)
        (error (cons 'save-failed err))))))

(cl-defun org-iw-write-put-rank (marker queue rank &key expected ensure-id)
  "Set the rank of the entry at MARKER in QUEUE to RANK.
This is the one write path of org-iw.  MARKER is at an entry's
heading, or at `point-min' for a document entry, in a buffer whose
base buffer visits a file; it may be indirect or narrowed.  QUEUE is
a queue ID in any case.  RANK is an integer, written as is: callers
take it from `org-iw-core-append-rank', which checks the limit.

EXPECTED is the rank the caller scanned, or :absent for an entry not
in QUEUE; anything else is an error.  With ENSURE-ID non-nil, an
entry without an ID is given one.

Before anything changes, refuse with `org-iw-refusal', naming the
file, if QUEUE is not a valid queue ID, the file changed on disk
since visited, the file is not writable, or the entry's IW_ lines for
QUEUE are not exactly EXPECTED: one membership line whose value
parses to it, or none for :absent.  A duplicated or accumulated key
never matches.

The ID and rank are then written atomically: if either signals, the
buffer is restored and the error propagates.  A base buffer that had
no unsaved changes is saved, returning `saved'; if saving signals
ERROR, the edit stands and the result is (save-failed . ERROR).  A
buffer with unsaved changes is left modified, returning `unsaved'."
  (cl-check-type expected (or integer (member :absent)))
  (let ((queue-id (or (org-iw-core-queue-id queue)
                      (org-iw-write--refuse marker "invalid queue ID %S"
                                            queue))))
    (org-iw-write--preflight marker queue-id expected)
    (org-iw-write--apply
     marker
     (lambda ()
       (when ensure-id
         (org-id-get-create))
       (org-entry-put marker (concat "IW_" queue-id)
                      (number-to-string rank))))))

(provide 'org-iw-write)
;;; org-iw-write.el ends here
