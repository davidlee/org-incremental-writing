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
;; first.  `org-iw-write-put-ranks' puts several ranks through one
;; buffer, and `org-iw-write-put-rank' is a group of one.  All work
;; through the buffer visiting the entries' file and share one
;; preflight and one apply: check the file and every scanned rank first,
;; edit atomically in one change group, and save once, only a buffer
;; that had no unsaved changes.  A buffer with unsaved changes is saved
;; only by `org-iw-write-save-file', once the user agreed.
;; `org-iw-write-file-problems' says what stands in the way of writing a
;; file.  Every operation that changes a queue writes through this
;; layer.  It does not read the user options of `org-iw'.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-id)
(require 'org-iw-core)
(require 'org-iw-discovery)

(defun org-iw-write--file (buffer)
  "Return the file written through BUFFER, that of its base buffer."
  (buffer-file-name (org-iw-discovery-base-buffer buffer)))

(defun org-iw-write--refuse (buffer format-string &rest args)
  "Signal an `org-iw-refusal' naming the file written through BUFFER.
The message is FORMAT-STRING with ARGS, after the file name."
  (org-iw-core-refuse "%s: %s" (org-iw-write--file buffer)
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

(defun org-iw-write-file-problems (file &optional buffer)
  "Return what stands in the way of writing FILE, or nil.
FILE is a truename.  BUFFER is the buffer the write goes through: the
buffer visiting FILE (by default `find-buffer-visiting''s) or an
indirect buffer of it; BASE is its base buffer.  The result lists, in
this order, those of these symbols that hold: `changed-on-disk'
\(BASE's file changed since visited), `not-writable', `read-only' (BASE
or BUFFER is read-only), `not-org' (BASE is not in Org mode, see
`org-iw-discovery-org-mode-p'), and `modified' (BASE has unsaved
changes).  Without a buffer only `not-writable' can hold.  No file is
visited and nothing is changed."
  (let* ((buffer (or buffer (find-buffer-visiting file)))
         (base (and buffer (org-iw-discovery-base-buffer buffer))))
    (delq nil
          (list (and base (not (verify-visited-file-modtime base))
                     'changed-on-disk)
                (and (not (file-writable-p file)) 'not-writable)
                (and base
                     (or (buffer-local-value 'buffer-read-only base)
                         (buffer-local-value 'buffer-read-only buffer))
                     'read-only)
                (and base
                     (not (with-current-buffer base
                            (org-iw-discovery-org-mode-p)))
                     'not-org)
                (and base (buffer-modified-p base) 'modified)))))

(defun org-iw-write-problem-text (problem)
  "Return the text for PROBLEM, a symbol from `org-iw-write-file-problems'."
  (cl-ecase problem
    (changed-on-disk "changed on disk; revert first")
    (not-writable "not writable")
    (read-only "buffer is read-only")
    (not-org org-iw-discovery-not-org-text)
    (modified "unsaved changes")))

(defun org-iw-write--check-file (buffer)
  "Refuse unless the file written through BUFFER may be written.
BUFFER visits the file or is an indirect buffer of one that does; see
`org-iw-write-file-problems'.  Unsaved changes do not refuse.  Nothing
is changed."
  (when-let* ((problem (car (remq 'modified
                                  (org-iw-write-file-problems
                                   (org-iw-write--file buffer) buffer)))))
    (org-iw-write--refuse buffer "%s" (org-iw-write-problem-text problem))))

(defun org-iw-write--check-entry (marker queue expected)
  "Refuse unless the entry at MARKER holds the rank EXPECTED in QUEUE.
QUEUE is a canonical queue ID.  The entry must also have no property
drawer Org fails to recognise.  Nothing is changed."
  (org-with-point-at marker
    (unless (org-iw-write--expected-p (org-iw-discovery-queue-lines queue)
                                      expected)
      (org-iw-write--refuse (marker-buffer marker)
                            "IW_%s changed since scan" queue))
    (when (org-iw-discovery-unrecognised-drawer-p)
      (org-iw-write--refuse
       (marker-buffer marker)
       "entry has a property drawer Org doesn't recognise"))))

(defun org-iw-write--preflight (marker queue expected)
  "Refuse unless writing QUEUE's rank at MARKER is safe.
See `org-iw-write--check-file', of MARKER's buffer, and
`org-iw-write--check-entry', which takes MARKER, QUEUE and EXPECTED.
Nothing is changed."
  (org-iw-write--check-file (marker-buffer marker))
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

(defun org-iw-write--save (buffer)
  "Save BUFFER.
Return `saved', or (save-failed . ERROR) if saving signalled ERROR."
  (condition-case err
      (progn (with-current-buffer buffer (save-buffer))
             'saved)
    (error (cons 'save-failed err))))

(defun org-iw-write--apply (buffer edits)
  "Run EDITS in BUFFER atomically; save its base buffer if it was clean.
EDITS is a list of (MARKER . EDIT), every MARKER in BUFFER.  Each EDIT
is called in turn, with no arguments, in BUFFER widened and with point
at its MARKER.  If one signals, the changes of all are undone, which
also restores the modified flag of a clean buffer, and the error
propagates.  Return `unsaved' if the base buffer had unsaved changes,
else what `org-iw-write--save' returns."
  (let* ((base (org-iw-discovery-base-buffer buffer))
         (was-clean (not (buffer-modified-p base))))
    (with-current-buffer buffer
      (atomic-change-group
        (pcase-dolist (`(,marker . ,edit) edits)
          (org-with-point-at marker (funcall edit)))))
    (if was-clean
        (org-iw-write--save base)
      'unsaved)))

(cl-defun org-iw-write--prepare-put (marker queue rank
                                            &key expected ensure-id document)
  "Check setting the rank of the entry at MARKER in QUEUE to RANK.
EXPECTED, ENSURE-ID and DOCUMENT, the errors and the refusals are as
for `org-iw-write-put-rank'.  Return (POSITION . EDIT), for
`org-iw-write--apply': EDIT writes the drawer, ID and rank at
POSITION, a copy of MARKER that advances past text inserted at it, so
that a heading starting the buffer keeps its position when a
document's new drawer goes in before it.  Nothing is changed."
  (cl-check-type queue (satisfies org-iw-core-canonical-queue-id-p))
  (cl-check-type rank (satisfies org-iw-core-rank-p))
  (cl-check-type expected (or integer (member :absent)))
  (when (and document (not (org-iw-write--document-start-p marker)))
    (error "Document entry marker not at the start of its buffer: %S"
           marker))
  (let ((new-drawer (and document
                         (not (org-iw-write--document-entry-p marker))))
        (position (copy-marker marker t)))
    (cond ((not new-drawer)
           (org-iw-write--preflight marker queue expected))
          ((eq expected :absent)
           (org-iw-write--check-file (marker-buffer marker)))
          (t (error "Document entry without a drawer expected in %s: %S"
                    queue expected)))
    (cons position
          (lambda ()
            (when new-drawer
              (save-excursion
                (goto-char (point-min))
                (insert ":PROPERTIES:\n:END:\n")))
            (when ensure-id
              (org-id-get-create))
            ;; A new drawer went in at POSITION, which moved past it.
            (org-entry-put (if new-drawer (point-min) position)
                           (concat "IW_" queue) (number-to-string rank))))))

(defun org-iw-write-put-ranks (changes)
  "Set the ranks of CHANGES through one buffer, saved once.
CHANGES is a list of (MARKER QUEUE RANK . KEYS), each read as the
arguments of `org-iw-write-put-rank', KEYS its keyword arguments.
Every MARKER is in the same buffer; else it is an error.

Each change is checked as `org-iw-write-put-rank' checks it, and all
are checked before anything changes, so the first refusal leaves the
buffer untouched.  The edits then run in order in one atomic change
group: if any signals, the buffer is restored and the error
propagates.  The base buffer is saved once if it had no unsaved
changes.  Return `saved', `unsaved' or (save-failed . ERROR), as
`org-iw-write-put-rank' does."
  (let ((buffer (marker-buffer (caar changes))))
    (unless (cl-every (lambda (change) (eq (marker-buffer (car change)) buffer))
                      changes)
      (error "Changes in more than one buffer: %S" changes))
    (org-iw-write--apply
     buffer (mapcar (lambda (change)
                      (apply #'org-iw-write--prepare-put change))
                    changes))))

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
  (org-iw-write-put-ranks
   (list (list marker queue rank
               :expected expected :ensure-id ensure-id :document document))))

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
     (marker-buffer marker)
     (list
      (cons marker
            (lambda ()
              ;; `org-entry-delete' skips a lowercase key unless this is t.
              (let ((case-fold-search t))
                (unless (and (org-entry-delete marker (concat "IW_" queue))
                             ;; Org deletes a drawer the deletion emptied.
                             (or document (org-get-property-block)))
                  (error "IW_%s not deleted alone" queue)))))))))

(defun org-iw-write-save-file (file)
  "Save the buffer visiting FILE, which the user agreed to save.
Refuse, saving nothing, if FILE has a problem other than `modified'
\(see `org-iw-write-file-problems'): saving over a file changed on
disk would lose those changes.  Return `saved', or (save-failed .
ERROR) if saving signalled ERROR, or (save-failed . still-modified)
if the buffer is modified again once saved (a save hook edited it)."
  (let ((buffer (find-buffer-visiting file)))
    (org-iw-write--check-file buffer)
    (let ((result (org-iw-write--save buffer)))
      (if (and (eq result 'saved) (buffer-modified-p buffer))
          '(save-failed . still-modified)
        result))))

(provide 'org-iw-write)
;;; org-iw-write.el ends here
