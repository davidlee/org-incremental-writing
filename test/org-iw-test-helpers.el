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
;; declared with `org-iw-test-make-symlink'.

;;; Code:

(require 'ert)
(require 'seq)
(require 'subr-x)
(require 'org-id)
(require 'org-iw)

(defvar org-iw-test-dir nil
  "Truename of the current corpus directory, as a directory name.")

(defvar org-iw-test--extras nil
  "Corpus paths the current test created on purpose.")

(defvar org-iw-test--modes nil
  "Alist (PATH . MODES) of file modes to restore after the test.")

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

(defun org-iw-test--release ()
  "Discard edits to corpus buffers, kill them and restore file modes."
  (dolist (buffer (seq-filter #'org-iw-test--corpus-buffer-p (buffer-list)))
    (with-current-buffer buffer
      (set-buffer-modified-p nil))
    (kill-buffer buffer))
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
         (ids-file (make-temp-file "org-iw-test-ids-"))
         (org-iw-sources (list org-iw-test-dir))
         (org-iw-exclude-regexp nil)
         (org-iw-queues nil)
         (org-id-locations-file ids-file)
         (org-id-locations nil)
         (org-id-track-globally nil))
    (unwind-protect
        (progn
          (pcase-dolist (`(,name . ,content) files)
            (org-iw-test--write name content))
          (let ((before (org-iw-test--listing))
                (completed nil))
            (unwind-protect
                (prog1 (funcall body)
                  (setq completed t))
              (org-iw-test--release)
              (when-let* ((violation (org-iw-test--i8-violation before)))
                ;; Never replace BODY's own error.
                (if completed
                    (ert-fail violation)
                  (message "Also violated: %S" violation))))))
      (delete-directory org-iw-test-dir t)
      (delete-file ids-file))))

(defmacro org-iw-test-with-corpus (files &rest body)
  "Run BODY over a temporary corpus holding FILES.
FILES is evaluated to an alist (NAME . CONTENT); NAME is relative to
the corpus and may include subdirectories.

BODY runs with `org-iw-test-dir' naming the corpus, `org-iw-sources'
bound to it, `org-iw-exclude-regexp' and `org-iw-queues' nil, and
org-id isolated: `org-id-locations-file' is a temporary file outside
the corpus, `org-id-locations' nil and `org-id-track-globally' nil.

Afterwards, even if BODY fails, the corpus buffers are killed with
their edits discarded and file modes changed through
`org-iw-test-set-modes' are restored.  Then I8 is asserted: the
corpus listing must equal the one before BODY, apart from *~ backups
and paths declared by `org-iw-test-make-symlink'.  A violation fails
the test, unless BODY already failed.  Finally the corpus is deleted."
  (declare (indent 1) (debug t))
  `(org-iw-test--call-with-corpus ,files (lambda () ,@body)))

(defun org-iw-test-make-symlink (target name)
  "Make corpus path NAME a symbolic link to TARGET; return its path.
NAME is declared as an expected extra for the I8 check."
  (let ((path (org-iw-test-path name)))
    (make-symbolic-link target path)
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

(provide 'org-iw-test-helpers)
;;; org-iw-test-helpers.el ends here
