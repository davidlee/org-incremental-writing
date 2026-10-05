;;; org-iw-write.el --- Put and delete org-iw ranks  -*- lexical-binding: t; -*-

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

;; The write path for org-iw.  `org-iw-write-put-rank' sets one
;; entry's rank in one queue, and `org-iw-write-delete-rank' deletes it,
;; removing that one line and keeping the property drawer, unless it is
;; the document's drawer and the line was its last.  Putting a rank for
;; a document with no text before its first heading inserts that drawer
;; first.  Both work through the buffer visiting the entry's file and
;; share one preflight and one apply: check the file and the scanned
;; rank first, edit atomically, and save only a buffer that had no
;; unsaved changes.  Every operation that changes a queue writes through
;; this layer.  It does not read the user options of `org-iw'.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'org-iw-core)
(require 'org-iw-discovery)

(defun org-iw-write--refuse (marker format-string &rest args)
  "Signal an `org-iw-refusal' naming the file of MARKER.
The message is FORMAT-STRING with ARGS, after the file name."
  (org-iw-core-refuse
   "%s: %s"
   (buffer-file-name (org-iw-discovery-base-buffer (marker-buffer marker)))
   (apply #'format format-string args)))

(defun org-iw-write--expected-p (lines expected)
  "Return non-nil if the queue LINES hold the rank EXPECTED.
LINES are as from `org-iw-discovery-queue-lines'.  EXPECTED :absent
holds for no line at all, and an integer for a single membership
line whose value parses to it."
  (pcase lines
    ('() (eq expected :absent))
    (`((member . ,value))
     (and (integerp expected)
          (eql (org-iw-core-parse-rank value) expected)))))

