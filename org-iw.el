;;; org-iw.el --- Incremental writing queues for Org  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 David Lee

;; Author: David Lee <david.lee@inlight.com.au>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1"))
;; URL: https://github.com/davidlee/org-incremental-writing
;; Keywords: outlines, wp

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

;; Incremental writing for Org: named queues of headings, worked
;; through one entry at a time.  Queue state lives on each entry as an
;; IW_<QUEUE> property holding an integer rank; there is no index file.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'org)
(require 'tabulated-list)
(require 'text-property-search)
(require 'org-iw-core)
(require 'org-iw-discovery)
(require 'org-iw-write)

(defgroup org-iw nil
  "Incremental writing queues for Org."
  :group 'org
  :prefix "org-iw-")

(defcustom org-iw-sources nil
  "Files and directories whose Org entries may belong to queues.

A file is used as is, but is refused when its buffer is not in
Org mode.  A directory is searched recursively for
files named *.org, with these rules:

- Below a listed directory, hidden directories (names starting
  with a dot, such as .git) are skipped.  A listed directory that
  is itself hidden, such as ~/.notes, is still searched.
- Symbolic links to directories are not followed; list the
  target instead.
- Names starting with .# (Emacs lock files) are skipped, as is
  anything that is not a regular file once symlinks are resolved.

Files are compared by their true names, so a file reached through
two sources is used once.  See also `org-iw-exclude-regexp'."
  :type '(repeat (choice (file :tag "File")
                         (directory :tag "Directory")))
  :group 'org-iw)

(defcustom org-iw-exclude-regexp nil
  "Regexp matching the true names of source files to ignore.
When nil, no file found through `org-iw-sources' is excluded."
  :type '(choice (const :tag "None" nil) regexp)
  :group 'org-iw)

(defconst org-iw--placement-type
  '(choice (list :tag "After N others" (const after) natnum)
           (list :tag "Fraction of the way back"
                 (const fraction) (natnum :tag "Numerator")
                 (natnum :tag "Denominator"))
           (list :tag "Percent of the way back" (const percent) natnum)
           (const :tag "End" end))
  "Customize type of one placement.")

(defconst org-iw--placements-type
  `(repeat (list (string :tag "Label") ,org-iw--placement-type))
  "Customize type of a list of labelled placements.")

(defcustom org-iw-placements
  '(("Soon" (after 2)) ("Later" (fraction 1 2)) ("End" end))
  "Placements offered by `org-iw-continue', `org-iw-move' and `org-iw-add'.
This is a list of (LABEL PLACEMENT), in the order the chooser lists
them, used by queues whose entry in `org-iw-queues' has no
:placements.  LABEL is a non-empty string, distinct within the list.
PLACEMENT says where an entry goes among the queue's other members:

  (after N)            after N of them, or at the end if there are fewer
  (fraction NUM DEN)   NUM/DEN of the way back, rounded towards the front
  (percent P)          P percent of the way back, rounded likewise
  end                  after all of them

Hence (after 0), (fraction 0 1) and (percent 0) put the entry first,
so that it comes up again at once.  Labels are not stored in entries:
renaming one changes no file."
  :type org-iw--placements-type
  :group 'org-iw)

(defcustom org-iw-default-placement "End"
  "Label of the placement used when none is chosen.
It applies to queues that have neither :default nor :placements in
`org-iw-queues', and names one of `org-iw-placements'.  When nil,
the first of them is used."
  :type '(choice (const :tag "First placement" nil) string)
  :group 'org-iw)

(defcustom org-iw-queues nil
  "Configured queues, as an alist of (QUEUE-ID . PLIST).

QUEUE-ID is a string of letters, digits and hyphens, compared
case-insensitively; entries join the queue through an IW_QUEUE-ID
property.  PLIST supports:

  :name        the display name shown in prompts and the mode line.
  :placements  the queue's own placements, in the form of
               `org-iw-placements', which they replace.
  :default     the label of the placement used when none is chosen.
               Without it, a queue with its own :placements uses the
               first of them, and any other queue uses
               `org-iw-default-placement'.

Queues found in source files but not listed here can still be
chosen; they are shown by their ID."
  :type `(alist :key-type (string :tag "Queue ID")
                :value-type (plist :tag "Options"
                                   :options ((:name string)
                                             (:placements
                                              ,org-iw--placements-type)
                                             (:default string))))
  :group 'org-iw)

;;;; Private helpers

(defun org-iw--files ()
  "Return the source files selected by the user options."
  (org-iw-discovery-files org-iw-sources org-iw-exclude-regexp))

(defun org-iw--scan ()
  "Scan the source files afresh; return an `org-iw-scan'."
  (org-iw-discovery-scan (org-iw--files)))

(defun org-iw--buffer-truename ()
  "Return the truename of the current buffer's file, or nil.
An indirect buffer's file is its base buffer's."
  (when-let* ((file (buffer-file-name (org-iw-discovery-base-buffer))))
    (file-truename file)))

(defun org-iw--source-file-p ()
  "Return non-nil if the current buffer's file is a source file."
  (when-let* ((file (org-iw--buffer-truename)))
    (member file (org-iw--files))))

(defun org-iw--require-source ()
  "Refuse unless the current buffer visits a source file in Org mode.
An indirect buffer's file is its base buffer's."
  (unless (org-iw--source-file-p)
    (org-iw-core-refuse "%s is not under org-iw-sources" (buffer-name)))
  (org-iw-discovery-require-org-mode (org-iw--buffer-truename)))

(defun org-iw--document-marker ()
  "Return a marker at the current buffer's document entry.
That is the start of the base buffer, widened, whatever the narrowing
and point.  Text inserted there goes after the marker, so a drawer
inserted for the document leaves it at the drawer."
  (with-current-buffer (org-iw-discovery-base-buffer)
    (org-with-wide-buffer
     (copy-marker (point-min)))))

(defun org-iw--target-at-point ()
  "Return a marker at the entry at point, or refuse.
The entry is the heading at or above point, ignoring narrowing, or,
before the first heading, the document (see
`org-iw--document-marker').  Refuse as `org-iw--require-source'."
  (org-iw--require-source)
  (org-with-wide-buffer
   (if (org-before-first-heading-p)
       (org-iw--document-marker)
     (org-back-to-heading t)
     (point-marker))))

(defun org-iw--configured-queues ()
  "Return `org-iw-queues' as an alist (QUEUE . PLIST), QUEUE canonical.
Entries whose key is not a valid queue ID are left out."
  (seq-keep (lambda (config)
              (when-let* ((queue (org-iw-core-queue-id (car-safe config))))
                (cons queue (cdr config))))
            org-iw-queues))

(defun org-iw--queue-config (queue)
  "Return the options configured for QUEUE, a canonical queue ID, or nil."
  (alist-get queue (org-iw--configured-queues) nil nil #'equal))

(defun org-iw--configured-name (queue)
  "Return the :name configured for QUEUE, a canonical queue ID, or nil."
  (plist-get (org-iw--queue-config queue) :name))

(defun org-iw--queue-name (queue)
  "Return the display name of QUEUE, a canonical queue ID."
  (or (org-iw--configured-name queue) queue))

(defun org-iw--queue-id (queue)
  "Return QUEUE, a queue ID in any case, canonical; refuse if invalid."
  (or (org-iw-core-queue-id queue)
      (org-iw-core-refuse "invalid queue ID %S" queue)))

(defun org-iw--order (scan queue)
  "Return the members of QUEUE, a canonical queue ID, in SCAN, in order."
  (org-iw-core-queue-order (org-iw-scan-entries scan) queue))

(defun org-iw--find-entry (entries id &optional file)
  "Return the element of ENTRIES with ID, and with FILE if given, or nil."
  (cl-find-if (lambda (entry)
                (and (equal (org-iw-entry-id entry) id)
                     (or (null file) (equal (org-iw-entry-file entry) file))))
              entries))

(defun org-iw--entry-marker (scan entry)
  "Return a marker at ENTRY of SCAN, resolved afresh, or refuse.
See `org-iw-discovery-resolve'."
  (org-iw-discovery-resolve scan (org-iw-entry-id entry)
                            (org-iw-entry-file entry)))

(defun org-iw--refuse-no-room (where name)
  "Refuse because queue NAME has no rank left WHERE.
WHERE is text carrying its preposition, such as \"at the end\"."
  (org-iw-core-refuse "no room %s in %s; redistribution is not yet available"
                      where name))

(defun org-iw--known-queues (scan)
  "Return the canonical IDs of the configured queues and those in SCAN.
The list is sorted and has no duplicates; configured IDs that are not
valid are left out."
  (sort (seq-uniq
         (append (mapcar #'car (org-iw--configured-queues))
                 (org-iw-core-queue-ids (org-iw-scan-entries scan))))
        #'string<))

(defun org-iw--read-queue (queues &optional require-match)
  "Prompt for a queue ID and return the string entered, unchecked.
Completion offers QUEUES, canonical queue IDs, annotated with their
configured names.  Unless REQUIRE-MATCH is non-nil, any other ID may
be typed."
  (let ((completion-extra-properties
         (list :annotation-function
               (lambda (queue)
                 (when-let* ((name (org-iw--configured-name queue)))
                   (concat " " name))))))
    (completing-read "Queue: " queues nil require-match)))

;;;; Vocabulary

(defun org-iw--check-placements (placements source)
  "Return PLACEMENTS, a list of (LABEL PLACEMENT), or refuse.
SOURCE names the option they came from, for the refusal.  The label
Remove, in any case, is reserved for the chooser of `org-iw-continue'."
  (cond ((null placements) (org-iw-core-refuse "%s: no placements" source))
        ((not (proper-list-p placements))
         (org-iw-core-refuse "%s: not a list" source)))
  (let ((labels nil))
    (dolist (entry placements placements)
      (pcase entry
        (`(,(and (pred stringp) (pred (not string-empty-p)) label)
           ,(pred org-iw-core-placement-p))
         (when (string-equal-ignore-case label "Remove")
           (org-iw-core-refuse "%s: label \"%s\" is reserved" source label))
         (when (member label labels)
           (org-iw-core-refuse "%s: duplicate label \"%s\"" source label))
         (push label labels))
        (_ (org-iw-core-refuse "%s: invalid entry %S" source entry))))))

(defun org-iw--vocabulary (queue)
  "Return the vocabulary of QUEUE, a canonical queue ID, or refuse.
The vocabulary is (DEFAULT-LABEL . PLACEMENTS), PLACEMENTS a list of
\(LABEL PLACEMENT) in configured order: the queue's :placements, else
`org-iw-placements'.  DEFAULT-LABEL is the queue's :default, else,
unless the queue has its own :placements, `org-iw-default-placement',
else the first label.  Refuse, naming the option at fault, unless the
placements are valid and the default is one of their labels."
  (let* ((config (org-iw--queue-config queue))
         (own (plist-member config :placements))
         (prefix (format "queue %s " (org-iw--queue-name queue)))
         (placements (org-iw--check-placements
                      (if own (cadr own) org-iw-placements)
                      (if own (concat prefix ":placements")
                        "org-iw-placements")))
         (default (cond ((plist-member config :default)
                         (cons (plist-get config :default)
                               (concat prefix ":default")))
                        ((and (not own) org-iw-default-placement)
                         (cons org-iw-default-placement
                               "org-iw-default-placement"))
                        (t (list (caar placements))))))
    (unless (assoc (car default) placements)
      (org-iw-core-refuse "%s: %S is not a placement label"
                          (cdr default) (car default)))
    (cons (car default) placements)))

(defun org-iw--placement (queue label)
  "Return (LABEL . PLACEMENT) for LABEL in QUEUE's vocabulary, or refuse.
QUEUE is a canonical queue ID.  A nil LABEL means the default."
  (pcase-let* ((`(,default . ,placements) (org-iw--vocabulary queue))
               (label (or label default)))
    (if-let* ((entry (assoc label placements)))
        (cons label (cadr entry))
      (org-iw-core-refuse "queue %s has no placement \"%s\""
                          (org-iw--queue-name queue) label))))

(defun org-iw--read-placement (queue &optional with-remove)
  "Prompt for a label of QUEUE's vocabulary and return it.
QUEUE is a canonical queue ID.  The labels are offered in configured
order, the default as the default.  WITH-REMOVE non-nil offers Remove
after them, returned as the symbol `remove'.  Bad configuration
refuses before the prompt.  The prompt names the queue."
  (pcase-let* ((`(,default . ,placements) (org-iw--vocabulary queue))
               (candidates (append placements
                                   (and with-remove '(("Remove"))))))
    (pcase (completing-read
            (format "Placement in %s: " (org-iw--queue-name queue))
            (lambda (string predicate action)
              (if (eq action 'metadata)
                  '(metadata (display-sort-function . identity)
                             (cycle-sort-function . identity))
                (complete-with-action action candidates string predicate)))
            nil t nil nil default)
      ("Remove" 'remove)
      (label label))))

;;;; Messages

(defun org-iw--save-status (status)
  "Return the text reporting STATUS, a result of a write.
That is `org-iw-write-put-rank' or `org-iw-write-delete-rank'."
  (pcase status
    ('saved "(saved)")
    ('unsaved "(buffer has unsaved changes — queue change not saved)")
    (`(save-failed . ,err)
     (format "(queue change applied but not saved: %s)"
             (error-message-string err)))))

(defun org-iw--report (scan format-string &rest args)
  "Echo FORMAT-STRING applied to ARGS, noting the problems of SCAN.
Return the message."
  (let ((problems (length (org-iw-scan-problems scan))))
    (message "%s%s" (apply #'format format-string args)
             (if (zerop problems)
                 ""
               (format " [%d source problems ignored]" problems)))))

;;;; Session

(cl-defstruct (org-iw--session (:constructor org-iw--session-create)
                               (:copier nil))
  "The entry being worked on: its QUEUE (canonical ID), ID and TITLE."
  queue id title)

(defvar org-iw--session nil
  "The current `org-iw--session', or nil.
Set only by `org-iw--session-start'; cleared only by
`org-iw--session-end'.")

(defconst org-iw--mode-line-construct '(:eval (org-iw--mode-line))
  "The `global-mode-string' item showing the session.")

(defun org-iw--mode-line ()
  "Return the mode-line text for the session, or nil without one.
The text is IW[NAME: TITLE] and a space, which separates it from the
next item, with % doubled in both so that the mode line shows it
literally."
  (when org-iw--session
    (let ((escape (lambda (text) (string-replace "%" "%%" text))))
      (format "IW[%s: %s] "
              (funcall escape (org-iw--queue-name
                               (org-iw--session-queue org-iw--session)))
              (funcall escape (org-iw--session-title org-iw--session))))))

(defun org-iw--session-start (queue entry)
  "Make ENTRY, of QUEUE, a canonical queue ID, the session's entry.
Show the session in the mode line."
  (setq org-iw--session (org-iw--session-create
                         :queue queue
                         :id (org-iw-entry-id entry)
                         :title (org-iw-entry-title entry)))
  (unless (listp global-mode-string)
    (setq global-mode-string (list global-mode-string)))
  (add-to-list 'global-mode-string org-iw--mode-line-construct)
  (force-mode-line-update t))

(defun org-iw--session-end ()
  "End the session and take it off the mode line.
Return the session that ended, or nil if there was none."
  (prog1 org-iw--session
    (setq org-iw--session nil)
    (when (listp global-mode-string)
      (setq global-mode-string (delete org-iw--mode-line-construct
                                       global-mode-string)))
    (force-mode-line-update t)))

(defun org-iw--session-entry-p (queue id)
  "Return non-nil if the session's entry is ID in QUEUE, a canonical queue ID."
  (and org-iw--session
       (equal (org-iw--session-queue org-iw--session) queue)
       (equal (org-iw--session-id org-iw--session) id)))

(defun org-iw--session-hint ()
  "Return the hint shown when the session names an entry no longer queued."
  (concat "The session still names it: org-iw-visit-next to go on,"
          " org-iw-end-session to stop"))

(defun org-iw--read-known-queue ()
  "Return a queue ID read over the configured and discovered queues."
  (org-iw--read-queue (org-iw--known-queues (org-iw--scan))))

(defun org-iw--read-session-queue ()
  "Return the session's queue, or a queue ID read from the user.
The ID is read, over the configured and discovered queues, when there
is a prefix argument or no session."
  (if (and org-iw--session (not current-prefix-arg))
      (org-iw--session-queue org-iw--session)
    (org-iw--read-known-queue)))

;;;; Add

(defun org-iw--problem-types-text (types)
  "Return problem TYPES, a list of symbols, as text for a refusal."
  (if types (mapconcat #'symbol-name types ", ") "unknown"))

(defun org-iw--refuse-excluded (types)
  "Refuse the entry at point as excluded by the scan, for TYPES, as text."
  (org-iw-core-refuse "entry at point is excluded (%s)" types))

(defun org-iw--excluded-types (scan queue id)
  "Return why SCAN excluded the entry at point, ID, from QUEUE, or nil.
QUEUE is a canonical queue ID, and the entry is not one of its
members.  If the entry has an IW_ line for QUEUE, the scan excluded
it: return SCAN's problem types for ID, as text.  Else return nil."
  (and (org-iw-discovery-queue-lines queue)
       (org-iw--problem-types-text (org-iw-discovery-problem-types scan id))))

(defun org-iw--add-entry (scan order marker queue placement document
                               &optional where)
  "Add the entry at MARKER to QUEUE at PLACEMENT, unless it is a member.
ORDER is QUEUE's members in SCAN, and QUEUE a canonical queue ID.
MARKER is at a heading or, with DOCUMENT non-nil, at the document's
entry (see `org-iw--document-marker').

If the entry is in ORDER, write nothing and return (existing
POSITION), POSITION being 1-based.  Else write its rank, giving it an
ID only if it has no identity, and return (added DEPTH STATUS ENTRY):
DEPTH is its index in the new order, STATUS the result of
`org-iw-write-put-rank', and ENTRY the entry as a scan now reads it.

Refuse, writing nothing, if the entry has an IW_ line for QUEUE that
SCAN excluded, another entry has its ID, or there is no room at
PLACEMENT, WHERE being its text, with its preposition (by default,
\"at the end\"), or if the write refuses."
  (org-with-point-at marker
    (let* ((file (org-iw--buffer-truename))
           (id (if document
                   (org-iw-discovery-document-id file)
                 (org-iw-discovery-entry-id file))))
      (if-let* ((index (cl-position (org-iw--find-entry order id file) order)))
          (list 'existing (1+ index))
        ;; A file starting with a heading has no document drawer yet:
        ;; the lines at its start are the heading's.
        (when-let* ((types (and (or (not document)
                                    (org-iw-discovery-document-slot-p))
                                (org-iw--excluded-types scan queue id))))
          (org-iw--refuse-excluded types))
        (when (and id (org-iw-discovery-shared-id-p scan id file))
          (org-iw-core-refuse "ID shared with another heading"))
        (pcase (org-iw-core-place order nil queue placement)
          (`(no-gap ,_)
           (org-iw--refuse-no-room (or where "at the end")
                                   (org-iw--queue-name queue)))
          (`(moved ,depth ,rank)
           (let ((status (org-iw-write-put-rank marker queue rank
                                                :expected :absent
                                                :ensure-id (null id)
                                                :document document)))
             (list 'added depth status (org-iw-discovery-entry file)))))))))

(defun org-iw--add-at (marker document queue label)
  "Add the entry at MARKER, the DOCUMENT or not, to QUEUE at LABEL.
See `org-iw--add-entry' and `org-iw-add', which documents QUEUE and
LABEL.  Return the message shown."
  (pcase-let* ((queue-id (org-iw--queue-id queue))
               (`(,where . ,placement)
                (if label (org-iw--placement queue-id label) '(nil . end)))
               (scan (org-iw--scan))
               (order (org-iw--order scan queue-id))
               (name (org-iw--queue-name queue-id)))
    (pcase (org-iw--add-entry scan order marker queue-id placement document
                              (and where (format "at %s" where)))
      (`(existing ,position)
       (org-iw--report scan "Already in %s at %d/%d"
                       name position (length order)))
      (`(added ,depth ,status ,_)
       (org-iw--report scan "Added to %s at %s%d/%d %s"
                       name (if where (concat where ", ") "")
                       (1+ depth) (1+ (length order))
                       (org-iw--save-status status))))))

(defun org-iw--read-add-args ()
  "Read the arguments of `org-iw-add' and `org-iw-add-document'.
That is a queue ID and, with a prefix argument, a label."
  (let ((queue (org-iw--read-known-queue)))
    (list queue
          (and current-prefix-arg
               (org-iw--read-placement (org-iw--queue-id queue))))))

;;;###autoload
(defun org-iw-add (queue &optional label)
  "Add the entry at point to QUEUE, at the placement LABEL.
QUEUE is a queue ID in any case; interactively, it is read with
completion over the configured and discovered queues, and a new
one may be typed.  LABEL names one of the queue's placements (see
`org-iw-placements' and `org-iw-queues'); nil means the end.
Interactively, a prefix argument reads LABEL after QUEUE, with
completion over the queue's labels, defaulting to its default.

The entry is the heading at or above point, even outside a
narrowing; indirect buffers work.  Before the first heading it is
the document, as with `org-iw-add-document'.  A heading is given an
ID and a property drawer if it lacks them, and its file is saved
unless its buffer already had unsaved changes.

An entry already in QUEUE is left alone.  Add refuses, changing
nothing, if the buffer is not a source file or not in Org mode (a
derived mode counts), QUEUE is not a valid ID, LABEL is given and is
not one of the queue's labels or the queue's placements are
misconfigured (checked before any scan), the entry has a property
drawer Org does not see, its IW property for QUEUE was excluded by
the scan, another entry has its ID, there is no room for a rank at
the placement, or the write refuses (the file changed on disk or is
not writable, or its buffer is read-only).

Return the message shown."
  ;; Called for its refusals: a buffer Add cannot use fails before
  ;; the prompt.
  (interactive (progn (org-iw--target-at-point) (org-iw--read-add-args)))
  (let ((marker (org-iw--target-at-point)))
    (org-iw--add-at marker (org-with-point-at marker
                             (org-before-first-heading-p))
                    queue label)))

;;;###autoload
(defun org-iw-add-document (queue &optional label)
  "Add the document of the current buffer to QUEUE, at the placement LABEL.
QUEUE and LABEL are as for `org-iw-add', and read the same way
interactively, the prefix argument included.

The document is the whole file, wherever point is; narrowing and
indirect buffers make no difference.  Its entry is the property
drawer at the start of the file, inserted there, before any heading,
if the file has none.  A document's ID is that drawer's ID or, for a
file named in Denote's scheme with Denote available, the identifier
in its name; the document is given an ID only if it has neither.
The file is saved unless its buffer already had unsaved changes.

A document already in QUEUE is left alone.  Add-document refuses as
`org-iw-add' does, changing nothing.

Return the message shown."
  ;; Called for its refusals: a buffer it cannot use fails before the
  ;; prompt.
  (interactive (progn (org-iw--require-source) (org-iw--read-add-args)))
  (org-iw--require-source)
  (org-iw--add-at (org-iw--document-marker) t queue label))

;;;; Visit

(defun org-iw--visit (scan entry queue pos total &optional other-window)
  "Show ENTRY of SCAN, POS of TOTAL in QUEUE, and make it the session.
QUEUE is a canonical queue ID.  The entry's buffer is shown in the
selected window or, if OTHER-WINDOW is non-nil, in another window,
which is selected.  It is widened only if its narrowing hides the
entry, with point at the entry and the entry revealed.  If the entry
cannot be resolved, refuse before anything changes.  Nothing is
written.

Return the message shown."
  (let ((marker (org-iw--entry-marker scan entry)))
    (if other-window
        (pop-to-buffer (marker-buffer marker) t)
      (pop-to-buffer-same-window (marker-buffer marker)))
    ;; The heading starts at MARKER, so at point-max it is hidden too.
    (unless (and (<= (point-min) marker) (< marker (point-max)))
      (widen))
    (goto-char marker)
    (org-fold-reveal)
    (org-fold-show-entry)
    (org-iw--session-start queue entry)
    (org-iw--report scan "IW %s %d/%d: %s" (org-iw--queue-name queue)
                    pos total (org-iw-entry-title entry))))

(defun org-iw--empty-text (queue)
  "Return the text saying QUEUE, a canonical queue ID, is empty."
  (format "Queue %s is empty" (org-iw--queue-name queue)))

(defun org-iw--report-empty (scan queue)
  "Report that QUEUE, a canonical queue ID, is empty, noting SCAN's problems.
Return the message shown."
  (org-iw--report scan "%s" (org-iw--empty-text queue)))

;;;###autoload
(defun org-iw-visit-next (queue)
  "Visit the first entry of QUEUE and make it the session's entry.
QUEUE is a queue ID in any case.  Interactively, it is the session's
queue; with a prefix argument, or without a session, it is read with
completion over the configured and discovered queues.

The entry's buffer is shown in the selected window, widened only if
its narrowing hides the entry.  Nothing is written, so visiting again
without `org-iw-continue' shows the same entry.  An empty queue is
reported and changes nothing.  Refuses if QUEUE is not a valid ID or
the entry cannot be found.

Return the message shown."
  (interactive (list (org-iw--read-session-queue)))
  (let* ((queue-id (org-iw--queue-id queue))
         (scan (org-iw--scan))
         (order (org-iw--order scan queue-id)))
    (if order
        (org-iw--visit scan (car order) queue-id 1 (length order))
      (org-iw--report-empty scan queue-id))))

;;;; Membership writes

(defun org-iw--refuse-absent (scan queue id title)
  "Refuse because the entry ID, titled TITLE, is not in QUEUE in SCAN.
QUEUE is a canonical queue ID.  Say whether SCAN excluded ID as a
duplicate."
  (let ((name (org-iw--queue-name queue)))
    (if (org-iw-discovery-excluded-id-p scan id)
        (org-iw-core-refuse "ID %s is duplicated; %s is excluded from queue %s"
                            id title name)
      (org-iw-core-refuse "%s is no longer in queue %s" title name))))

(defun org-iw--find-member (scan order queue id title)
  "Return the element of ORDER with ID, or refuse it as absent.
ORDER is QUEUE's members in SCAN; TITLE names the entry in the
refusal.  See `org-iw--refuse-absent'."
  (or (org-iw--find-entry order id)
      (org-iw--refuse-absent scan queue id title)))

(defun org-iw--put-rank (scan entry queue rank)
  "Write RANK to ENTRY of SCAN in QUEUE, a canonical queue ID.
The write expects ENTRY's scanned rank.  Return the result of
`org-iw-write-put-rank'."
  (org-iw-write-put-rank (org-iw--entry-marker scan entry) queue rank
                         :expected (org-iw-core-rank entry queue)))

(defun org-iw--delete-rank (scan entry queue)
  "Delete the rank of ENTRY of SCAN in QUEUE, a canonical queue ID.
The delete expects ENTRY's scanned rank.  Return the result of
`org-iw-write-delete-rank'."
  (org-iw-write-delete-rank (org-iw--entry-marker scan entry) queue
                            :expected (org-iw-core-rank entry queue)))

(defun org-iw--move (scan order entry queue placement &optional where)
  "Move ENTRY, an element of ORDER, to PLACEMENT in QUEUE.
ORDER is QUEUE's members in SCAN, and QUEUE a canonical queue ID.
Return (unchanged DEPTH), writing nothing, or (moved DEPTH STATUS)
after writing ENTRY's new rank against its scanned rank; DEPTH is
ENTRY's index in the new order and STATUS the result of
`org-iw-write-put-rank'.  Refuse if there is no room at PLACEMENT,
WHERE being its text, with its preposition; without WHERE, the text
is the position ENTRY would take, as \"at position 2/3\"."
  (pcase (org-iw-core-place order entry queue placement)
    (`(no-gap ,depth)
     (org-iw--refuse-no-room
      (or where (format "at position %d/%d" (1+ depth) (length order)))
      (org-iw--queue-name queue)))
    (`(unchanged ,depth) (list 'unchanged depth))
    (`(moved ,depth ,rank)
     (list 'moved depth (org-iw--put-rank scan entry queue rank)))))

(defun org-iw--moved-text (result title where total)
  "Return the text reporting RESULT of `org-iw--move' for the entry TITLE.
WHERE names the placement, as \"Soon\" or \"Soon in ESSAYS\", or is nil
to give only the position.  TOTAL is the number of the queue's members."
  (pcase-let* ((`(,outcome ,depth ,status) result)
               (at (format "%s%d/%d" (if where (concat where ", ") "")
                           (1+ depth) total)))
    (if (eq outcome 'moved)
        (format "Moved %s to %s %s" title at (org-iw--save-status status))
      (format "%s already at %s" title at))))

(defun org-iw--removed-text (entry queue status &optional then)
  "Return the text reporting ENTRY removed from QUEUE, a canonical queue ID.
STATUS is the result of `org-iw-write-delete-rank'.  The sentence THEN,
if given, follows; then the session hint, if the session still names
ENTRY in QUEUE."
  (string-join
   (delq nil
         (list (format "Removed %s from %s %s" (org-iw-entry-title entry)
                       (org-iw--queue-name queue) (org-iw--save-status status))
               then
               (and (org-iw--session-entry-p queue (org-iw-entry-id entry))
                    (org-iw--session-hint))))
   ". "))

(defun org-iw--now-text (order)
  "Return the text naming the head of ORDER, a non-empty queue order."
  (format "Now 1/%d: %s" (length order) (org-iw-entry-title (car order))))

;;;; Continue

(defun org-iw--session-or-refuse ()
  "Return the session, or refuse if there is none."
  (or org-iw--session
      (org-iw-core-refuse "no session; run org-iw-visit-next first")))

(defun org-iw--continue-place (scan order entry queue choice)
  "Move ENTRY, of ORDER, to the placement CHOICE in QUEUE; visit the head.
ORDER is QUEUE's members in SCAN, QUEUE a canonical queue ID, and
CHOICE (LABEL . PLACEMENT), as from `org-iw--placement'.  The only
entry is left alone.  Return the message shown."
  (pcase-let ((`(,label . ,placement) choice)
              (title (org-iw-entry-title entry))
              (total (length order)))
    (if (null (cdr order))
        (org-iw--report scan "%s is the only entry in queue %s"
                        title (org-iw--queue-name queue))
      (let* ((result (org-iw--move scan order entry queue placement
                                   (format "at %s" label)))
             (new-order (pcase result
                          (`(moved ,depth ,_)
                           (org-iw-core-reorder order entry depth))
                          (_ order))))
        (org-iw--visit scan (car new-order) queue 1 total)
        (org-iw--report scan "%s. %s"
                        (org-iw--moved-text result title label total)
                        (org-iw--now-text new-order))))))

(defun org-iw--continue-remove (scan order entry queue)
  "Remove ENTRY, of ORDER, from QUEUE; visit the head of the rest.
ORDER is QUEUE's members in SCAN, and QUEUE a canonical queue ID.
With none left, the session stays.  Return the message shown."
  (let ((status (org-iw--delete-rank scan entry queue))
        (rest (remq entry order)))
    ;; Visiting moves the session to the head, so the text gives the
    ;; hint only when no entry is left.
    (when rest
      (org-iw--visit scan (car rest) queue 1 (length rest)))
    (org-iw--report scan "%s" (org-iw--removed-text
                               entry queue status
                               (if rest
                                   (org-iw--now-text rest)
                                 (org-iw--empty-text queue))))))

;;;###autoload
(defun org-iw-continue (&optional label)
  "Reinsert the session's entry at the placement LABEL; visit the next.
The entry is the one `org-iw-visit-next' last showed, whatever is at
point or now first in the queue.  LABEL names one of the queue's
placements (see `org-iw-placements' and `org-iw-queues'); nil means
the queue's default.  Interactively, a prefix argument reads LABEL
with completion over the queue's labels, then Remove.

The entry is given a rank between its new neighbours through its
buffer, which is saved unless it already had unsaved changes.  Then
the first member of the queue is visited and becomes the session's
entry.  At the front, that is the entry itself.

LABEL may also be the symbol `remove': the entry's IW line for the
queue is deleted instead, unconfirmed, and the first of the rest is
visited.  If none remain, the session is left on the entry and the
message says how to go on or stop.  The placements' configuration
is not consulted.

An entry already at its placement is not written, the only entry in
its queue is left alone unless removed, and an empty queue is
reported; none of these change anything.  Continue refuses, writing
and visiting nothing, if:

- there is no session;
- the queue's placements are misconfigured (checked before the
  prompt), or LABEL is not one of its labels (before any scan);
- a source buffer is not in Org mode;
- the entry has left its queue, or its ID is duplicated, missing or
  ambiguous in its file;
- there is no room for a rank at the placement; or
- the write refuses: the file changed on disk or is not writable, its
  buffer is read-only, the rank changed since the scan, or the entry
  has a property drawer Org doesn't recognise.

Return the message shown."
  (interactive
   (let ((session (org-iw--session-or-refuse)))
     (list (and current-prefix-arg
                (org-iw--read-placement (org-iw--session-queue session) t)))))
  (let* ((session (org-iw--session-or-refuse))
         (queue (org-iw--session-queue session))
         (choice (unless (eq label 'remove)
                   (org-iw--placement queue label)))
         (id (org-iw--session-id session))
         (scan (org-iw--scan))
         (order (org-iw--order scan queue)))
    (if (null order)
        (org-iw--report-empty scan queue)
      (let ((retained (org-iw--find-member scan order queue id
                                           (org-iw--session-title session))))
        (if choice
            (org-iw--continue-place scan order retained queue choice)
          (org-iw--continue-remove scan order retained queue))))))

;;;; Move

(defun org-iw--scanned-entry-at (marker scan &optional queue)
  "Return the element of SCAN's entries for the entry at MARKER, or refuse.
Refuse if SCAN left the entry out: as excluded, naming the problem
types of its ID, if it has any, else, also for an entry with no ID, as
being in no queue.  Given QUEUE, a canonical queue ID, refuse also
unless the entry is in it: as excluded if it has an IW_ line for QUEUE
\(see `org-iw--excluded-types'), else as not in QUEUE."
  (org-with-point-at marker
    (let* ((file (org-iw--buffer-truename))
           (id (org-iw-discovery-entry-id file))
           (entry (and id (org-iw--find-entry (org-iw-scan-entries scan)
                                              id file)))
           (absent (and entry queue (not (org-iw-core-rank entry queue))))
           (excluded
            (cond (absent (org-iw--excluded-types scan queue id))
                  ((and id (not entry))
                   (when-let* ((types (org-iw-discovery-problem-types scan id)))
                     (org-iw--problem-types-text types))))))
      (cond (excluded
             (org-iw--refuse-excluded excluded))
            ((not entry)
             (org-iw-core-refuse "entry at point is not in any queue"))
            (absent
             (org-iw-core-refuse "%s is not in queue %s"
                                 (org-iw-entry-title entry)
                                 (org-iw--queue-name queue)))
            (t entry)))))

(defun org-iw--membership-queue (entry &optional ask)
  "Return the queue, a canonical ID, to act on for ENTRY.
With ASK non-nil, it is read from the user, who must choose among
ENTRY's queues, even if there is one.  Otherwise it is ENTRY's only
queue; of several, the session's if it is one of them, else read."
  (let ((queues (mapcar #'car (org-iw-entry-memberships entry)))
        (session-queue (and org-iw--session
                            (org-iw--session-queue org-iw--session))))
    (or (unless ask
          (if (cdr queues) (car (member session-queue queues)) (car queues)))
        (org-iw--read-queue queues t))))

(defun org-iw--queue-at-point (&optional ask)
  "Return the queue to act on for the entry at point, a canonical ID.
See `org-iw--membership-queue' for ASK."
  (org-iw--membership-queue
   (org-iw--scanned-entry-at (org-iw--target-at-point) (org-iw--scan))
   ask))

;;;###autoload
(defun org-iw-move (queue &optional label)
  "Move the entry at point to the placement LABEL in QUEUE.
QUEUE is a queue ID in any case, one the entry is in; LABEL names one
of the queue's placements (see `org-iw-placements' and
`org-iw-queues'), nil meaning the queue's default.  Interactively,
QUEUE is the entry's only queue or, of several, the session's if it is
one of them, else it is read; with a prefix argument it is always
read, among the entry's queues.  Then LABEL is read, defaulting to the
queue's default.

The entry is the heading at or above point, even outside a narrowing,
or the document before the first heading; indirect buffers work.  Its
rank in QUEUE is rewritten through its buffer, which is saved unless
it already had unsaved changes.  Nothing is visited and the session is
left as it is.  An entry already at its placement is not written.

Move refuses, writing nothing, if the buffer is not a source file or
not in Org mode, QUEUE is not a valid ID, LABEL is not one of the
queue's labels or its placements are misconfigured (checked before any
scan), the entry is in no queue, was excluded by the scan or is not in
QUEUE, there is no room for a rank at the placement, or the write
refuses (the file changed on disk or is not writable, its buffer is
read-only, or the entry has a property drawer Org doesn't recognise).

Return the message shown."
  (interactive
   (let ((queue (org-iw--queue-at-point current-prefix-arg)))
     (list queue (org-iw--read-placement queue))))
  (pcase-let* ((queue-id (org-iw--queue-id queue))
               (marker (org-iw--target-at-point))
               (`(,label . ,placement) (org-iw--placement queue-id label))
               (scan (org-iw--scan))
               (entry (org-iw--scanned-entry-at marker scan queue-id))
               (order (org-iw--order scan queue-id)))
    (org-iw--report scan "%s" (org-iw--moved-text
                               (org-iw--move scan order entry queue-id
                                             placement (format "at %s" label))
                               (org-iw-entry-title entry)
                               (format "%s in %s" label
                                       (org-iw--queue-name queue-id))
                               (length order)))))

;;;; Remove

;;;###autoload
(defun org-iw-remove (queue)
  "Remove the entry at point from QUEUE.
QUEUE is a queue ID in any case, one the entry is in.  Interactively,
it is the entry's only queue or, of several, the session's if it is
one of them, else it is read; with a prefix argument it is always
read, among the entry's queues.

The entry is the heading at or above point, even outside a narrowing,
or the document before the first heading; indirect buffers work.  Its
IW line for QUEUE alone is deleted through its buffer, which is saved
unless it already had unsaved changes.  There is no confirmation: the
buffer has undo.  The session is left as it is, even when it names
the entry; the message then says how to go on or stop.

Remove refuses, writing nothing, if the buffer is not a source file
or not in Org mode, QUEUE is not a valid ID, the entry is in no
queue, was excluded by the scan or is not in QUEUE, or the write
refuses (the file changed on disk or is not writable, its buffer is
read-only, or the entry has a property drawer Org doesn't recognise).

Return the message shown."
  (interactive (list (org-iw--queue-at-point current-prefix-arg)))
  (let* ((queue-id (org-iw--queue-id queue))
         (marker (org-iw--target-at-point))
         (scan (org-iw--scan))
         (entry (org-iw--scanned-entry-at marker scan queue-id)))
    (org-iw--report scan "%s" (org-iw--removed-text
                               entry queue-id
                               (org-iw--delete-rank scan entry queue-id)))))

;;;; Queue view

(defun org-iw--outline-text (outline width)
  "Return OUTLINE, ancestor titles outermost first, as text WIDTH wide or less.
The titles join with \" / \".  Text too wide drops the outermost
ancestors behind \"…/\" until it fits; if the nearest ancestor alone is
too wide, its right end is kept, so that the nearest stay visible."
  (let ((tail outline)
        (text (string-join outline " / ")))
    (while (and (cdr tail) (> (string-width text) width))
      (setq tail (cdr tail)
            text (concat "…/" (string-join tail " / "))))
    (if (<= (string-width text) width)
        text
      (let ((end (car tail)))
        (while (> (string-width end) (- width 2))
          (setq end (substring end 1)))
        (concat "…/" end)))))

(defconst org-iw--view-context-width 30
  "The width of the queue view's Context column.")

(defvar-keymap org-iw-view-mode-map
  :doc "Keymap for `org-iw-view-mode'."
  :parent tabulated-list-mode-map
  "RET" #'org-iw-view-open
  "M-<up>" #'org-iw-view-move-up
  "M-<down>" #'org-iw-view-move-down
  "m" #'org-iw-view-mark
  "u" #'org-iw-view-unmark
  "b" #'org-iw-view-place-before
  "a" #'org-iw-view-place-after
  "D" #'org-iw-view-remove)

(define-derived-mode org-iw-view-mode tabulated-list-mode "IW Queue"
  "Major mode for the view of one queue, its entries listed in order.
Each row shows the entry's position, title, outline context and file;
the session's entry is starred, and the marked entry tagged \">\".

\\{org-iw-view-mode-map}"
  (setq tabulated-list-format
        `[("#" 5 nil :right-align t) ("Title" 40 nil)
          ("Context" ,org-iw--view-context-width nil) ("File" 0 nil)])
  (setq tabulated-list-padding 2)
  (setq tabulated-list-printer #'org-iw--view-print-row)
  (setq-local revert-buffer-function #'org-iw--view-revert)
  (tabulated-list-init-header))

(defvar-local org-iw--view-queue nil
  "The canonical ID of the queue the view buffer shows.
It survives turning the mode on again.")
(put 'org-iw--view-queue 'permanent-local t)

(defvar-local org-iw--view-mark nil
  "The ID of the view's marked entry, or nil.
It is display state, tagged on the entry's row.")

(defun org-iw--view-buffer (queue)
  "Return the view buffer of QUEUE, a canonical queue ID, making it if need be.
A view is found by queue ID, so queues sharing a name have a view
each.  Only a new view is put in `org-iw-view-mode'."
  (or (seq-find (lambda (buffer)
                  (equal (buffer-local-value 'org-iw--view-queue buffer) queue))
                (buffer-list))
      (with-current-buffer (generate-new-buffer
                            (format "*org-iw: %s*" (org-iw--queue-name queue)))
        (org-iw-view-mode)
        (setq org-iw--view-queue queue)
        (current-buffer))))

(defun org-iw--view-row (entry ordinal current)
  "Return the view row of ENTRY, ORDINAL in its queue's order, 1-based.
CURRENT non-nil marks the session's entry: its ordinal is starred and
its title bold.  The row is (ID [ORDINAL TITLE CONTEXT FILE]), as in
`tabulated-list-entries'."
  (let ((title (org-link-display-format (org-iw-entry-title entry))))
    (list (org-iw-entry-id entry)
          (vector (format "%d%s" ordinal (if current "*" ""))
                  (if current (propertize title 'face 'bold) title)
                  (propertize (org-iw--outline-text
                               (org-iw-entry-outline entry)
                               org-iw--view-context-width)
                              'face 'shadow)
                  (file-name-nondirectory (org-iw-entry-file entry))))))

(defun org-iw--view-title (id)
  "Return the title on the view row of the entry ID, as plain text."
  (substring-no-properties (aref (cadr (assoc id tabulated-list-entries)) 1)))

(defun org-iw--view-row-position (id)
  "Return the start of the view row of the entry ID, or nil if not listed."
  (and id
       (save-excursion
         (goto-char (point-min))
         (when-let* ((match (text-property-search-forward
                             'tabulated-list-id id t)))
           (prop-match-beginning match)))))

(defun org-iw--view-tag-row ()
  "Tag the view row at point \">\" if its entry is marked, else untag it.
This is the one place the mark is drawn."
  (tabulated-list-put-tag
   (if (equal (tabulated-list-get-id) org-iw--view-mark) ">" "")))

(defun org-iw--view-print-row (id cols)
  "Print the view row of the entry ID, with COLS, then tag it.
This is the view's `tabulated-list-printer', so that every print,
tabulated-list's own included, shows the mark."
  (tabulated-list-print-entry id cols)
  (save-excursion
    (forward-line -1)
    (org-iw--view-tag-row)))

(defun org-iw--view-set-mark (id)
  "Mark the entry ID in the view, or clear the mark if ID is nil.
The old mark's row and ID's row, where listed, are tagged afresh."
  (let ((old org-iw--view-mark))
    (setq org-iw--view-mark id)
    (dolist (row (list old id))
      (when-let* ((position (org-iw--view-row-position row)))
        (save-excursion
          (goto-char position)
          (org-iw--view-tag-row))))))

(defun org-iw--view-redraw (scan &optional goto-id)
  "Show the members of the view's queue in SCAN in the current buffer.
Point goes to the row of the entry GOTO-ID, if given and listed, else
stays on the row it was on, found by ID.  If that entry is gone, point
stays on the same line, or goes to the last row when fewer remain.
The marked entry's row is tagged as it is printed; the mark is cleared
if the entry is not listed.  Then every window showing the buffer is given
the buffer's point: printing erases the buffer, which resets the point
of a window that is not selected."
  (let ((id (tabulated-list-get-id))
        (line (line-number-at-pos)))
    (setq tabulated-list-entries
          (seq-map-indexed
           (lambda (entry index)
             (org-iw--view-row entry (1+ index)
                               (org-iw--session-entry-p
                                org-iw--view-queue (org-iw-entry-id entry))))
           (org-iw--order scan org-iw--view-queue)))
    (tabulated-list-print t)
    (if-let* ((position (org-iw--view-row-position goto-id)))
        (goto-char position)
      (unless (equal (tabulated-list-get-id) id)
        (goto-char (point-min))
        (forward-line (1- (min line (length tabulated-list-entries))))))
    (unless (assoc org-iw--view-mark tabulated-list-entries)
      (setq org-iw--view-mark nil)))
  (dolist (window (get-buffer-window-list nil nil t))
    (set-window-point window (point))))

(defun org-iw--view-refresh (scan)
  "Redraw the view in the current buffer from SCAN; report its queue.
The report counts the queue's members, noting SCAN's problems.
Return the message shown."
  (org-iw--view-redraw scan)
  (let ((queue org-iw--view-queue)
        (count (length tabulated-list-entries)))
    (if (zerop count)
        (org-iw--report-empty scan queue)
      (org-iw--report scan "Queue %s: %d %s" (org-iw--queue-name queue)
                      count (if (= count 1) "entry" "entries")))))

(defun org-iw--view-revert (&rest _)
  "Refresh the view in the current buffer from a fresh scan.
This is the view's `revert-buffer-function'.  Refuse if the buffer
shows no queue.  Return the message shown."
  (unless org-iw--view-queue
    (org-iw-core-refuse "no queue in this view; run org-iw-list-queue"))
  (org-iw--view-refresh (org-iw--scan)))

(defun org-iw--view-id-at-point ()
  "Return the ID of the entry on the view row at point, or refuse."
  (or (tabulated-list-get-id)
      (org-iw-core-refuse "no entry at point")))

(defun org-iw--view-rescan (&rest ids)
  "Scan afresh and find the entries IDS of the view's queue in the scan.
Return (SCAN ORDER ENTRY...), ORDER the queue's members in SCAN and
each ENTRY that of its ID, in turn.  Refuse at the first ID whose
entry is not there, naming it by its title on the view row."
  (let* ((queue org-iw--view-queue)
         (scan (org-iw--scan))
         (order (org-iw--order scan queue)))
    (cl-list* scan order
              (mapcar (lambda (id)
                        (org-iw--find-member scan order queue id
                                             (org-iw--view-title id)))
                      ids))))

(defun org-iw--view-redraw-and-report (scan id text)
  "Redraw the view from a fresh scan, point on the entry ID; report TEXT.
TEXT reports an action taken against SCAN, whose problems it notes.
Return the message shown."
  (org-iw--view-redraw (org-iw--scan) id)
  (org-iw--report scan "%s" text))

(defun org-iw--view-move (scan order entry placement &optional where)
  "Move ENTRY, of ORDER, to PLACEMENT in the view's queue; redraw on it.
ORDER is the queue's members in SCAN.  WHERE is the placement's text
for a refusal, as for `org-iw--move'.  Return the message shown."
  (org-iw--view-redraw-and-report
   scan (org-iw-entry-id entry)
   (org-iw--moved-text (org-iw--move scan order entry org-iw--view-queue
                                     placement where)
                       (org-iw-entry-title entry) nil (length order))))

(defun org-iw-view-open ()
  "Visit the entry at point in another window and make it the session's.
The entry is found afresh, and its position counted, in a new scan,
from which the view is redrawn.  Refuses off a row, or if the entry
has left the queue.

Return the message shown."
  (interactive)
  (pcase-let* ((id (org-iw--view-id-at-point))
               (view (current-buffer))
               (`(,scan ,order ,entry) (org-iw--view-rescan id)))
    (prog1 (org-iw--visit scan entry org-iw--view-queue
                          (1+ (cl-position entry order)) (length order) t)
      (with-current-buffer view
        (org-iw--view-redraw scan id)))))

(defun org-iw--view-step (delta)
  "Move the entry at point DELTA rows along the view's queue.
The entry is found, and moved, in a fresh scan.  Return the message
shown."
  (pcase-let ((`(,scan ,order ,entry)
               (org-iw--view-rescan (org-iw--view-id-at-point))))
    (org-iw--view-move scan order entry (org-iw-core-step order entry delta))))

(defun org-iw-view-mark ()
  "Mark the entry at point, replacing any mark; its row is tagged.
The marked entry is what `org-iw-view-place-before' and
`org-iw-view-place-after' place.  Nothing is scanned or written.
Refuses off a row.  For interactive use only.

Return nil: the tag is the feedback, and no message is shown."
  (interactive)
  (org-iw--view-set-mark (org-iw--view-id-at-point))
  nil)

(defun org-iw-view-unmark ()
  "Clear the view's mark, whichever row holds it.
Refuses off a row.  For interactive use only.

Return nil: no message is shown."
  (interactive)
  (org-iw--view-id-at-point)
  (org-iw--view-set-mark nil)
  nil)

(defun org-iw--view-place (side)
  "Place the marked entry on SIDE of the entry at point.
SIDE is `before' or `after'.  Both entries are found, and the marked
one moved, in a fresh scan.  The mark clears unless this refuses.
Return the message shown."
  (pcase-let* ((id (org-iw--view-id-at-point))
               (marked-id
                (or org-iw--view-mark
                    (org-iw-core-refuse "no marked entry; mark one with m")))
               (`(,scan ,order ,marked ,anchor)
                (org-iw--view-rescan marked-id id)))
    (prog1 (org-iw--view-move scan order marked
                              (org-iw-core-beside order marked anchor side)
                              (format "%s %s" side (org-iw-entry-title anchor)))
      (org-iw--view-set-mark nil))))

(defun org-iw-view-place-before ()
  "Place the marked entry just before the entry at point; clear the mark.
Point follows the marked entry.  If it is there already, nothing is
written.  Refuses off a row, without a mark, if either entry has left
the queue, if there is no room, or if the write refuses: the file
changed on disk or is not writable, its buffer is read-only, or the
entry has a property drawer Org doesn't recognise.  A refusal keeps
the mark.
For interactive use only.

Return the message shown."
  (interactive)
  (org-iw--view-place 'before))

(defun org-iw-view-place-after ()
  "Place the marked entry just after the entry at point; clear the mark.
Point follows the marked entry.  If it is there already, nothing is
written.  Refuses off a row, without a mark, if either entry has left
the queue, if there is no room, or if the write refuses: the file
changed on disk or is not writable, its buffer is read-only, or the
entry has a property drawer Org doesn't recognise.  A refusal keeps
the mark.
For interactive use only.

Return the message shown."
  (interactive)
  (org-iw--view-place 'after))

(defun org-iw-view-remove ()
  "Remove the entry at point from the view's queue, after confirming.
The entry is found, and its IW line deleted, in a fresh scan; the
view has no undo, but the entry's buffer has.  Point goes to the next
row, else to the previous one.  Answered no, nothing changes.  Refuses
off a row, or, before confirming, if the entry has left the queue.
After confirming, it refuses if the write does: the file changed on
disk or is not writable, its buffer is read-only, the rank changed
since the scan (as by an edit while asked), or the entry has a
property drawer Org doesn't recognise.
For interactive use only.

Return the message shown, or nil if not confirmed."
  (interactive)
  (pcase-let* ((id (org-iw--view-id-at-point))
               (`(,scan ,_ ,entry) (org-iw--view-rescan id)))
    (when (y-or-n-p (format "Remove %s from %s? " (org-iw-entry-title entry)
                            (org-iw--queue-name org-iw--view-queue)))
      (let ((ids (mapcar #'car tabulated-list-entries)))
        (org-iw--view-redraw-and-report
         scan (or (cadr (member id ids)) (cadr (member id (reverse ids))))
         (org-iw--removed-text
          entry org-iw--view-queue
          (org-iw--delete-rank scan entry org-iw--view-queue)))))))

(defun org-iw-view-move-up ()
  "Move the entry at point up one row, writing its new rank.
Point follows the entry.  At the front, nothing is written.  Refuses
off a row, if the entry has left the queue, if there is no room, or if
the write refuses: the file changed on disk or is not writable, its
buffer is read-only, or the entry has a property drawer Org doesn't
recognise.
For interactive use only.

Return the message shown."
  (interactive)
  (org-iw--view-step -1))

(defun org-iw-view-move-down ()
  "Move the entry at point down one row, writing its new rank.
Point follows the entry.  At the end, nothing is written.  Refuses off
a row, if the entry has left the queue, if there is no room, or if the
write refuses: the file changed on disk or is not writable, its buffer
is read-only, or the entry has a property drawer Org doesn't
recognise.
For interactive use only.

Return the message shown."
  (interactive)
  (org-iw--view-step 1))

;;;###autoload
(defun org-iw-list-queue (queue)
  "Show the view of QUEUE, its entries listed in order.
QUEUE is a queue ID in any case.  Interactively, it is the session's
queue; with a prefix argument, or without a session, it is read with
completion over the configured and discovered queues.

The view is the buffer *org-iw: NAME*, NAME the queue's display name,
made the first time and refreshed after.  The queue's number of
entries is reported, or that it is empty.  Nothing is written.
Refuses if QUEUE is not a valid ID.

Return the message shown."
  (interactive (list (org-iw--read-session-queue)))
  (let* ((queue-id (org-iw--queue-id queue))
         (scan (org-iw--scan))
         (view (org-iw--view-buffer queue-id)))
    (prog1 (with-current-buffer view
             (org-iw--view-refresh scan))
      (pop-to-buffer view))))

;;;; End session

;;;###autoload
(defun org-iw-end-session ()
  "End the session and remove it from the mode line.
Without a session this does nothing but say so.  Nothing is written.

Return the message shown."
  (interactive)
  (message (if (org-iw--session-end)
               "org-iw session ended"
             "No org-iw session")))

(provide 'org-iw)
;;; org-iw.el ends here
