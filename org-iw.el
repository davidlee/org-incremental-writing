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

(defcustom org-iw-queues nil
  "Configured queues, as an alist of (QUEUE-ID . PLIST).

QUEUE-ID is a string of letters, digits and hyphens, compared
case-insensitively; entries join the queue through an IW_QUEUE-ID
property.  PLIST supports :name, the display name shown in prompts
and the mode line.

Queues found in source files but not listed here can still be
chosen; they are shown by their ID."
  :type '(alist :key-type (string :tag "Queue ID")
                :value-type (plist :tag "Options"
                                   :options ((:name string))))
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

(defun org-iw--configured-queues ()
  "Return `org-iw-queues' as an alist (QUEUE . PLIST), QUEUE canonical.
Entries whose key is not a valid queue ID are left out."
  (seq-keep (lambda (config)
              (when-let* ((queue (org-iw-core-queue-id (car-safe config))))
                (cons queue (cdr config))))
            org-iw-queues))

(defun org-iw--configured-name (queue)
  "Return the :name configured for QUEUE, a canonical queue ID, or nil."
  (plist-get (alist-get queue (org-iw--configured-queues) nil nil #'equal)
             :name))

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

(defun org-iw--append-rank (order queue)
  "Return the rank after ORDER, members of QUEUE; refuse at the limit."
  (or (org-iw-core-rank-at order queue (length order))
      (org-iw-core-refuse "rank limit; redistribution needed")))

(defun org-iw--read-queue (scan)
  "Prompt for a queue ID and return the string entered, unchecked.
Completion offers the configured queues with valid IDs and those
found by SCAN, annotated with their configured names.  Any other ID
may be typed."
  (let ((completion-extra-properties
         (list :annotation-function
               (lambda (queue)
                 (when-let* ((name (org-iw--configured-name queue)))
                   (concat " " name))))))
    (completing-read
     "Queue: "
     (sort (seq-uniq
            (append (mapcar #'car (org-iw--configured-queues))
                    (org-iw-core-queue-ids (org-iw-scan-entries scan))))
           #'string<))))

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

;;;; Add

(defun org-iw--add-target ()
  "Return a marker at the heading to add, or refuse.
The heading is the one at or above point, ignoring narrowing, in the
current buffer, which must visit a source file and be in Org mode."
  (unless (org-iw--source-file-p)
    (org-iw-core-refuse "%s is not under org-iw-sources" (buffer-name)))
  (org-iw-discovery-require-org-mode (org-iw--buffer-truename))
  (org-with-wide-buffer
   (when (org-before-first-heading-p)
     (org-iw-core-refuse "document targets are not yet supported"))
   (org-back-to-heading t)
   (point-marker)))

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
        (if-let* ((index (cl-position-if
                          (lambda (entry)
                            (and (equal (org-iw-entry-id entry) id)
                                 (equal (org-iw-entry-file entry) file)))
                          order)))
            (1+ index)
          (org-iw-core-refuse
           "heading has IW_%s but it is excluded (%s)" queue
           (org-iw--problem-types-text
            (org-iw-discovery-problem-types scan id)))))
       ((and id (org-iw-discovery-shared-id-p scan id file))
        (org-iw-core-refuse "ID shared with another heading"))))))

;;;###autoload
(defun org-iw-add (queue)
  "Add the heading at point to the end of QUEUE.
QUEUE is a queue ID in any case; interactively, it is read with
completion over the configured and discovered queues, and a new
one may be typed.  The heading is the one at or above point, even
outside a narrowing; indirect buffers work.  It is given an ID and
a property drawer if it lacks them, and its file is saved unless
its buffer already had unsaved changes.

A heading already in QUEUE is left alone.  Add refuses, changing
nothing, if the buffer is not a source file or not in Org mode (a
derived mode counts), point is before the first heading, QUEUE is
not a valid ID, the heading has a property drawer Org does not see,
its IW property for QUEUE was excluded by the scan, another heading
has its ID, or QUEUE has no rank left.

Return the message shown."
  ;; Called for its refusals: a buffer or point Add cannot use fails
  ;; before the prompt.
  (interactive (progn (org-iw--add-target)
                      (list (org-iw--read-queue (org-iw--scan)))))
  (let* ((marker (org-iw--add-target))
         (queue-id (org-iw--queue-id queue))
         (scan (org-iw--scan))
         (order (org-iw--order scan queue-id))
         (name (org-iw--queue-name queue-id)))
    (if-let* ((position (org-iw--check-heading marker scan order queue-id)))
        (org-iw--report scan "Already in %s at %d/%d"
                        name position (length order))
      (let* ((rank (org-iw--append-rank order queue-id))
             (status (org-iw-write-put-rank marker queue-id rank
                                            :expected :absent :ensure-id t))
             (total (1+ (length order))))
        (org-iw--report scan "Added to %s at %d/%d %s"
                        name total total (org-iw--save-status status))))))

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
  (interactive (list (if (and org-iw--session (not current-prefix-arg))
                         (org-iw--session-queue org-iw--session)
                       (org-iw--read-queue (org-iw--scan)))))
  (let* ((queue-id (org-iw--queue-id queue))
         (scan (org-iw--scan))
         (order (org-iw--order scan queue-id)))
    (if order
        (org-iw--visit scan (car order) queue-id 1 (length order))
      (org-iw--report scan "Queue %s is empty" (org-iw--queue-name queue-id)))))