(defun org-iw-write--check-file (marker)
  "Refuse unless the file of MARKER may be written.
The base buffer's file must be unchanged on disk since visited and
writable, and neither it nor MARKER's buffer read-only.  Nothing is
changed."
  (let* ((base (org-iw-discovery-base-buffer (marker-buffer marker)))
         (file (buffer-file-name base)))
    (unless (verify-visited-file-modtime base)
      (org-iw-write--refuse marker "changed on disk; revert first"))
    (unless (file-writable-p file)
      (org-iw-write--refuse marker "not writable"))
    (when (or (buffer-local-value 'buffer-read-only base)
              (buffer-local-value 'buffer-read-only (marker-buffer marker)))
      (org-iw-write--refuse marker "buffer is read-only"))))

(defun org-iw-write--check-entry (marker queue expected)
  "Refuse unless the entry at MARKER holds the rank EXPECTED in QUEUE.
QUEUE is a canonical queue ID.  The entry must also have no property
drawer Org fails to recognise.  Nothing is changed."
  (org-with-point-at marker
    (unless (org-iw-write--expected-p (org-iw-discovery-queue-lines queue)
                                      expected)
      (org-iw-write--refuse marker "IW_%s changed since scan" queue))
    (when (org-iw-discovery-unrecognised-drawer-p)
      (org-iw-write--refuse
       marker "entry has a property drawer Org doesn't recognise"))))

(defun org-iw-write--preflight (marker queue expected)
  "Refuse unless writing QUEUE's rank at MARKER is safe.
See `org-iw-write--check-file' and `org-iw-write--check-entry', which
take MARKER, QUEUE and EXPECTED.  Nothing is changed."
  (org-iw-write--check-file marker)
  (org-iw-write--check-entry marker queue expected))

(defun org-iw-write--document-start-p (marker)
  "Return non-nil if MARKER is where its buffer's document starts.
See `org-iw-discovery-document-marker'."
  (= marker (with-current-buffer (marker-buffer marker)
              (org-iw-discovery-document-marker))))

(defun org-iw-write--document-entry-p (marker)
  "Return non-nil if MARKER is at the entry of its buffer's document.
That is at the start of the buffer, widened, with text before the
first heading; see `org-iw-discovery-document-slot-p'."
  (and (org-iw-write--document-start-p marker)
       (with-current-buffer (marker-buffer marker)
         (org-iw-discovery-document-slot-p))))

(defun org-iw-write--apply (marker fn)
  "Call FN at MARKER atomically; save the base buffer if it was clean.
FN runs in MARKER's buffer, widened, with point at MARKER.  If it
signals, its changes are undone, which also restores the modified
flag of a clean buffer, and the error propagates.  Return `saved',
`unsaved', or (save-failed . ERROR) if saving signalled ERROR."
  (let* ((base (org-iw-discovery-base-buffer (marker-buffer marker)))
         (was-clean (not (buffer-modified-p base))))
    (with-current-buffer (marker-buffer marker)
      (atomic-change-group
        (org-with-point-at marker (funcall fn))))
    (if (not was-clean)
        'unsaved
      (condition-case err
          (progn (with-current-buffer base (save-buffer))
                 'saved)
        (error (cons 'save-failed err))))))

(cl-defun org-iw-write-put-rank (marker queue rank
                                        &key expected ensure-id document)
  "Set the rank of the entry at MARKER in QUEUE to RANK.
MARKER is at an entry's heading, or at the start of the buffer,
widened, for the document's entry, in a buffer whose base buffer
visits a file; it may be indirect or narrowed.  QUEUE is a canonical
queue ID, as from `org-iw-core-queue-id'; anything else is an error.
RANK is an integer of magnitude at most `org-iw-core-rank-limit', as
from `org-iw-core-rank-at'; anything else is an error.

EXPECTED is the rank the caller scanned, or :absent for an entry not
in QUEUE; anything else is an error.  With ENSURE-ID non-nil, an
entry without an ID is given one.

DOCUMENT non-nil says MARKER is at the document's entry: it is an
error unless MARKER is at the start of the buffer, widened.  A caller
making a document a member passes it.  If the file has no text before
its first heading, the document has no entry yet: EXPECTED must then
be :absent, else it is an error, and the edit first inserts an empty
property drawer before the first heading, so that the ID and rank go
into it and the heading is untouched.  Otherwise DOCUMENT changes
nothing.

Before anything changes, refuse with `org-iw-refusal', naming the
file, if the file changed on disk since visited, the file is not
writable, the buffer is read-only, or the entry's IW_ lines for
QUEUE are not exactly EXPECTED: one membership line whose value
parses to it, or none for :absent.  A duplicated or accumulated key
never matches.  It also refuses if the entry has a property drawer
Org does not recognise, since Org would add a second one.

The drawer, ID and rank are then written atomically: if any signals,
the buffer is restored and the error propagates.  A base buffer that
had no unsaved changes is saved, returning `saved'; if saving signals
ERROR, the edit stands and the result is (save-failed . ERROR).  A
buffer with unsaved changes is left modified, returning `unsaved'."
  (cl-check-type queue (satisfies org-iw-core-canonical-queue-id-p))
  (cl-check-type rank (satisfies org-iw-core-rank-p))
  (cl-check-type expected (or integer (member :absent)))
  (when (and document (not (org-iw-write--document-start-p marker)))
    (error "Document entry marker not at the start of its buffer: %S"
           marker))
  (let ((new-drawer (and document
                         (not (org-iw-write--document-entry-p marker)))))
    (cond ((not new-drawer)
           (org-iw-write--preflight marker queue expected))
          ((eq expected :absent)
           (org-iw-write--check-file marker))
          (t (error "Document entry without a drawer expected in %s: %S"
                    queue expected)))
    (org-iw-write--apply
     marker
     (lambda ()
       (when new-drawer
         (save-excursion
           (goto-char (point-min))
           (insert ":PROPERTIES:\n:END:\n")))
       (when ensure-id
         (org-id-get-create))
       ;; A new drawer went in at MARKER, which may have moved past it.
       (org-entry-put (if new-drawer (point-min) marker)
                      (concat "IW_" queue) (number-to-string rank))))))

(cl-defun org-iw-write-delete-rank (marker queue &key expected)
  "Delete the rank of the entry at MARKER in QUEUE.
MARKER and QUEUE are as for `org-iw-write-put-rank'.  EXPECTED is
the rank the caller scanned, an integer; anything else is an error.

Before anything changes, refuse as `org-iw-write-put-rank' does: if
the file changed on disk since visited, the file is not writable, the
buffer is read-only, the entry's IW_ lines for QUEUE are not exactly
one membership line whose value parses to EXPECTED, or the entry has
a property drawer Org does not recognise.

The membership line alone is then deleted, atomically.  A heading's
drawer must keep another line, such as the entry's ID, while the
document's entry, at the start of a buffer with text before its first
heading, may lose its emptied drawer too.  If nothing was deleted, or
a heading's drawer went with it, the buffer is restored and an error
is signalled.  Saving and the result are as for
`org-iw-write-put-rank': `saved', `unsaved' or (save-failed . ERROR)."
  (cl-check-type queue (satisfies org-iw-core-canonical-queue-id-p))
  (cl-check-type expected integer)
  (org-iw-write--preflight marker queue expected)
  ;; Before deleting: a drawer that is all the text before the first
  ;; heading leaves no document slot once it goes.
  (let ((document (org-iw-write--document-entry-p marker)))
    (org-iw-write--apply
     marker
     (lambda ()
       ;; `org-entry-delete' skips a lowercase key unless this is t.
       (let ((case-fold-search t))
         (unless (and (org-entry-delete marker (concat "IW_" queue))
                      ;; Org deletes a drawer the deletion emptied.
                      (or document (org-get-property-block)))
           (error "IW_%s not deleted alone" queue)))))))

(provide 'org-iw-write)
;;; org-iw-write.el ends here
