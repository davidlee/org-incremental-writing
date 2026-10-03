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
  "Placements offered by `org-iw-continue' and `org-iw-add'.
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

(defun org-iw--target-at-point ()
  "Return a marker at the entry at point, or refuse.
The entry is the heading at or above point, ignoring narrowing, or,
before the first heading, the document, marked at the start of the
buffer.  The current buffer must visit a source file and be in Org
mode."
  (unless (org-iw--source-file-p)
    (org-iw-core-refuse "%s is not under org-iw-sources" (buffer-name)))
  (org-iw-discovery-require-org-mode (org-iw--buffer-truename))
  (org-with-wide-buffer
   (if (org-before-first-heading-p)
       (copy-marker (point-min))
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
SOURCE names the option they came from, for the refusal."
  (cond ((null placements) (org-iw-core-refuse "%s: no placements" source))
        ((not (proper-list-p placements))
         (org-iw-core-refuse "%s: not a list" source)))
  (let ((labels nil))
    (dolist (entry placements placements)
      (pcase entry
        (`(,(and (pred stringp) (pred (not string-empty-p)) label)
           ,(pred org-iw-core-placement-p))
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

(defun org-iw--read-placement (queue)
  "Prompt for a label of QUEUE's vocabulary and return it.
QUEUE is a canonical queue ID.  The labels are offered in configured
order, the default as the default.  Bad configuration refuses before
the prompt."
  (pcase-let ((`(,default . ,placements) (org-iw--vocabulary queue)))
    (completing-read
     "Placement: "
     (lambda (string predicate action)
       (if (eq action 'metadata)
           '(metadata (display-sort-function . identity)
                      (cycle-sort-function . identity))
         (complete-with-action action placements string predicate)))
     nil t nil nil default)))

;;;; Messages

(defun org-iw--save-status (status)
  "Return the text reporting STATUS, a result of `org-iw-write-put-rank'."
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

(defun org-iw--read-session-queue ()
  "Return the session's queue, or a queue ID read from the user.
The ID is read, over the configured and discovered queues, when there
is a prefix argument or no session."
  (if (and org-iw--session (not current-prefix-arg))
      (org-iw--session-queue org-iw--session)
    (org-iw--read-queue (org-iw--known-queues (org-iw--scan)))))

;;;; Add

(defun org-iw--heading-or-refuse (marker)
  "Return MARKER, from `org-iw--target-at-point', or refuse a document."
  (when (org-with-point-at marker (org-before-first-heading-p))
    (org-iw-core-refuse "document targets are not yet supported"))
  marker)

(defun org-iw--problem-types-text (types)
  "Return problem TYPES, a list of symbols, as text for a refusal."
  (if types (mapconcat #'symbol-name types ", ") "unknown"))

(defun org-iw--check-heading (marker scan order queue)
  "Refuse unless the heading at MARKER may join QUEUE, a canonical queue ID.
ORDER is QUEUE's members in SCAN.  Refuse if the heading has an IW_
line for QUEUE but is not in ORDER (the scan excluded it), or if
another heading has its ID.  Return the heading's 1-based position in ORDER
if it is already a member, else nil."
  (org-with-point-at marker
    (let ((id (org-iw-discovery-entry-id))
          (file (org-iw--buffer-truename)))
      (cond
       ((org-iw-discovery-queue-lines queue)
        (if-let* ((index (cl-position (org-iw--find-entry order id file)
                                      order)))
            (1+ index)
          (org-iw-core-refuse
           "heading has IW_%s but it is excluded (%s)" queue
           (org-iw--problem-types-text
            (org-iw-discovery-problem-types scan id)))))
       ((and id (org-iw-discovery-shared-id-p scan id file))
        (org-iw-core-refuse "ID shared with another heading"))))))

;;;###autoload
(defun org-iw-add (queue &optional label)
  "Add the heading at point to QUEUE, at the placement LABEL.
QUEUE is a queue ID in any case; interactively, it is read with
completion over the configured and discovered queues, and a new
one may be typed.  LABEL names one of the queue's placements (see
`org-iw-placements' and `org-iw-queues'); nil means the end.
Interactively, a prefix argument reads LABEL after QUEUE, with
completion over the queue's labels, defaulting to its default.

The heading is the one at or above point, even outside a narrowing;
indirect buffers work.  It is given an ID and a property drawer if
it lacks them, and its file is saved unless its buffer already had
unsaved changes.

A heading already in QUEUE is left alone.  Add refuses, changing
nothing, if the buffer is not a source file or not in Org mode (a
derived mode counts), point is before the first heading, QUEUE is
not a valid ID, LABEL is given and is not one of the queue's labels
or the queue's placements are misconfigured (checked before any
scan), the heading has a property drawer Org does not see, its IW
property for QUEUE was excluded by the scan, another heading has its
ID, there is no room for a rank at the placement, or the write
refuses (the file changed on disk or is not writable, or its buffer
is read-only).

Return the message shown."
  ;; Called for its refusals: a buffer or point Add cannot use fails
  ;; before the prompt.
  (interactive
   (progn (org-iw--heading-or-refuse (org-iw--target-at-point))
          (let ((queue (org-iw--read-queue
                        (org-iw--known-queues (org-iw--scan)))))
            (list queue
                  (and current-prefix-arg
                       (org-iw--read-placement (org-iw--queue-id queue)))))))
  (pcase-let* ((marker (org-iw--heading-or-refuse (org-iw--target-at-point)))
               (queue-id (org-iw--queue-id queue))
               (`(,where . ,placement)
                (if label (org-iw--placement queue-id label) '(nil . end)))
               (scan (org-iw--scan))
               (order (org-iw--order scan queue-id))
               (total (1+ (length order)))
               (name (org-iw--queue-name queue-id)))
    (if-let* ((position (org-iw--check-heading marker scan order queue-id)))
        (org-iw--report scan "Already in %s at %d/%d"
                        name position (length order))
      (pcase (org-iw-core-place order nil queue-id placement)
        (`(no-gap ,_) (org-iw--refuse-no-room
                       (if where (format "at %s" where) "at the end") name))
        (`(moved ,depth ,rank)
         (let ((status (org-iw--save-status
                        (org-iw-write-put-rank marker queue-id rank
                                               :expected :absent
                                               :ensure-id t))))
           (org-iw--report scan "Added to %s at %s%d/%d %s"
                           name (if where (concat where ", ") "")
                           (1+ depth) total status)))))))

;;;; Visit

(defun org-iw--visit (scan entry queue pos total)
  "Show ENTRY of SCAN, POS of TOTAL in QUEUE, and make it the session.
QUEUE is a canonical queue ID.  The entry's buffer is shown in the
selected window, widened only if its narrowing hides the entry, with
point at the entry and the entry revealed.  If the entry cannot be
resolved, refuse before anything changes.  Nothing is written.

Return the message shown."
  (let ((marker (org-iw-discovery-resolve scan (org-iw-entry-id entry)
                                          (org-iw-entry-file entry))))
    (pop-to-buffer-same-window (marker-buffer marker))
    ;; The heading starts at MARKER, so at point-max it is hidden too.
    (unless (and (<= (point-min) marker) (< marker (point-max)))
      (widen))
    (goto-char marker)
    (org-fold-reveal)
    (org-fold-show-entry)
    (org-iw--session-start queue entry)
    (org-iw--report scan "IW %s %d/%d: %s" (org-iw--queue-name queue)
                    pos total (org-iw-entry-title entry))))

(defun org-iw--report-empty (scan queue)
  "Report that QUEUE, a canonical queue ID, is empty, noting SCAN's problems.
Return the message shown."
  (org-iw--report scan "Queue %s is empty" (org-iw--queue-name queue)))

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

;;;; Continue

(defun org-iw--refuse-absent (scan queue id title)
  "Refuse because the entry ID, titled TITLE, is not in QUEUE in SCAN.
QUEUE is a canonical queue ID.  Say whether SCAN excluded ID as a
duplicate."
  (let ((name (org-iw--queue-name queue)))
    (if (org-iw-discovery-excluded-id-p scan id)
        (org-iw-core-refuse "ID %s is duplicated; %s is excluded from queue %s"
                            id title name)
      (org-iw-core-refuse "%s is no longer in queue %s" title name))))

(defun org-iw--session-or-refuse ()
  "Return the session, or refuse if there is none."
  (or org-iw--session
      (org-iw-core-refuse "no session; run org-iw-visit-next first")))

(defun org-iw--put-rank (scan entry queue rank)
  "Write RANK to ENTRY of SCAN in QUEUE, a canonical queue ID.
The write expects ENTRY's scanned rank.  Return the result of
`org-iw-write-put-rank'."
  (org-iw-write-put-rank
   (org-iw-discovery-resolve scan (org-iw-entry-id entry)
                             (org-iw-entry-file entry))
   queue rank :expected (org-iw-core-rank entry queue)))

(defun org-iw--move (scan order entry queue placement where)
  "Move ENTRY, an element of ORDER, to PLACEMENT in QUEUE.
ORDER is QUEUE's members in SCAN, and QUEUE a canonical queue ID.
Return (unchanged DEPTH), writing nothing, or (moved DEPTH STATUS)
after writing ENTRY's new rank against its scanned rank; DEPTH is
ENTRY's index in the new order and STATUS the result of
`org-iw-write-put-rank'.  Refuse if there is no room at PLACEMENT,
WHERE being its text, with its preposition."
  (pcase (org-iw-core-place order entry queue placement)
    (`(no-gap ,_) (org-iw--refuse-no-room where (org-iw--queue-name queue)))
    (`(unchanged ,depth) (list 'unchanged depth))
    (`(moved ,depth ,rank)
     (list 'moved depth (org-iw--put-rank scan entry queue rank)))))

;;;###autoload
(defun org-iw-continue (&optional label)
  "Reinsert the session's entry at the placement LABEL; visit the next.
The entry is the one `org-iw-visit-next' last showed, whatever is at
point or now first in the queue.  LABEL names one of the queue's
placements (see `org-iw-placements' and `org-iw-queues'); nil means
the queue's default.  Interactively, a prefix argument reads LABEL
with completion over the queue's labels.

The entry is given a rank between its new neighbours through its
buffer, which is saved unless it already had unsaved changes.  Then
the first member of the queue is visited and becomes the session's
entry.  At the front, that is the entry itself.

An entry already at its placement is not written, the only entry in
its queue is left alone, and an empty queue is reported; none of
these change anything.  Continue refuses, writing and visiting
nothing, if:

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
                (org-iw--read-placement (org-iw--session-queue session))))))
  (pcase-let* ((session (org-iw--session-or-refuse))
               (queue (org-iw--session-queue session))
               (`(,label . ,placement) (org-iw--placement queue label))
               (id (org-iw--session-id session))
               (scan (org-iw--scan))
               (order (org-iw--order scan queue))
               (total (length order))
               (name (org-iw--queue-name queue)))
    (if (null order)
        (org-iw--report-empty scan queue)
      (let* ((retained (or (org-iw--find-entry order id)
                           (org-iw--refuse-absent
                            scan queue id (org-iw--session-title session))))
             (title (org-iw-entry-title retained)))
        (if (null (cdr order))
            (org-iw--report scan "%s is the only entry in queue %s"
                            title name)
          (pcase-let
              ((`(,text . ,new-order)
                (pcase (org-iw--move scan order retained queue placement
                                     (format "at %s" label))
                  (`(unchanged ,depth)
                   (cons (format "%s already at %s, %d/%d"
                                 title label (1+ depth) total)
                         order))
                  (`(moved ,depth ,status)
                   (cons (format "Moved %s to %s, %d/%d %s"
                                 title label (1+ depth) total
                                 (org-iw--save-status status))
                         (org-iw-core-reorder order retained depth))))))
            (org-iw--visit scan (car new-order) queue 1 total)
            (org-iw--report scan "%s. Now 1/%d: %s" text total
                            (org-iw-entry-title (car new-order)))))))))

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