;;;; Continue to End

(defun org-iw--refuse-absent (scan session)
  "Refuse because SESSION's entry is not in its queue in SCAN.
Say whether SCAN excluded the entry's ID as a duplicate."
  (let ((id (org-iw--session-id session))
        (title (org-iw--session-title session)))
    (if (org-iw-discovery-excluded-id-p scan id)
        (org-iw-core-refuse "ID %s is duplicated; %s not moved" id title)
      (org-iw-core-refuse
       "%s is no longer in queue %s" title
       (org-iw--queue-name (org-iw--session-queue session))))))

(defun org-iw--move-to-end (scan entry rest queue)
  "Rank ENTRY of SCAN after REST, the other members of QUEUE.
Return the result of `org-iw-write-put-rank'."
  (let ((rank (org-iw--append-rank rest queue))
        (marker (org-iw-discovery-resolve scan (org-iw-entry-id entry)
                                          (org-iw-entry-file entry))))
    (org-iw-write-put-rank marker queue rank
                           :expected (org-iw-core-rank entry queue))))

;;;###autoload
(defun org-iw-continue ()
  "Move the session's entry to the end of its queue; visit the next.
The entry is the one `org-iw-visit-next' last showed, whatever is at
point or now first in the queue.  It is ranked after the queue's
other members through its buffer, which is saved unless it already
had unsaved changes.  Then the first of the other members is visited
and becomes the session's entry.

An entry already last is not written, and the only entry in its
queue is left alone.  Continue refuses, writing and visiting nothing,
if there is no session, the entry has left its queue or its ID is
duplicated, the queue has no rank left, or the write refuses (the
file changed on disk or is not writable, or the rank changed since
the scan).

Return the message shown."
  (interactive)
  (unless org-iw--session
    (org-iw-core-refuse "no session; run org-iw-visit-next first"))
  (let* ((queue (org-iw--session-queue org-iw--session))
         (id (org-iw--session-id org-iw--session))
         (scan (org-iw--scan))
         (order (org-iw--order scan queue))
         (retained (or (seq-find (lambda (entry)
                                   (equal (org-iw-entry-id entry) id))
                                 order)
                       (org-iw--refuse-absent scan org-iw--session)))
         (rest (remq retained order))
         (title (org-iw-entry-title retained)))
    (if (null rest)
        (org-iw--report scan "%s is the only entry in queue %s"
                        title (org-iw--queue-name queue))
      (let ((save-status
             (unless (eq retained (car (last order)))
               (org-iw--save-status
                (org-iw--move-to-end scan retained rest queue))))
            (next (car rest)))
        (org-iw--visit scan next queue 1 (length order))
        (org-iw--report scan "%s. Now 1/%d: %s"
                        (if save-status
                            (format "Moved %s to end %s" title save-status)
                          (format "%s already at end" title))
                        (length order) (org-iw-entry-title next))))))

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
