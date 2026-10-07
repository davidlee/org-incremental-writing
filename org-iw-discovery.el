;;; org-iw-discovery.el --- Find queue entries in Org sources  -*- lexical-binding: t; -*-

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

;; Discovery for org-iw: select the source files, then scan them for
;; queue entries and problems.  Source files are read, never visited
;; or modified: a visiting buffer's text (unsaved edits included) wins
;; over the file on disk.  Configuration arrives as arguments; this
;; layer does not read the user options of `org-iw'.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'org)
(require 'org-element)
(require 'org-iw-core)

(cl-defstruct (org-iw-scan (:constructor org-iw-scan-create)
                           (:copier nil))
  "The result of one discovery scan."
  entries     ; list of `org-iw-entry'
  problems)   ; list of `org-iw-problem'

(defconst org-iw-discovery--block-types
  '(src-block example-block export-block quote-block verse-block
              special-block comment-block dynamic-block)
  "Org element types whose contents are quoted text, not metadata.")

(defconst org-iw-discovery--iw-line-regexp
  "^[ \t]*:\\(IW_[^:\n]*\\):[ \t]*\\(.*?\\)[ \t]*$"
  "Regexp for an IW_ property line: group 1 the name, group 2 the value.
Match it case-insensitively.")

(defconst org-iw-discovery--id-line-regexp
  "^[ \t]*:ID:[ \t]+\\(.*?\\)[ \t]*$"
  "Regexp for an ID property line, group 1 the value.
Match it case-insensitively; compare values case-sensitively.")

;;;; File selection

(defun org-iw-discovery--descend-p (directory)
  "Return non-nil if a source search should descend into DIRECTORY.
Hidden and inaccessible directories are skipped."
  (and (not (string-prefix-p "." (file-name-nondirectory directory)))
       (file-accessible-directory-p directory)))

(defun org-iw-discovery--candidates (source)
  "Return the candidate file names for SOURCE, a file or directory."
  (if (file-directory-p source)
      (directory-files-recursively source "\\.org\\'" nil
                                   #'org-iw-discovery--descend-p)
    (list source)))

(defun org-iw-discovery--selected-truename (file exclude-regexp)
  "Return the truename of FILE if it is a usable source, else nil.
A usable source is a regular file, not named as an Emacs lock file,
whose truename EXCLUDE-REGEXP (if non-nil) does not match.  The lock
file test uses FILE's own name, since a lock file is a dangling
symlink whose target loses the .# prefix."
  (unless (string-prefix-p ".#" (file-name-nondirectory file))
    (let ((truename (file-truename file))
          (case-fold-search nil))
      (and (file-regular-p truename)
           (not (and exclude-regexp
                     (string-match-p exclude-regexp truename)))
           truename))))

(defun org-iw-discovery-files (sources exclude-regexp)
  "Return the sorted, unique truenames of the files in SOURCES.
SOURCES is a list of files and directories; see `org-iw-sources' for
the selection rules.  Files whose truename matches EXCLUDE-REGEXP,
case-sensitively, are left out; nil excludes nothing.  Sources that
do not exist are ignored."
  (sort (delete-dups
         (seq-keep (lambda (file)
                     (org-iw-discovery--selected-truename file exclude-regexp))
                   (mapcan #'org-iw-discovery--candidates sources)))
        #'string<))

;;;; Document identity

(defvar org-iw-discovery--denote-tried nil
  "Non-nil once loading Denote has been tried.
It is set before the one attempt of a session, so a Denote that fails
to load warns once.")

(declare-function denote-file-has-denoted-filename-p "denote" (file))
(declare-function denote-retrieve-filename-identifier "denote" (file))

(defun org-iw-discovery-document-marker ()
  "Return a marker at the current buffer's document entry.
That is the start of the base buffer, widened, whatever the current
buffer, its narrowing and point.  Text inserted there goes after the
marker, so a drawer inserted for the document leaves it at the
drawer.  This is the one owner of where a document starts."
  (with-current-buffer (org-iw-discovery-base-buffer)
    (org-with-wide-buffer
     (copy-marker (point-min)))))

(defmacro org-iw-discovery--at-document-start (&rest body)
  "Run BODY at `org-iw-discovery-document-marker'.
The current buffer, point and the narrowing are restored afterwards."
  (declare (indent 0) (debug t))
  `(org-with-point-at (org-iw-discovery-document-marker)
     ,@body))

(defun org-iw-discovery--denote-available-p ()
  "Return non-nil if Denote is loaded, trying to load it once if not.
A load error is shown as a warning and gives nil; it never signals."
  (or (featurep 'denote)
      (unless org-iw-discovery--denote-tried
        (setq org-iw-discovery--denote-tried t)
        (condition-case err
            (require 'denote nil t)
          (error
           (display-warning 'org-iw
                            (format "Denote failed to load: %s"
                                    (error-message-string err)))
           nil)))))

(defun org-iw-discovery--denote-identifier (file)
  "Return the Denote identifier in the name of FILE, or nil.
There is one only if Denote is available and FILE is named in its
file naming scheme; where FILE lives does not matter."
  (and (org-iw-discovery--denote-available-p)
       (denote-file-has-denoted-filename-p file)
       (denote-retrieve-filename-identifier file)))

(defun org-iw-discovery--id-at-point ()
  "Return the ID property of the entry at point, or nil if it is empty."
  (org-string-nw-p (org-entry-get nil "ID")))

(defun org-iw-discovery-document-slot-p ()
  "Return non-nil if the current buffer has text before its first heading.
That text is where the document's own entry, and its file-level
property drawer, are.  The answer is the base buffer's, widened,
whatever the current buffer, its narrowing and point."
  (org-iw-discovery--at-document-start
    (org-before-first-heading-p)))

(defun org-iw-discovery-document-id (file)
  "Return the ID of the current buffer's document, or nil if it has none.
FILE is the truename of the buffer's file.  The ID is the file-level
:ID: if the buffer has a document slot and the :ID: is not empty,
else the Denote identifier in FILE's name (see
`org-iw-discovery--denote-identifier').  The base buffer is read,
widened, wherever point is.  This is the one owner of a document's
identity."
  (or (org-iw-discovery--at-document-start
        (and (org-iw-discovery-document-slot-p)
             (org-iw-discovery--id-at-point)))
      (org-iw-discovery--denote-identifier file)))

;;;; Reading entries

(defun org-iw-discovery--tally (values)
  "Return a hash table counting each of VALUES, compared with `equal'."
  (let ((tally (make-hash-table :test #'equal)))
    (dolist (value values tally)
      (cl-incf (gethash value tally 0)))))

(defun org-iw-discovery--id-lines ()
  "Return the ID property lines in the current buffer as (VALUE . POS).
An ID property line matches `org-iw-discovery--id-line-regexp', key in
any case, where `org-at-property-p' holds.  VALUE keeps its case and
POS is the start of the line; lines come in buffer order.  Only the
accessible portion is searched, so widen first to see the whole buffer.

This is the only matcher of ID lines, and `org-iw-discovery--identities'
its only reader, so every caller agrees on them."
  (save-excursion
    (goto-char (point-min))
    (let ((lines nil))
      (while (let ((case-fold-search t))
               (re-search-forward org-iw-discovery--id-line-regexp nil t))
        (let ((value (match-string-no-properties 1)))
          (save-excursion
            (goto-char (match-beginning 0))
            (when (org-at-property-p)
              (push (cons value (point)) lines)))))
      (nreverse lines))))

(defun org-iw-discovery--iw-lines ()
  "Return the entry's IW_ property lines as an alist (NAME . VALUE).
Point must be within the entry: at or below its heading and above
the next, or before the first heading for the document entry.  Only
the entry's own property drawer is read; nothing is inherited.  Names
keep their original case and repeated names are all kept, in drawer
order.  VALUE is the raw string, trimmed.

This is the only reader of IW values, so every caller agrees on them."
  (when-let* ((drawer (org-get-property-block)))
    (save-excursion
      (goto-char (car drawer))
      (let ((lines nil))
        (while (let ((case-fold-search t))
                 (re-search-forward org-iw-discovery--iw-line-regexp
                                    (cdr drawer) t))
          (push (cons (match-string-no-properties 1)
                      (match-string-no-properties 2))
                lines))
        (nreverse lines)))))

(defun org-iw-discovery-queue-lines (queue)
  "Return the entry at point's IW lines for QUEUE as (KIND . VALUE).
QUEUE is a canonical queue ID.  Lines are read by
`org-iw-discovery--iw-lines', the only IW reader, and classified by
`org-iw-core-classify-property', so KIND is `member' or `accumulate'.
Lines come in drawer order."
  (cl-loop for (name . value) in (org-iw-discovery--iw-lines)
           for class = (org-iw-core-classify-property name)
           when (and (consp class) (equal (cdr class) queue))
           collect (cons (car class) value)))

(defun org-iw-discovery--classify-lines (lines)
  "Classify raw IW LINES, as from `org-iw-discovery--iw-lines'.
Return (MEMBERSHIPS . PROBLEM-TYPES): MEMBERSHIPS is an alist
\(QUEUE . RANK) and PROBLEM-TYPES a list of problem type symbols.  A
queue named more than once, case-insensitively and counting IW_<Q>+
lines, is a `duplicate-property'; an IW_<Q>+ line alone and any
other invalid name are an `invalid-property'; a bad rank is an
`invalid-rank'.  Reserved names are ignored."
  (let ((groups nil)
        (invalid nil))
    (pcase-dolist (`(,name . ,value) lines)
      (pcase (org-iw-core-classify-property name)
        ('invalid (push 'invalid-property invalid))
        (`(,kind . ,queue)
         (let ((group (assoc queue groups)))
           (unless group
             (setq group (list queue))
             (push group groups))
           (push (cons kind value) (cdr group))))))
    (let ((memberships nil)
          (problems nil))
      (pcase-dolist (`(,queue . ,occurrences) (nreverse groups))
        (pcase occurrences
          (`((member . ,value))
           (if-let* ((rank (org-iw-core-parse-rank value)))
               (push (cons queue rank) memberships)
             (push 'invalid-rank problems)))
          (`((accumulate . ,_)) (push 'invalid-property problems))
          (_ (push 'duplicate-property problems))))
      (cons (nreverse memberships)
            (append (nreverse invalid) (nreverse problems))))))

(defun org-iw-discovery-entry-title (file)
  "Return the title of the entry at point in FILE.
A heading's title is its text; the document's is its #+title, else
the base name of FILE."
  (if (org-at-heading-p)
      (org-get-heading t t t t)
    (or (cadr (assoc "TITLE" (org-collect-keywords '("TITLE"))))
        (file-name-base file))))

(defun org-iw-discovery--identities (file)
  "Return the identities in the current buffer, FILE's text, as (ID . POS).
FILE is the buffer's truename.  The base buffer is read, widened.
The document's identity, if it has one, comes first, at `point-min';
then the ID property lines (see `org-iw-discovery--id-lines'), each
at the start of its line, except those in the document's own drawer,
whose :ID: is the document's identity already.

This is the only enumerator of identities, so the scan's tally and
`org-iw-discovery-id-count' agree on them."
  (org-iw-discovery--at-document-start
    (let ((document (org-iw-discovery-document-id file))
          (drawer (and (org-iw-discovery-document-slot-p)
                       (org-get-property-block))))
      (append (and document (list (cons document (point-min))))
              (seq-remove (lambda (line)
                            (and drawer
                                 (<= (car drawer) (cdr line) (cdr drawer))))
                          (org-iw-discovery--id-lines))))))

(defun org-iw-discovery-entry-id (file)
  "Return the ID of the entry at point in FILE, or nil if it has none.
FILE is the truename of the current buffer's file.  A heading's ID is
its :ID:; before the first heading, the entry is the document, and its
ID is `org-iw-discovery-document-id'.  The scan and the commands both
read it here, so they agree on it."
  (if (org-before-first-heading-p)
      (org-iw-discovery-document-id file)
    (org-iw-discovery--id-at-point)))

(defun org-iw-discovery--entry (file id memberships)
  "Return the entry at point in FILE, with ID and MEMBERSHIPS, or nil.
MEMBERSHIPS is the alist of `org-iw-discovery--classify-lines'; nil
gives nil.  This is the one constructor of scanned entries."
  (and memberships
       (org-iw-entry-create
        :id id :title (org-iw-discovery-entry-title file)
        :file file :memberships memberships
        :outline (mapcar #'string-clean-whitespace (org-get-outline-path)))))

(defun org-iw-discovery-entry (file)
  "Return the entry starting at point in FILE as a scan reads it, or nil.
FILE is the truename of the current buffer's file, and the buffer
must be widened.  Point is at a heading, or at `point-min' for the
document.  The result is nil if the entry has no ID or no
membership.  Unlike a scan, it does not check that the ID is
unique."
  (when-let* ((id (org-iw-discovery-entry-id file)))
    (org-iw-discovery--entry
     file id (car (org-iw-discovery--classify-lines
                   (org-iw-discovery--iw-lines))))))

(defun org-iw-discovery--read-entry (file tally)
  "Read the entry starting at point in FILE.
TALLY counts the buffer's identities.  Return (ENTRY
. PROBLEMS), where ENTRY is nil unless a membership survives."
  (let ((id (org-iw-discovery-entry-id file)))
    (cl-flet ((problem (type)
                (org-iw-problem-create :type type :file file :id id)))
      (cond
       ((not id) (list nil (problem 'missing-id)))
       ((> (gethash id tally 0) 1) (list nil (problem 'duplicate-id)))
       (t
        (pcase-let ((`(,memberships . ,types)
                     (org-iw-discovery--classify-lines
                      (org-iw-discovery--iw-lines))))
          (cons (org-iw-discovery--entry file id memberships)
                (mapcar #'problem types))))))))

(defun org-iw-discovery--in-block-p ()
  "Return non-nil if point is inside a block of quoted text."
  (org-element-lineage (org-element-at-point)
                       org-iw-discovery--block-types t))

(defun org-iw-discovery-unrecognised-drawer-p ()
  "Return non-nil if the entry at point has a drawer Org ignores.
Point must be at the entry's start: its heading, or `point-min' for
the document entry.  That is a :PROPERTIES: line in the entry's
section, outside any block, when Org finds no property drawer:
`org-entry-put' would add a second one."
  (unless (org-get-property-block)
    (save-excursion
      (let ((end (save-excursion (outline-next-heading) (point)))
            (case-fold-search t)
            (found nil))
        (while (and (not found)
                    (re-search-forward org-property-start-re end t))
          (setq found (save-excursion
                        (goto-char (match-beginning 0))
                        (not (org-iw-discovery--in-block-p)))))
        found))))

(defun org-iw-discovery--scan-buffer (file)
  "Scan the current buffer, in Org mode, holding the text of FILE.
Return (ENTRIES . PROBLEMS), each in buffer order."
  (let ((tally (org-iw-discovery--tally
                (mapcar #'car (org-iw-discovery--identities file))))
        (seen nil)
        (entries nil)
        (problems nil))
    (goto-char (point-min))
    (while (let ((case-fold-search t))
             (re-search-forward org-iw-discovery--iw-line-regexp nil t))
      (save-excursion
        (goto-char (match-beginning 0))
        (cond
         ((org-iw-discovery--in-block-p))
         ((not (org-at-property-p))
          (push (org-iw-problem-create :type 'misplaced-property :file file)
                problems))
         (t
          (org-back-to-heading-or-point-min)
          (unless (memql (point) seen)
            (push (point) seen)
            (pcase-let ((`(,entry . ,found)
                         (org-iw-discovery--read-entry file tally)))
              (when entry
                (push entry entries))
              (setq problems (append (reverse found) problems))))))))
    (cons (nreverse entries) (nreverse problems))))

(defun org-iw-discovery--insert-text (file)
  "Insert the current text of FILE at point; return nil if unreadable.
A buffer visiting FILE supplies its whole text, unsaved edits
included, and is left untouched.  Otherwise the file is read from
disk without visiting it."
  (condition-case nil
      (progn
        (if-let* ((live (find-buffer-visiting file)))
            (insert (with-current-buffer live
                      (save-restriction
                        (widen)
                        (buffer-substring-no-properties (point-min)
                                                        (point-max)))))
          (insert-file-contents file))
        t)
    (file-error nil)))

(defun org-iw-discovery--has-iw-line-p ()
  "Return non-nil if the current buffer contains an IW_ property line."
  (save-excursion
    (goto-char (point-min))
    (let ((case-fold-search t))
      (re-search-forward org-iw-discovery--iw-line-regexp nil t))))

(defun org-iw-discovery--scan-file (file)
  "Scan FILE; return (ENTRIES . PROBLEMS), each in buffer order.
Org mode is enabled only for text containing an IW_ line."
  (with-temp-buffer
    (cond
     ((not (org-iw-discovery--insert-text file))
      (list nil (org-iw-problem-create :type 'unreadable :file file)))
     ((org-iw-discovery--has-iw-line-p)
      (delay-mode-hooks (org-mode))
      (org-iw-discovery--scan-buffer file))
     (t (list nil)))))

(defun org-iw-discovery--drop-shared-ids (entries)
  "Split ENTRIES on IDs carried by more than one of them.
Return (KEPT . PROBLEMS): the entries whose ID is unique, and one
`duplicate-id' problem per shared ID, naming the first file."
  (let* ((tally (org-iw-discovery--tally (mapcar #'org-iw-entry-id entries)))
         (shared-p (lambda (entry)
                     (> (gethash (org-iw-entry-id entry) tally) 1))))
    (cons (seq-remove shared-p entries)
          (mapcar (lambda (entry)
                    (org-iw-problem-create :type 'duplicate-id
                                           :file (org-iw-entry-file entry)
                                           :id (org-iw-entry-id entry)))
                  (seq-uniq (seq-filter shared-p entries)
                            (lambda (a b)
                              (string= (org-iw-entry-id a)
                                       (org-iw-entry-id b))))))))

(defun org-iw-discovery-scan (files)
  "Scan FILES for queue entries; return an `org-iw-scan'.
FILES are truenames, as from `org-iw-discovery-files'.  Entries and
problems come in the order of FILES, then buffer order; problems for
IDs shared between entries come last.  No file is visited and no
buffer is changed."
  (let* ((results (mapcar #'org-iw-discovery--scan-file files))
         (split (org-iw-discovery--drop-shared-ids
                 (apply #'append (mapcar #'car results)))))
    (org-iw-scan-create
     :entries (car split)
     :problems (append (apply #'append (mapcar #'cdr results))
                       (cdr split)))))

;;;; ID resolution

(defun org-iw-discovery-base-buffer (&optional buffer)
  "Return the base buffer of BUFFER, or BUFFER if it is not indirect.
BUFFER defaults to the current buffer.  See also
`org-iw-discovery-buffer'."
  (let ((buffer (or buffer (current-buffer))))
    (or (buffer-base-buffer buffer) buffer)))

(defun org-iw-discovery-buffer (file)
  "Return the buffer visiting FILE, visiting it first if need be.
An indirect buffer has no file name, so this is always a base buffer;
see also `org-iw-discovery-base-buffer'.
The lookup is by file, so it finds a buffer visiting FILE through a
symlink."
  (or (find-buffer-visiting file)
      (find-file-noselect file)))

(defun org-iw-discovery--id-positions (id file)
  "Return the positions where ID is an identity in the current buffer.
FILE is the truename of the buffer's file.  The search covers the
whole of the current buffer's base buffer, whatever its narrowing or
the current buffer's, and positions are in the base buffer: an ID
property line's start, or `point-min' for the document's identity.
See `org-iw-discovery--identities'."
  (cl-loop for (value . position) in (org-iw-discovery--identities file)
           when (string= value id) collect position))

(defun org-iw-discovery-id-count (id file)
  "Return the number of identities with value ID in the current buffer.
FILE is the truename of the buffer's file.  The whole base buffer is
counted, ignoring narrowing: the document's identity once, and each
ID property line outside its drawer.  The key of an ID property line
matches in any case; values compare case-sensitively."
  (length (org-iw-discovery--id-positions id file)))

(defun org-iw-discovery--refuse (what id file)
  "Signal an `org-iw-refusal' that WHAT is wrong with ID in FILE."
  (org-iw-core-refuse "ID %s in %s: %s" id file what))

(defconst org-iw-discovery-not-org-text "buffer not in Org mode"
  "The reason given when a buffer is not in Org mode.")

(defun org-iw-discovery-org-mode-p ()
  "Return non-nil if the current buffer is in Org mode.
A mode derived from Org mode counts.  This is the one owner of the
rule; no Org function may run in a buffer it rejects."
  (derived-mode-p 'org-mode))

(defun org-iw-discovery-require-org-mode (file)
  "Refuse with `org-iw-refusal' unless the current buffer is in Org mode.
See `org-iw-discovery-org-mode-p'.  FILE, the buffer's file, is named
in the message, which ends in `org-iw-discovery-not-org-text'."
  (unless (org-iw-discovery-org-mode-p)
    (org-iw-core-refuse "%s: %s" file org-iw-discovery-not-org-text)))

(defun org-iw-discovery--id-problems (scan id)
  "Return SCAN's problems whose ID is ID, in scan order.
A problem for an ID shared between files names only one of them, so
the file is not compared.  This is the one problem-by-ID filter."
  (seq-filter (lambda (problem) (equal (org-iw-problem-id problem) id))
              (org-iw-scan-problems scan)))

(defun org-iw-discovery-excluded-id-p (scan id)
  "Return non-nil if SCAN excluded ID as a duplicate, in any file."
  (seq-some (lambda (problem)
              (eq (org-iw-problem-type problem) 'duplicate-id))
            (org-iw-discovery--id-problems scan id)))

(defun org-iw-discovery-problem-types (scan id)
  "Return the distinct types of SCAN's problems with ID, in scan order.
The types are symbols, and come from problems naming ID in any file.
A nil ID gives (missing-id), since an entry without an ID has no ID
to match its problem by."
  (if (not id)
      '(missing-id)
    (seq-uniq (mapcar #'org-iw-problem-type
                      (org-iw-discovery--id-problems scan id)))))

(defun org-iw-discovery-shared-id-p (scan id file)
  "Return non-nil if an entry other than the one at point has ID.
ID is the entry's ID, and FILE the truename of the current buffer's
file.  The other entry may be a heading or the document.  That holds
if ID is other than one identity of the base buffer (see
`org-iw-discovery-id-count'), a scanned entry in another file has it,
or SCAN excluded it as a duplicate."
  (or (/= (org-iw-discovery-id-count id file) 1)
      (seq-some (lambda (entry)
                  (and (equal (org-iw-entry-id entry) id)
                       (not (equal (org-iw-entry-file entry) file))))
                (org-iw-scan-entries scan))
      (org-iw-discovery-excluded-id-p scan id)))

(defun org-iw-discovery-resolve (scan id file)
  "Return a marker at the entry with ID in FILE, or refuse.
This is the only resolver of IDs.  The marker is in FILE's buffer, at
the heading, or at `point-min' for a document-level ID.  SCAN is the
scan that found the entry; refuse with `org-iw-refusal' if it excluded
ID as a duplicate (in any file), if FILE's buffer is not in Org mode
\(a mode derived from it counts), or if ID is not exactly one identity
in FILE (see `org-iw-discovery-id-count'), which catches copies the
scan cannot know of."
  (when (org-iw-discovery-excluded-id-p scan id)
    (org-iw-discovery--refuse "duplicated, excluded from the queue" id file))
  (with-current-buffer (org-iw-discovery-buffer file)
    (org-iw-discovery-require-org-mode file)
    (pcase (org-iw-discovery--id-positions id file)
      ('() (org-iw-discovery--refuse "not found" id file))
      (`(,position)
       (org-with-wide-buffer
        (goto-char position)
        (org-back-to-heading-or-point-min t)
        (copy-marker (point))))
      (_ (org-iw-discovery--refuse "ambiguous, more than one heading"
                                   id file)))))

(provide 'org-iw-discovery)
;;; org-iw-discovery.el ends here
