;;; org-iw-test-helpers.el --- Test fixture for org-iw  -*- lexical-binding: t; -*-

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

;; The one corpus fixture for org-iw tests.  `org-iw-test-with-corpus'
;; runs its body over a temporary directory of Org files, with the
;; org-iw options and org-id's global state isolated.  Afterwards it
;; kills the corpus buffers (releasing lock files) and asserts I8: no
;; file appeared or vanished apart from backups and paths the test
;; declared with `org-iw-test-make-symlink' or `org-iw-test-make-fifo'.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'seq)
(require 'subr-x)
(require 'org)
(require 'org-id)
(require 'org-iw)
(require 'org-iw-discovery)

(defvar org-iw-test-dir nil
  "Truename of the current corpus directory, as a directory name.")

(defvar org-iw-test--extras nil
  "Corpus paths the current test created on purpose.")

(defvar org-iw-test--modes nil
  "Alist (PATH . MODES) of file modes to restore after the test.")

(defvar org-iw-test--outside-views nil
  "The queue views that existed when the current fixture started.")

(defun org-iw-test-path (name)
  "Return the absolute name of NAME in the corpus."
  (expand-file-name name org-iw-test-dir))

(defun org-iw-test--write (name content)
  "Create corpus file NAME holding CONTENT, making its directory."
  (let ((path (org-iw-test-path name)))
    (make-directory (file-name-directory path) t)
    (with-temp-file path
      (insert content))))

(defun org-iw-test--listing ()
  "Return the corpus's relative file names, sorted, ignoring backups."
  (sort (seq-remove (lambda (name) (string-suffix-p "~" name))
                    (mapcar (lambda (path)
                              (file-relative-name path org-iw-test-dir))
                            (directory-files-recursively
                             org-iw-test-dir "" t)))
        #'string<))

(defun org-iw-test--corpus-buffer-p (buffer)
  "Return non-nil if BUFFER visits a file in the corpus."
  (when-let* ((name (buffer-file-name buffer)))
    (seq-some (lambda (file) (string-prefix-p org-iw-test-dir file))
              (list name (file-truename name)))))

(defun org-iw-test--view-buffer-p (buffer)
  "Return non-nil if BUFFER is an org-iw queue view."
  (provided-mode-derived-p (buffer-local-value 'major-mode buffer)
                           'org-iw-view-mode))

(defun org-iw-test--spare-outside-view (view)
  "Return VIEW, found by `org-iw--view-buffer', or fail the test.
A view made outside the fixture fails it, before the view is redrawn."
  (when (memq view org-iw-test--outside-views)
    (ert-fail (list "Queue view made outside the test" (buffer-name view))))
  view)

(defun org-iw-test--release ()
  "Discard edits to corpus buffers, kill them and restore file modes.
Kill the queue views made in the test too: they have no file, and a
view left behind would be found again by its queue ID."
  (dolist (buffer (seq-filter #'org-iw-test--corpus-buffer-p (buffer-list)))
    (with-current-buffer buffer
      (set-buffer-modified-p nil))
    (kill-buffer buffer))
  (mapc #'kill-buffer
        (seq-difference (seq-filter #'org-iw-test--view-buffer-p (buffer-list))
                        org-iw-test--outside-views))
  (pcase-dolist (`(,path . ,modes) org-iw-test--modes)
    (set-file-modes path modes)))

(defun org-iw-test--i8-violation (before)
  "Return a description of any I8 violation since listing BEFORE, or nil."
  (let ((expected (sort (seq-uniq (append before org-iw-test--extras))
                        #'string<))
        (after (org-iw-test--listing)))
    (unless (equal after expected)
      (list 'org-iw-i8
            :created (seq-difference after expected)
            :deleted (seq-difference expected after)))))

(defun org-iw-test--call-with-corpus (files body)
  "Call BODY with no arguments over a corpus holding FILES.
See `org-iw-test-with-corpus'."
  (let* ((org-iw-test-dir (file-name-as-directory
                           (file-truename
                            (make-temp-file "org-iw-test-" t))))
         (org-iw-test--extras nil)
         (org-iw-test--modes nil)
         (org-iw-test--outside-views
          (seq-filter #'org-iw-test--view-buffer-p (buffer-list)))
         (ids-file (make-temp-file "org-iw-test-ids-"))
         (org-iw-sources (list org-iw-test-dir))
         (org-iw-exclude-regexp nil)
         (org-iw-queues nil)
         (org-iw--session nil)
         (global-mode-string nil)
         (org-id-locations-file ids-file)
         (org-id-locations nil)
         (org-id-track-globally nil))
    (advice-add 'org-iw--view-buffer :filter-return
                #'org-iw-test--spare-outside-view)
    (unwind-protect
        (progn
          (pcase-dolist (`(,name . ,content) files)
            (org-iw-test--write name content))
          (let ((before (org-iw-test--listing))
                (completed nil))
            (unwind-protect
                (prog1 (save-window-excursion (funcall body))
                  (setq completed t))
              (org-iw-test--release)
              (when-let* ((violation (org-iw-test--i8-violation before)))
                ;; Never replace BODY's own error.
                (if completed
                    (ert-fail violation)
                  (message "Also violated: %S" violation))))))
      (advice-remove 'org-iw--view-buffer #'org-iw-test--spare-outside-view)
      (delete-directory org-iw-test-dir t)
      (delete-file ids-file))))

(defmacro org-iw-test-with-corpus (files &rest body)
  "Run BODY over a temporary corpus holding FILES.
FILES is evaluated to an alist (NAME . CONTENT); NAME is relative to
the corpus and may include subdirectories.

BODY runs with `org-iw-test-dir' naming the corpus, `org-iw-sources'
bound to it, `org-iw-exclude-regexp' and `org-iw-queues' nil, no
session (`org-iw--session' and `global-mode-string' nil), and org-id
isolated: `org-id-locations-file' is a temporary file outside the
corpus, `org-id-locations' nil and `org-id-track-globally' nil.

BODY runs inside `save-window-excursion'.  A queue view that existed
before BODY is spared: BODY fails if it would show that view's queue.
Afterwards, even if BODY fails, the window configuration is restored,
the corpus buffers and BODY's queue views are killed, the corpus
buffers' edits discarded, and file modes changed through
`org-iw-test-set-modes' are restored.  Then I8
is asserted: the corpus listing must equal the one before BODY, apart
from *~ backups and paths declared by `org-iw-test-make-symlink' or
`org-iw-test-make-fifo'.  A violation fails the test, unless BODY
already failed.  Finally the corpus is deleted."
  (declare (indent 1) (debug t))
  `(org-iw-test--call-with-corpus ,files (lambda () ,@body)))

(defun org-iw-test-make-symlink (target name)
  "Make corpus path NAME a symbolic link to TARGET; return its path.
NAME is declared as an expected extra for the I8 check."
  (let ((path (org-iw-test-path name)))
    (make-symbolic-link target path)
    (push name org-iw-test--extras)
    path))

(defun org-iw-test-make-fifo (name)
  "Make corpus path NAME a named pipe; return its path.
Skip the test where `mkfifo' is unavailable.  NAME is declared as an
expected extra for the I8 check."
  (unless (executable-find "mkfifo")
    (ert-skip "mkfifo is unavailable"))
  (let ((path (org-iw-test-path name)))
    (should (zerop (call-process "mkfifo" nil nil nil path)))
    (push name org-iw-test--extras)
    path))

(defun org-iw-test-set-modes (name modes)
  "Set the file MODES of corpus path NAME until the fixture ends."
  (let ((path (org-iw-test-path name)))
    (push (cons path (file-modes path 'nofollow)) org-iw-test--modes)
    (set-file-modes path modes)))

(defun org-iw-test-file-string (name)
  "Return the contents on disk of corpus file NAME."
  (with-temp-buffer
    (insert-file-contents (org-iw-test-path name))
    (buffer-string)))

(defun org-iw-test-visit (name)
  "Return a buffer visiting corpus file NAME.
The fixture kills it at the end of the test."
  (find-file-noselect (org-iw-test-path name)))

(defun org-iw-test-rewrite-behind (name text)
  "Replace corpus file NAME's contents with TEXT behind Emacs's back.
Its modification time is moved an hour back, so that clock
granularity cannot hide the change."
  (let ((path (org-iw-test-path name)))
    (with-temp-file path
      (insert text))
    (set-file-times path (time-subtract nil 3600))))

(defun org-iw-test-changed-lines (before after)
  "Return the lines that differ between strings BEFORE and AFTER.
The result is (REMOVED . ADDED): the lines of BEFORE and of AFTER
left once their common leading and trailing lines are dropped.  One
changed line gives one line on each side; separate changes are
reported together with the lines between them."
  (let ((old (split-string before "\n"))
        (new (split-string after "\n")))
    (while (and old new (equal (car old) (car new)))
      (setq old (cdr old) new (cdr new)))
    (setq old (reverse old) new (reverse new))
    (while (and old new (equal (car old) (car new)))
      (setq old (cdr old) new (cdr new)))
    (cons (nreverse old) (nreverse new))))

;;;; Corpus text builders

(defun org-iw-test-org (&rest lines)
  "Return LINES as Org text, each ending in a newline."
  (mapconcat (lambda (line) (concat line "\n")) lines ""))

(defun org-iw-test-heading (title id &rest properties)
  "Return a heading TITLE with a drawer holding ID and PROPERTIES.
ID nil omits the ID line; PROPERTIES are whole drawer lines."
  (apply #'org-iw-test-org
         (concat "* " title) ":PROPERTIES:"
         (append (and id (list (concat ":ID: " id)))
                 properties
                 '(":END:"))))

(declare-function denote-file-has-denoted-filename-p "denote" (file))

(defun org-iw-test-denote-file (identifier content &optional title)
  "Return a corpus file (NAME . CONTENT), NAME in Denote's scheme.
NAME is made of the Denote IDENTIFIER, \"--\", TITLE (default
\"note\") and \".org\".  Skip
the test unless Denote loads, and fail it unless Denote accepts NAME,
so a typo cannot quietly turn a test of Denote identity into a test
of a plain file.  Use it in the FILES of `org-iw-test-with-corpus'."
  (unless (require 'denote nil t)
    (ert-skip "Denote is unavailable"))
  (let ((name (format "%s--%s.org" identifier (or title "note"))))
    (should (denote-file-has-denoted-filename-p name))
    (cons name content)))

(defmacro org-iw-test-without-feature (feature &rest body)
  "Run BODY with FEATURE absent from `features', then restore it.
`features' is not special in lexical code, so `let' would bind it
lexically and `featurep' would not see the binding: it is bound
dynamically with `cl-progv'."
  (declare (indent 1) (debug t))
  `(cl-progv '(features) (list (remq ,feature features))
     ,@body))

(defmacro org-iw-test-without-denote (&rest body)
  "Run BODY as if Denote were not installed.
`denote' is removed from `features' and the one attempt to load
Denote is marked as made.  BODY reaches discovery's private
`org-iw-discovery--denote-tried' because Denote's availability is
session state, which a test must isolate.  See
`org-iw-test-without-feature' for how `features' is bound."
  (declare (indent 0) (debug t))
  `(org-iw-test-without-feature 'denote
     (let ((org-iw-discovery--denote-tried t))
       ,@body)))

;;;; Buffers, markers and snapshots

(defun org-iw-test-marker (name title)
  "Return a marker at the heading TITLE in corpus file NAME.
The file is visited first; the marker is in its buffer."
  (with-current-buffer (org-iw-test-visit name)
    (org-with-wide-buffer
     (goto-char (point-min))
     (let ((case-fold-search nil))
       (re-search-forward (concat "^\\* " (regexp-quote title) "$")))
     (copy-marker (line-beginning-position)))))

(defun org-iw-test-base (marker)
  "Return the base buffer of MARKER's buffer.
Deliberately independent of `org-iw-discovery-base-buffer': tests use
it as an oracle."
  (let ((buffer (marker-buffer marker)))
    (or (buffer-base-buffer buffer) buffer)))

(defun org-iw-test-text (marker)
  "Return the whole text of MARKER's buffer, ignoring narrowing."
  (with-current-buffer (marker-buffer marker)
    (org-with-wide-buffer
     (buffer-substring-no-properties (point-min) (point-max)))))

(defun org-iw-test-snapshot (marker)
  "Return (TEXT MODIFIED DISK) for the base buffer of MARKER's buffer.
The buffer is not visited again, so a file changed on disk cannot
prompt."
  (let ((base (org-iw-test-base marker)))
    (list (org-iw-test-text marker)
          (buffer-modified-p base)
          (org-iw-test-file-string (buffer-file-name base)))))

(defun org-iw-test-state ()
  "Return the state of the corpus files and the buffers visiting them.
The result lists (FILE . CONTENTS) for every regular corpus file, then
\(BUFFER-NAME TEXT MODIFIED) for every live buffer visiting one, so
two states are `equal' only if nothing was written, edited or
visited.  No buffer is visited to take it."
  (append
   (mapcar (lambda (file) (cons file (org-iw-test-file-string file)))
           (seq-filter #'file-regular-p
                       (directory-files-recursively org-iw-test-dir "")))
   (sort (mapcar (lambda (buffer)
                   (with-current-buffer buffer
                     (list (buffer-name)
                           (org-with-wide-buffer
                            (buffer-substring-no-properties (point-min)
                                                            (point-max)))
                           (buffer-modified-p))))
                 (seq-filter #'org-iw-test--corpus-buffer-p (buffer-list)))
         (lambda (a b) (string< (car a) (car b))))))

(defun org-iw-test-edit-elsewhere (marker)
  "Leave unsaved text at the end of MARKER's buffer, as a user would."
  (with-current-buffer (marker-buffer marker)
    (save-excursion
      (goto-char (point-max))
      (insert "User edit.\n"))))

(defun org-iw-test-call-with-indirect (marker fn)
  "Call FN with MARKER's position in a cloned indirect buffer.
The indirect buffer is made with `make-indirect-buffer' and CLONE t,
as `clone-indirect-buffer' does, and killed afterwards."
  (let ((indirect (make-indirect-buffer
                   (marker-buffer marker)
                   (generate-new-buffer-name "org-iw-test-indirect")
                   t)))
    (unwind-protect
        (with-current-buffer indirect
          (should-not buffer-file-name)
          (funcall fn (copy-marker (marker-position marker))))
      (kill-buffer indirect))))

(defun org-iw-test-should-add-drawer (text marker anchor)
  "Assert the saved file of MARKER is TEXT plus one new drawer.
The drawer must directly follow the line ANCHOR and hold exactly one
new ID, unique in the file, and IW_ESSAYS at 1024."
  (let ((disk (org-iw-test-file-string
               (buffer-file-name (org-iw-test-base marker)))))
    (should (string-search (concat anchor "\n:PROPERTIES:\n") disk))
    (pcase-let ((`(,removed . ,added) (org-iw-test-changed-lines text disk)))
      (should-not removed)
      (should (equal (length added) 4))
      (should (equal (nth 0 added) ":PROPERTIES:"))
      (should (string-match "\\`:ID: +\\([^ ]+\\)\\'" (nth 1 added)))
      (let ((id (match-string 1 (nth 1 added))))
        (with-current-buffer (marker-buffer marker)
          (should (equal (org-iw-discovery-id-count
                          id (buffer-file-name (org-iw-test-base marker)))
                         1))))
      (should (equal (nth 2 added) ":IW_ESSAYS: 1024"))
      (should (equal (nth 3 added) ":END:")))))

(defmacro org-iw-test-unless-root (&rest body)
  "Run BODY, skipping the test when file modes cannot deny access."
  (declare (indent 0) (debug t))
  `(progn
     (skip-unless (not (zerop (user-uid))))
     ,@body))

(provide 'org-iw-test-helpers)
;;; org-iw-test-helpers.el ends here
