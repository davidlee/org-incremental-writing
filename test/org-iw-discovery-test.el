;;; org-iw-discovery-test.el --- Tests for org-iw-discovery  -*- lexical-binding: t; -*-

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

;; ERT tests for file selection and the discovery scan, and for the
;; corpus fixture they run on.

;;; Code:

(require 'ert)
(require 'seq)
(require 'org-iw-test-helpers)
(require 'org-iw-discovery)

;;;; Helpers

(defun org-iw-discovery-test--relative (file)
  "Return FILE relative to the corpus."
  (file-relative-name file org-iw-test-dir))

(defun org-iw-discovery-test--files ()
  "Return the corpus-relative files selected by the user options."
  (mapcar #'org-iw-discovery-test--relative
          (org-iw-discovery-files org-iw-sources org-iw-exclude-regexp)))

(defun org-iw-discovery-test--scan ()
  "Scan the files selected by the user options."
  (org-iw-discovery-scan
   (org-iw-discovery-files org-iw-sources org-iw-exclude-regexp)))

(defun org-iw-discovery-test--entries (scan)
  "Return the entries of SCAN as (ID . MEMBERSHIPS)."
  (mapcar (lambda (entry)
            (cons (org-iw-entry-id entry) (org-iw-entry-memberships entry)))
          (org-iw-scan-entries scan)))

(defun org-iw-discovery-test--problems (scan)
  "Return the problems of SCAN as (TYPE RELATIVE-FILE ID)."
  (mapcar (lambda (problem)
            (list (org-iw-problem-type problem)
                  (org-iw-discovery-test--relative
                   (org-iw-problem-file problem))
                  (org-iw-problem-id problem)))
          (org-iw-scan-problems scan)))

(defun org-iw-discovery-test--check (files entries problems)
  "Scan a corpus of FILES; assert its ENTRIES and PROBLEMS.
ENTRIES and PROBLEMS are as returned by
`org-iw-discovery-test--entries' and `org-iw-discovery-test--problems'."
  (org-iw-test-with-corpus files
    (let ((scan (org-iw-discovery-test--scan)))
      (should (equal (org-iw-discovery-test--entries scan) entries))
      (should (equal (org-iw-discovery-test--problems scan) problems)))))

(defconst org-iw-discovery-test--member
  (org-iw-test-heading "Member" "m1" ":IW_ESSAYS: 1024")
  "Text of a file holding one valid member of ESSAYS.")

;;;; Fixture (I8, org-id isolation)

(ert-deftest org-iw-discovery-test-fixture-isolates ()
  "The fixture binds the options and org-id state, then cleans up."
  (let (dir ids-file)
    (org-iw-test-with-corpus '(("sub/a.org" . "* A\n"))
      (setq dir org-iw-test-dir
            ids-file org-id-locations-file)
      (should (equal org-iw-sources (list org-iw-test-dir)))
      (should-not org-iw-queues)
      (should-not org-iw-exclude-regexp)
      (should-not org-id-locations)
      (should-not org-id-track-globally)
      (should-not (string-prefix-p dir ids-file))
      (should (equal (org-iw-test-file-string "sub/a.org") "* A\n")))
    (should-not (file-exists-p dir))
    (should-not (file-exists-p ids-file))))

(ert-deftest org-iw-discovery-test-fixture-releases-lock-files ()
  "Corpus buffers are killed, releasing a modified buffer's lock file."
  (let (buffer)
    (org-iw-test-with-corpus '(("a.org" . "* A\n"))
      (setq buffer (org-iw-test-visit "a.org"))
      (with-current-buffer buffer
        (insert "x"))
      (should (file-symlink-p (org-iw-test-path ".#a.org"))))
    (should-not (buffer-live-p buffer))))

(ert-deftest org-iw-discovery-test-fixture-i8-fails-on-stray-file ()
  "An undeclared new file fails the test; a declared symlink does not."
  (let ((err (should-error
              (org-iw-test-with-corpus '(("a.org" . ""))
                (write-region "" nil (org-iw-test-path "stray.org")))
              :type 'ert-test-failed)))
    (should (equal (plist-get (cdr (cadr err)) :created) '("stray.org"))))
  (org-iw-test-with-corpus '(("a.org" . ""))
    (org-iw-test-make-symlink "a.org" "alias.org")))

(ert-deftest org-iw-discovery-test-fixture-keeps-body-error ()
  "A failing body keeps its own error, and the corpus is still deleted."
  (let* ((dir nil)
         (err (should-error
               (org-iw-test-with-corpus '(("a.org" . ""))
                 (setq dir org-iw-test-dir)
                 (write-region "" nil (org-iw-test-path "stray.org"))
                 (error "Boom")))))
    (should (equal err '(error "Boom")))
    (should-not (file-exists-p dir))))

(ert-deftest org-iw-discovery-test-fixture-changed-lines ()
  "Changed lines are those left between the common head and tail."
  (should (equal (org-iw-test-changed-lines "a\nb\nc\n" "a\nB\nc\n")
                 '(("b") . ("B"))))
  (should (equal (org-iw-test-changed-lines "a\nc\n" "a\nb\nc\n")
                 '(nil . ("b"))))
  (should (equal (org-iw-test-changed-lines "a\nb\nc\nd\n" "A\nb\nc\nD\n")
                 '(("a" "b" "c" "d") . ("A" "b" "c" "D"))))
  (should (equal (org-iw-test-changed-lines "same\n" "same\n")
                 '(nil . nil))))

(ert-deftest org-iw-discovery-test-fixture-snapshot-detects-change ()
  "A snapshot differs after a buffer edit, a modified flag or a disk change."
  (let ((files '(("a.org" . "* A\n"))))
    (org-iw-test-with-corpus files
      (let* ((marker (org-iw-test-marker "a.org" "A"))
             (before (org-iw-test-snapshot marker)))
        (should (consp before))
        (should (equal (org-iw-test-snapshot marker) before))))
    (org-iw-test-with-corpus files
      (let* ((marker (org-iw-test-marker "a.org" "A"))
             (before (org-iw-test-snapshot marker)))
        (org-iw-test-edit-elsewhere marker)
        (should-not (equal (org-iw-test-snapshot marker) before))))
    (org-iw-test-with-corpus files
      (let* ((marker (org-iw-test-marker "a.org" "A"))
             (before (org-iw-test-snapshot marker)))
        (with-current-buffer (org-iw-test-base marker)
          (set-buffer-modified-p t))
        (should (equal (org-iw-test-text marker) (car before)))
        (should-not (equal (org-iw-test-snapshot marker) before))))
    (org-iw-test-with-corpus files
      (let* ((marker (org-iw-test-marker "a.org" "A"))
             (before (org-iw-test-snapshot marker)))
        (org-iw-test-rewrite-behind "a.org" "* A\nbehind\n")
        (should (equal (org-iw-test-text marker) (car before)))
        (should-not (equal (org-iw-test-snapshot marker) before))))))

(ert-deftest org-iw-discovery-test-fixture-state-detects-change ()
  "A state differs after an edit, a flag, a disk change, a visit or a new file."
  (let ((files '(("a.org" . "* A\n") ("b.org" . "* B\n"))))
    (org-iw-test-with-corpus files
      (let* ((marker (org-iw-test-marker "a.org" "A"))
             (before (org-iw-test-state)))
        (should before)
        (should (equal (org-iw-test-state) before))
        (org-iw-test-edit-elsewhere marker)
        (should-not (equal (org-iw-test-state) before))))
    (org-iw-test-with-corpus files
      (let* ((marker (org-iw-test-marker "a.org" "A"))
             (before (org-iw-test-state)))
        (with-current-buffer (org-iw-test-base marker)
          (set-buffer-modified-p t))
        (should-not (equal (org-iw-test-state) before))))
    (org-iw-test-with-corpus files
      (let ((before (org-iw-test-state)))
        (org-iw-test-rewrite-behind "b.org" "* B\nbehind\n")
        (should-not (equal (org-iw-test-state) before))))
    (org-iw-test-with-corpus files
      (let ((before (org-iw-test-state)))
        (org-iw-test-visit "b.org")
        (should-not (equal (org-iw-test-state) before))))
    (org-iw-test-with-corpus files
      (let ((before (org-iw-test-state)))
        (org-iw-test--write "c.org" "* C\n")
        (push "c.org" org-iw-test--extras)
        (should-not (equal (org-iw-test-state) before))))))

;;;; File selection (`org-iw-discovery-files')

(ert-deftest org-iw-discovery-test-files-directory-rules ()
  "Directory search skips hidden, symlinked and irregular names."
  (org-iw-test-with-corpus '(("a.org" . "") ("sub/b.org" . "")
                             ("sub/notes.txt" . "") (".hidden/c.org" . "")
                             ("dir.org/d.org" . "") (".#e.org" . ""))
    ;; `org-iw-test-make-symlink' is `make-symbolic-link', declared for I8.
    ;; Following linkdir would reach .hidden/c.org.
    (org-iw-test-make-symlink ".hidden" "linkdir")
    (org-iw-test-make-symlink "/nonexistent/x.org" "dangling.org")
    (org-iw-test-make-symlink "user@host.1:2" ".#a.org")
    ;; The .# test is on the link's own name, not its truename.
    (org-iw-test-make-symlink "sub/notes.txt" ".#n.org")
    (should (equal (org-iw-discovery-test--files)
                   '("a.org" "dir.org/d.org" "sub/b.org")))))

(ert-deftest org-iw-discovery-test-files-skip-fifo ()
  "A named pipe named *.org is not selected, so a scan cannot block on it."
  (org-iw-test-with-corpus '(("a.org" . ""))
    (org-iw-test-make-fifo "f.org")
    (should (equal (org-iw-discovery-test--files) '("a.org")))))

(ert-deftest org-iw-discovery-test-files-hidden-root ()
  "A source directory that is itself hidden is still searched."
  (org-iw-test-with-corpus '((".notes/a.org" . "") (".notes/.git/b.org" . ""))
    (let ((org-iw-sources (list (org-iw-test-path ".notes"))))
      (should (equal (org-iw-discovery-test--files) '(".notes/a.org"))))))

(ert-deftest org-iw-discovery-test-files-deduplicated ()
  "Overlapping sources and symlinks give each truename once, sorted."
  (org-iw-test-with-corpus '(("a.org" . "") ("sub/b.org" . ""))
    (org-iw-test-make-symlink "sub/b.org" "alias.org")
    (let ((org-iw-sources (list (org-iw-test-path "sub")
                                org-iw-test-dir
                                (org-iw-test-path "a.org")
                                (org-iw-test-path "alias.org"))))
      (should (equal (org-iw-discovery-test--files) '("a.org" "sub/b.org"))))))

(ert-deftest org-iw-discovery-test-files-exclude-regexp ()
  "`org-iw-exclude-regexp' matches truenames, case-sensitively."
  (org-iw-test-with-corpus '(("archive/old.org" . "") ("ARCHIVE/up.org" . "")
                             ("new.org" . ""))
    (org-iw-test-make-symlink "archive/old.org" "keep.org")
    (let ((org-iw-exclude-regexp "/archive/"))
      (should (equal (org-iw-discovery-test--files)
                     '("ARCHIVE/up.org" "new.org"))))))

(ert-deftest org-iw-discovery-test-files-lock-file-of-modified-buffer ()
  "The real .# lock file of a modified visited buffer is not selected."
  (org-iw-test-with-corpus '(("a.org" . "* A\n"))
    (with-current-buffer (org-iw-test-visit "a.org")
      (insert "x"))
    (should (file-symlink-p (org-iw-test-path ".#a.org")))
    (should (equal (org-iw-discovery-test--files) '("a.org")))))

(ert-deftest org-iw-discovery-test-files-inaccessible-directory ()
  "A subdirectory that cannot be read is skipped without error."
  (org-iw-test-unless-root
    (org-iw-test-with-corpus '(("a.org" . "") ("locked/b.org" . ""))
      (org-iw-test-set-modes "locked" #o000)
      (should (equal (org-iw-discovery-test--files) '("a.org"))))))

(ert-deftest org-iw-discovery-test-files-missing-source ()
  "A source that does not exist is ignored."
  (org-iw-test-with-corpus '(("a.org" . ""))
    (let ((org-iw-sources (list (org-iw-test-path "gone.org")
                                (org-iw-test-path "gone/")
                                org-iw-test-dir)))
      (should (equal (org-iw-discovery-test--files) '("a.org"))))))

;;;; Scan (`org-iw-discovery-scan')

(ert-deftest org-iw-discovery-test-scan-heading-entry ()
  "A heading with an ID and a rank is an entry with its title and file."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat "Preamble.\n"
                            (org-iw-test-heading
                             "TODO [#A] Argument :tag:" "a1"
                             ":IW_ESSAYS: 5120" ":IW_NOTES:  -3  "))))
    (let ((entry (car (org-iw-scan-entries (org-iw-discovery-test--scan)))))
      (should (equal (org-iw-entry-id entry) "a1"))
      (should (equal (org-iw-entry-title entry) "Argument"))
      (should (equal (org-iw-entry-file entry) (org-iw-test-path "a.org")))
      (should (equal (org-iw-entry-memberships entry)
                     '(("ESSAYS" . 5120) ("NOTES" . -3)))))))

(ert-deftest org-iw-discovery-test-scan-document-entry ()
  "A document drawer is read; its title is #+title, else the file name."
  (org-iw-test-with-corpus
      `(("titled.org" . ,(org-iw-test-org
                          ":PROPERTIES:" ":ID: d1" ":IW_ESSAYS: 7" ":END:"
                          "#+title: The Doc" "* Heading"))
        ("plain.org" . ,(org-iw-test-org
                         "# comment" ":PROPERTIES:" ":ID: d2"
                         ":IW_ESSAYS: 8" ":END:")))
    (let ((scan (org-iw-discovery-test--scan)))
      (should (equal (org-iw-discovery-test--entries scan)
                     '(("d2" ("ESSAYS" . 8)) ("d1" ("ESSAYS" . 7)))))
      (should (equal (mapcar #'org-iw-entry-title (org-iw-scan-entries scan))
                     '("plain" "The Doc")))
      (should-not (org-iw-scan-problems scan)))))

(defun org-iw-discovery-test--outlines (scan)
  "Return the entries of SCAN as (ID . OUTLINE)."
  (mapcar (lambda (entry)
            (cons (org-iw-entry-id entry) (org-iw-entry-outline entry)))
          (org-iw-scan-entries scan)))

(ert-deftest org-iw-discovery-test-scan-outline-nested ()
  "An entry's outline is its ancestors' text, outermost first.
Cookies are stripped, links reduced and whitespace collapsed; a
member's outline holds its member parent, and a preceding top-level
heading does not leak in."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat
                     (org-iw-test-heading "Other" nil)
                     (org-iw-test-heading
                      "Plan [1/3] [[https://x.example][Site]]" "p1"
                      ":IW_Q: 1")
                     "*" (org-iw-test-heading "Mid" "m1" ":IW_Q: 2")
                     "**" (org-iw-test-heading "Deep" "d1" ":IW_Q: 3"))))
    (let ((outlines (org-iw-discovery-test--outlines
                     (org-iw-discovery-test--scan))))
      (should (equal (assoc "m1" outlines) (list "m1" "Plan Site")))
      (should (equal (assoc "d1" outlines) (list "d1" "Plan Site" "Mid"))))))

(ert-deftest org-iw-discovery-test-scan-outline-top-level-and-document ()
  "A top-level heading, even after nested ones, and a document have no outline."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat
                     (org-iw-test-heading "Parent" "p1" ":IW_Q: 1")
                     "*" (org-iw-test-heading "Child" "c1" ":IW_Q: 2")
                     (org-iw-test-heading "Next" "n1" ":IW_Q: 3")))
        ("b.org" . ,(org-iw-test-org
                     ":PROPERTIES:" ":ID: d1" ":IW_Q: 4" ":END:"
                     "* Heading")))
    (let ((outlines (org-iw-discovery-test--outlines
                     (org-iw-discovery-test--scan))))
      (should (equal (assoc "c1" outlines) '("c1" "Parent")))
      (dolist (id '("p1" "n1" "d1"))
        (should (equal (assoc id outlines) (list id)))))))

(ert-deftest org-iw-discovery-test-scan-no-inheritance ()
  "Members' children are not members, nor do they inherit the ID."
  (let ((org-use-property-inheritance t))
    (org-iw-discovery-test--check
     `(("a.org" . ,(concat (org-iw-test-heading
                            "Parent" "p1" ":IW_ESSAYS: 1")
                           "** Child\n"
                           ;; A leading star demotes to level 2.
                           "*" (org-iw-test-heading
                                "Child with ID" "c1")
                           "*" (org-iw-test-heading
                                "Child without ID" nil ":IW_NOTES: 2"))))
     '(("p1" ("ESSAYS" . 1)))
     '((missing-id "a.org" nil)))))

(ert-deftest org-iw-discovery-test-scan-property-names ()
  "Lowercase iw_essays is a member of ESSAYS; IW_AFTER_ESSAYS never is."
  (org-iw-discovery-test--check
   `(("a.org" . ,(concat (org-iw-test-heading
                          "Lower" "l1" ":iw_essays: 3"
                          ":IW_AFTER_ESSAYS: whatever")
                         (org-iw-test-heading
                          "Reserved only" "r1" ":IW_AFTER_ESSAYS: 1"))))
   '(("l1" ("ESSAYS" . 3)))
   nil))

(ert-deftest org-iw-discovery-test-scan-without-buffers ()
  "Scanning unvisited files creates, visits and keeps no corpus buffer."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-discovery-test--member)
                             ("b.org" . "No properties.\n"))
    (let ((buffers (seq-filter #'org-iw-test--corpus-buffer-p (buffer-list)))
          (scan (org-iw-discovery-test--scan)))
      (should (equal (org-iw-discovery-test--entries scan)
                     '(("m1" ("ESSAYS" . 1024)))))
      (should (equal (seq-filter #'org-iw-test--corpus-buffer-p (buffer-list))
                     buffers))
      (should-not (find-buffer-visiting (org-iw-test-path "a.org"))))))

(ert-deftest org-iw-discovery-test-scan-org-mode-only-on-iw-line ()
  "Org mode is started only for text holding an IW_ line."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-discovery-test--member)
                             ("b.org" . "* Plain\n") ("c.org" . "* Plain\n"))
    (let* ((calls 0)
           (count (lambda (&rest _) (setq calls (1+ calls)))))
      (advice-add 'org-mode :before count)
      (unwind-protect (org-iw-discovery-test--scan)
        (advice-remove 'org-mode count))
      (should (= calls 1)))))

(ert-deftest org-iw-discovery-test-scan-live-buffer-beats-disk ()
  "A visiting buffer's unsaved text is scanned whole, and left untouched."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading
                             "One" "a1" ":IW_ESSAYS: 1024")
                            (org-iw-test-heading
                             "Two" "a2" ":IW_ESSAYS: 2048"))))
    (with-current-buffer (org-iw-test-visit "a.org")
      (goto-char (point-min))
      (search-forward "1024")
      (replace-match "10")
      (search-forward "* Two")
      (narrow-to-region (line-beginning-position) (point-max))
      (let ((point (point))
            (bounds (cons (point-min) (point-max))))
        (should (equal (org-iw-discovery-test--entries
                        (org-iw-discovery-test--scan))
                       '(("a1" ("ESSAYS" . 10)) ("a2" ("ESSAYS" . 2048)))))
        (should (= (point) point))
        (should (equal (cons (point-min) (point-max)) bounds))
        (should (buffer-modified-p))
        (should (derived-mode-p 'org-mode))))
    (should (string-match-p "1024" (org-iw-test-file-string "a.org")))))

(ert-deftest org-iw-discovery-test-scan-live-buffer-in-other-mode ()
  "A visiting buffer outside Org mode is still read, and keeps its mode."
  (org-iw-test-with-corpus `(("a.txt" . ,org-iw-discovery-test--member))
    (with-current-buffer (org-iw-test-visit "a.txt")
      (should-not (derived-mode-p 'org-mode))
      (goto-char (point-min))
      (search-forward "1024")
      (replace-match "7")
      (should (equal (org-iw-discovery-test--entries
                      (org-iw-discovery-scan
                       (list (org-iw-test-path "a.txt"))))
                     '(("m1" ("ESSAYS" . 7)))))
      (should-not (derived-mode-p 'org-mode)))))

(ert-deftest org-iw-discovery-test-scan-symlink-visited-buffer ()
  "A buffer visited through a symlink is found; its unsaved rank wins (F-5)."
  (org-iw-test-with-corpus `(("real.org" . ,org-iw-discovery-test--member))
    (let* ((truename (org-iw-test-path "real.org"))
           (link (org-iw-test-make-symlink truename "link.org"))
           (buffer (find-file-noselect link)))
      (should (equal (buffer-file-name buffer) link))
      ;; The trap: a lookup by the truename's name misses this buffer.
      (should-not (get-file-buffer truename))
      (should (eq (find-buffer-visiting truename) buffer))
      (with-current-buffer buffer
        (goto-char (point-min))
        (search-forward "1024")
        (replace-match "-5"))
      (should (equal (org-iw-discovery-test--entries
                      (org-iw-discovery-scan (list truename)))
                     '(("m1" ("ESSAYS" . -5)))))
      (should (string-match-p "1024" (org-iw-test-file-string "real.org"))))))

(ert-deftest org-iw-discovery-test-scan-order ()
  "Results follow the order of the given files, then buffer order."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-heading "A1" nil ":IW_Q: 1"))
        ("b.org" . ,(concat (org-iw-test-heading
                             "B1" "b1" ":IW_Q: 1")
                            (org-iw-test-heading "B2" nil ":IW_Q: 2")
                            (org-iw-test-heading
                             "B3" "b3" ":IW_Q: 3"))))
    (let ((scan (org-iw-discovery-scan
                 (mapcar #'org-iw-test-path '("b.org" "a.org")))))
      (should (equal (org-iw-discovery-test--entries scan)
                     '(("b1" ("Q" . 1)) ("b3" ("Q" . 3)))))
      (should (equal (org-iw-discovery-test--problems scan)
                     '((missing-id "b.org" nil) (missing-id "a.org" nil)))))))

;;;; Problems

(ert-deftest org-iw-discovery-test-classify-lines ()
  "Raw IW lines classify into memberships and problem types."
  (should (equal (org-iw-discovery--classify-lines
                  '(("IW_A" . "1") ("iw_b" . "x") ("IW_AFTER_A" . "?")
                    ("IW_c_d" . "1") ("IW_E" . "1") ("IW_e+" . "2")
                    ("IW_F+" . "1") ("IW_G" . "2") ("iw_g" . "2")))
                 '((("A" . 1))
                   invalid-property invalid-rank duplicate-property
                   invalid-property duplicate-property)))
  (should (equal (org-iw-discovery--classify-lines nil) '(nil))))

(ert-deftest org-iw-discovery-test-problem-missing-id ()
  "IW properties without an ID give missing-id and no entry."
  (org-iw-discovery-test--check
   `(("a.org" . ,(org-iw-test-heading
                  "No ID" nil ":IW_ESSAYS: 1"))
     ("b.org" . ,(org-iw-test-heading
                  "Blank ID" "" ":IW_ESSAYS: 1")))
   nil
   '((missing-id "a.org" nil) (missing-id "b.org" nil))))

(ert-deftest org-iw-discovery-test-problem-invalid-rank ()
  "A bad or out-of-range rank gives invalid-rank and drops that membership."
  (org-iw-discovery-test--check
   `(("a.org" . ,(concat (org-iw-test-heading
                          "Soon" "a1" ":IW_ESSAYS: soon" ":IW_NOTES: 4")
                         (org-iw-test-heading
                          "Huge" "a2"
                          (format ":IW_ESSAYS: %d"
                                  (1+ org-iw-core-rank-limit))))))
   '(("a1" ("NOTES" . 4)))
   '((invalid-rank "a.org" "a1") (invalid-rank "a.org" "a2"))))

(ert-deftest org-iw-discovery-test-problem-invalid-property ()
  "Invalid IW names, including IW_straße and IW_ESSAYS+ alone, are problems."
  (org-iw-discovery-test--check
   `(("a.org" . ,(org-iw-test-heading
                  "Odd" "a1" ":IW_straße: 1" ":IW_ESSAYS+: 2"
                  ":IW_a_b: 3" ":IW_NOTES: 4")))
   '(("a1" ("NOTES" . 4)))
   '((invalid-property "a.org" "a1") (invalid-property "a.org" "a1")
     (invalid-property "a.org" "a1"))))

(ert-deftest org-iw-discovery-test-problem-duplicate-property ()
  "A queue named twice, as iw_essays or IW_ESSAYS+, is a duplicate-property."
  (org-iw-discovery-test--check
   `(("a.org" . ,(concat (org-iw-test-heading
                          "Case" "a1" ":IW_ESSAYS: 1" ":iw_essays: 2"
                          ":IW_NOTES: 3")
                         (org-iw-test-heading
                          "Accumulate" "a2" ":IW_ESSAYS: 1"
                          ":IW_ESSAYS+: 2"))))
   '(("a1" ("NOTES" . 3)))
   '((duplicate-property "a.org" "a1") (duplicate-property "a.org" "a2"))))

(ert-deftest org-iw-discovery-test-problem-duplicate-id-across-files ()
  "An ID on entries in two files is one duplicate-id; both are dropped."
  (org-iw-discovery-test--check
   `(("a.org" . ,(org-iw-test-heading "A" "x1" ":IW_ESSAYS: 1"))
     ("b.org" . ,(org-iw-test-heading "B" "x1" ":IW_NOTES: 2"))
     ("c.org" . ,(org-iw-test-heading "C" "c1" ":IW_NOTES: 3")))
   '(("c1" ("NOTES" . 3)))
   '((duplicate-id "a.org" "x1"))))

(ert-deftest org-iw-discovery-test-problem-duplicate-id-in-file ()
  "A non-member copy of the ID in the same file excludes the entry.
Copies differing in case, or quoted in a block, do not count."
  (org-iw-discovery-test--check
   `(("a.org" . ,(concat (org-iw-test-heading
                          "Member" "x1" ":IW_ESSAYS: 1")
                         (org-iw-test-heading "Copy" nil
                                              ":id:   x1  ")
                         (org-iw-test-heading
                          "Other" "Y1" ":IW_ESSAYS: 2")
                         (org-iw-test-heading "Variant" "y1")
                         (org-iw-test-org
                          "* Quoted" "#+begin_example" ":ID: Y1"
                          "#+end_example"))))
   '(("Y1" ("ESSAYS" . 2)))
   '((duplicate-id "a.org" "x1"))))

(ert-deftest org-iw-discovery-test-problem-no-surviving-membership ()
  "An entry left with no valid membership is not an entry."
  (org-iw-discovery-test--check
   `(("a.org" . ,(org-iw-test-heading
                  "Bad" "a1" ":IW_ESSAYS: soon"))
     ("b.org" . ,(org-iw-test-heading
                  "Also" "a1" ":IW_ESSAYS: 1")))
   '(("a1" ("ESSAYS" . 1)))
   '((invalid-rank "a.org" "a1"))))

;;;; RV-001 F-6: misplaced properties and blocks

(ert-deftest org-iw-discovery-test-problem-misplaced-property ()
  "A drawer after #+title or after body text is a misplaced-property."
  (org-iw-discovery-test--check
   `(("title.org" . ,(org-iw-test-org
                      "#+title: T" ":PROPERTIES:" ":ID: t1"
                      ":IW_ESSAYS: 1" ":END:"))
     ("body.org" . ,(org-iw-test-org
                     "* H" "Body text." ":PROPERTIES:" ":ID: b1"
                     ":IW_ESSAYS: 2" ":END:")))
   nil
   '((misplaced-property "body.org" nil)
     (misplaced-property "title.org" nil))))

(defconst org-iw-discovery-test--blocks
  '(("#+begin_src org" . "#+end_src")
    ("#+begin_example" . "#+end_example")
    ("#+begin_quote" . "#+end_quote")
    ("#+begin_foo" . "#+end_foo")
    ("#+BEGIN: clocktable :scope file" . "#+END:")
    ("#+begin_verse" . "#+end_verse")
    ("#+begin_export html" . "#+end_export")
    ("#+begin_comment" . "#+end_comment"))
  "Block delimiters (BEGIN . END) whose contents are quoted text.")

(ert-deftest org-iw-discovery-test-scan-skips-blocks ()
  "IW lines inside #+begin_quote, #+begin_src and other blocks are ignored."
  (dolist (block org-iw-discovery-test--blocks)
    (ert-info ((car block) :prefix "Block: ")
      (org-iw-discovery-test--check
       `(("a.org" . ,(concat org-iw-discovery-test--member
                             (org-iw-test-org
                              "* Quoting" (car block)
                              ":PROPERTIES:" ":ID: q1" ":IW_ESSAYS: 1"
                              ":END:" ":IW_NOTES: 2" (cdr block)))))
       '(("m1" ("ESSAYS" . 1024)))
       nil))))

;;;; RV-001 F-3: hostile directory contents

(ert-deftest org-iw-discovery-test-scan-hostile-directory ()
  "Lock files and dangling links are skipped; unreadable is a problem (F-3)."
  (org-iw-test-unless-root
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-discovery-test--member)
                               ("good.org" . ,(org-iw-test-heading
                                               "Good" "g1" ":IW_NOTES: 1"))
                               ("locked.org" . ,org-iw-discovery-test--member))
      (with-current-buffer (org-iw-test-visit "a.org")
        (goto-char (point-max))
        (insert "Unsaved.\n"))
      (should (file-symlink-p (org-iw-test-path ".#a.org")))
      (org-iw-test-make-symlink "user@host.123:456" ".#b.org")
      (org-iw-test-make-symlink "/nonexistent/x.org" "dangling.org")
      (org-iw-test-set-modes "locked.org" #o000)
      (should-not (file-readable-p (org-iw-test-path "locked.org")))
      (should (equal (org-iw-discovery-test--files)
                     '("a.org" "good.org" "locked.org")))
      (let ((scan (org-iw-discovery-test--scan)))
        (should (equal (org-iw-discovery-test--entries scan)
                       '(("m1" ("ESSAYS" . 1024)) ("g1" ("NOTES" . 1)))))
        (should (equal (org-iw-discovery-test--problems scan)
                       '((unreadable "locked.org" nil))))))))

;;;; ID resolution (`org-iw-discovery-buffer', `-id-count', `-resolve')

(defun org-iw-discovery-test--marker-line (marker)
  "Return the text of the line MARKER points at."
  (with-current-buffer (marker-buffer marker)
    (save-excursion
      (goto-char marker)
      (buffer-substring-no-properties (line-beginning-position)
                                      (line-end-position)))))

(defun org-iw-discovery-test--refuse (kind scan id name)
  "Assert resolving ID in corpus file NAME against SCAN refuses as KIND.
KIND is a regexp for the cause; the message must also name ID and the
file.  Each cause is worded differently, so this proves which one fired."
  (let* ((file (org-iw-test-path name))
         (err (should-error (org-iw-discovery-resolve scan id file)
                            :type 'org-iw-refusal))
         (message (error-message-string err)))
    (should (string-match-p kind message))
    (should (string-match-p (regexp-quote id) message))
    (should (string-match-p (regexp-quote file) message))))

(defun org-iw-discovery-test--copy-after-scan (name copy)
  "Scan the corpus, then add COPY to the end of the buffer visiting NAME.
Return the scan, taken before the copy existed, so it cannot have
excluded the ID; only `org-iw-discovery-id-count' can see the copy."
  (let ((scan (org-iw-discovery-test--scan)))
    (with-current-buffer (org-iw-test-visit name)
      (goto-char (point-max))
      (insert copy))
    scan))

(ert-deftest org-iw-discovery-test-buffer-lookup ()
  "The visiting buffer is returned, even for a symlink; else the file is visited."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-discovery-test--member)
                             ("b.org" . ,org-iw-discovery-test--member))
    (let* ((a (org-iw-test-visit "a.org"))
           (link (org-iw-test-make-symlink (org-iw-test-path "a.org")
                                           "link.org"))
           (b (org-iw-discovery-buffer (org-iw-test-path "b.org"))))
      (should (eq (org-iw-discovery-buffer (org-iw-test-path "a.org")) a))
      (should (eq (org-iw-discovery-buffer link) a))
      (should (equal (buffer-file-name b) (org-iw-test-path "b.org")))
      (should (eq (org-iw-discovery-buffer (org-iw-test-path "b.org")) b)))))

(ert-deftest org-iw-discovery-test-id-count-lines ()
  "`org-iw-discovery-id-count' counts ID property lines: any key case, exact value."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "One" "a1")
                            (org-iw-test-heading "Two" nil ":id: a1")
                            (org-iw-test-heading "Three" "A1")
                            (org-iw-test-org
                             "* Quoted" "#+begin_example" ":ID: a1"
                             "#+end_example" "Body text." ":ID: a1"))))
    (with-current-buffer (org-iw-test-visit "a.org")
      (should (= (org-iw-discovery-id-count "a1") 2))
      (should (= (org-iw-discovery-id-count "A1") 1))
      (should (= (org-iw-discovery-id-count "zz") 0)))))

(ert-deftest org-iw-discovery-test-id-count-ignores-narrowing ()
  "A copy outside `narrow-to-region' is still counted, target or copy alike."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "Target" "t1")
                            (org-iw-test-heading "Copy" "t1"))))
    (with-current-buffer (org-iw-test-visit "a.org")
      (goto-char (point-min))
      (narrow-to-region (point-min) (line-end-position))
      (should (= (org-iw-discovery-id-count "t1") 2))
      (widen)
      (search-forward "* Copy")
      (narrow-to-region (line-beginning-position) (point-max))
      (should (= (org-iw-discovery-id-count "t1") 2)))))

(ert-deftest org-iw-discovery-test-id-count-via-indirect-buffer ()
  "Called from a narrowed `make-indirect-buffer', the count is the base's."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "Target" "t1")
                            (org-iw-test-heading "Copy" nil ":id: t1"))))
    (let* ((base (org-iw-test-visit "a.org"))
           (indirect (make-indirect-buffer base "*org-iw-indirect*")))
      (unwind-protect
          (with-current-buffer indirect
            ;; Design § 3: an indirect buffer is never returned as a source.
            (should-not (buffer-file-name indirect))
            (should (eq (find-buffer-visiting (org-iw-test-path "a.org")) base))
            (narrow-to-region (point-min) (line-end-position))
            (should (= (org-iw-discovery-id-count "t1") 2)))
        (kill-buffer indirect)))))

(ert-deftest org-iw-discovery-test-resolve-unique ()
  "`org-iw-discovery-resolve' returns a marker at the heading, or point-min."
  (org-iw-test-with-corpus
      `(("a.org" . ,org-iw-discovery-test--member)
        ("b.org" . ,(org-iw-test-heading "Other" "b1"
                                         ":IW_NOTES: 1"))
        ("c.org" . ,(org-iw-test-org
                     ":PROPERTIES:" ":ID: d1" ":IW_ESSAYS: 7" ":END:"
                     "* Heading")))
    (let* ((scan (org-iw-discovery-test--scan))
           (visited (org-iw-test-visit "a.org"))
           (in-a (org-iw-discovery-resolve scan "m1" (org-iw-test-path "a.org")))
           (in-b (org-iw-discovery-resolve scan "b1" (org-iw-test-path "b.org")))
           (in-c (org-iw-discovery-resolve scan "d1" (org-iw-test-path "c.org"))))
      (should (eq (marker-buffer in-a) visited))
      (should (equal (org-iw-discovery-test--marker-line in-a) "* Member"))
      (should (equal (buffer-file-name (marker-buffer in-b))
                     (org-iw-test-path "b.org")))
      (should (equal (org-iw-discovery-test--marker-line in-b) "* Other"))
      (should (= in-c 1)))))

(ert-deftest org-iw-discovery-test-resolve-not-found ()
  "Resolve refuses an ID absent from the file, or differing only in case."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-heading "Upper" "A1"
                                         ":IW_ESSAYS: 1"))
        ("b.org" . ,org-iw-discovery-test--member))
    (let ((scan (org-iw-discovery-test--scan)))
      (org-iw-discovery-test--refuse "not found" scan "zz" "a.org")
      (org-iw-discovery-test--refuse "not found" scan "a1" "a.org")
      ;; Only the named file is searched.
      (org-iw-discovery-test--refuse "not found" scan "m1" "a.org")
      (should (org-iw-discovery-resolve scan "A1" (org-iw-test-path "a.org"))))))

(defun org-iw-discovery-test--resolve-txt (mode)
  "Resolve m1 in a visited a.txt, a listed source, set to MODE if non-nil.
Return the `*Warnings*' buffer's presence and the resolve outcome as
\(WARNED . RESULT): the marker, or the refusal's message."
  (org-iw-test-with-corpus `(("a.txt" . ,org-iw-discovery-test--member))
    (let ((org-iw-sources (list (org-iw-test-path "a.txt"))))
      (when (get-buffer "*Warnings*")
        (kill-buffer "*Warnings*"))
      (when mode
        (with-current-buffer (org-iw-test-visit "a.txt")
          (funcall mode)))
      (let* ((scan (org-iw-discovery-test--scan))
             (result (condition-case err
                         (org-iw-discovery-resolve
                          scan "m1" (org-iw-test-path "a.txt"))
                       (org-iw-refusal (error-message-string err)))))
        (cons (and (get-buffer "*Warnings*") t) result)))))

(ert-deftest org-iw-discovery-test-resolve-refuses-non-org-buffer ()
  "A visiting buffer not in Org mode is refused, naming the file (F-3).
No Org function runs there, so no warning is raised."
  (let ((outcome (org-iw-discovery-test--resolve-txt nil)))
    (should-not (car outcome))
    (should (string-search "buffer not in Org mode" (cdr outcome)))
    (should (string-search "a.txt" (cdr outcome)))))

(define-derived-mode org-iw-discovery-test--derived-mode org-mode "Derived"
  "An Org-derived mode, for `org-iw-discovery-test-resolve-derived-mode'.")

(ert-deftest org-iw-discovery-test-resolve-accepts-derived-org-mode ()
  "A mode derived from Org mode resolves as Org mode does (F-3)."
  (let ((outcome (org-iw-discovery-test--resolve-txt
                  #'org-iw-discovery-test--derived-mode)))
    (should-not (car outcome))
    (should (markerp (cdr outcome)))))

(ert-deftest org-iw-discovery-test-resolve-scan-excluded-duplicate ()
  "Resolve refuses an ID the scan excluded as a duplicate, in either file."
  (dolist (copy `(("no memberships" . ,(org-iw-test-heading
                                        "Copy" "x1"))
                  ("other queue" . ,(org-iw-test-heading
                                     "Copy" "x1" ":IW_NOTES: 1"))
                  ("lowercase key" . ,(org-iw-test-heading
                                       "Copy" nil ":id: x1"))))
    (ert-info ((car copy) :prefix "Copy: ")
      (org-iw-test-with-corpus
          `(("a.org" . ,(concat (org-iw-test-heading
                                 "Member" "x1" ":IW_ESSAYS: 1")
                                (cdr copy))))
        (let ((scan (org-iw-discovery-test--scan)))
          (should-not (org-iw-scan-entries scan))
          (org-iw-discovery-test--refuse "duplicate" scan "x1" "a.org")))))
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-heading "A" "x1" ":IW_ESSAYS: 1"))
        ("b.org" . ,(org-iw-test-heading "B" "x1" ":IW_NOTES: 2")))
    ;; The problem names only the first file; both must still be refused.
    (let ((scan (org-iw-discovery-test--scan)))
      (org-iw-discovery-test--refuse "duplicate" scan "x1" "a.org")
      (org-iw-discovery-test--refuse "duplicate" scan "x1" "b.org"))))

(ert-deftest org-iw-discovery-test-resolve-ambiguous-after-scan ()
  "Resolve refuses when a copy appeared after the scan, seen or hidden.
The scan predates the copy, so this is `org-iw-discovery-id-count' alone."
  (dolist (copy `(("no memberships" . ,(org-iw-test-heading
                                        "Copy" "m1"))
                  ("other queue" . ,(org-iw-test-heading
                                     "Copy" "m1" ":IW_NOTES: 1"))
                  ("lowercase key" . ,(org-iw-test-heading
                                       "Copy" nil ":id: m1"))))
    (ert-info ((car copy) :prefix "Copy: ")
      (org-iw-test-with-corpus `(("a.org" . ,org-iw-discovery-test--member))
        (let ((scan (org-iw-discovery-test--copy-after-scan "a.org" (cdr copy))))
          (should (org-iw-scan-entries scan))
          (org-iw-discovery-test--refuse "ambiguous" scan "m1" "a.org")
          (with-current-buffer (org-iw-test-visit "a.org")
            ;; Hidden by narrowing to the target, or the target hidden.
            (goto-char (point-min))
            (narrow-to-region (point-min) (line-end-position))
            (org-iw-discovery-test--refuse "ambiguous" scan "m1" "a.org")
            (widen)
            (goto-char (point-max))
            (search-backward "* Copy")
            (narrow-to-region (line-beginning-position) (point-max))
            (org-iw-discovery-test--refuse "ambiguous" scan "m1" "a.org")))))))

(ert-deftest org-iw-discovery-test-resolve-narrowed-and-indirect ()
  "Resolve finds the target through narrowing and an indirect buffer.
The marker is in the base buffer, whatever buffer is current."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "Front" "f1")
                            org-iw-discovery-test--member)))
    (let* ((scan (org-iw-discovery-test--scan))
           (file (org-iw-test-path "a.org"))
           (base (org-iw-test-visit "a.org"))
           (indirect (make-indirect-buffer base "*org-iw-indirect*")))
      (unwind-protect
          (with-current-buffer indirect
            (narrow-to-region (point-min) (line-end-position))
            (let ((marker (org-iw-discovery-resolve scan "m1" file)))
              (should (eq (marker-buffer marker) base))
              (should (equal (org-iw-discovery-test--marker-line marker)
                             "* Member"))))
        (kill-buffer indirect))
      (with-current-buffer base
        (narrow-to-region (point-min) (line-end-position))
        (should (org-iw-discovery-resolve scan "m1" file))))))

(ert-deftest org-iw-discovery-test-duplicate-excludes-only-its-own-id ()
  "A duplicate-id problem on one ID does not touch another ID (RV-002 F-11)."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "A" "x1" ":IW_ESSAYS: 1")
                            (org-iw-test-heading "B" "x1" ":IW_NOTES: 2")
                            (org-iw-test-heading "C" "y1" ":IW_NOTES: 3"))))
    (let ((scan (org-iw-discovery-test--scan))
          (file (org-iw-test-path "a.org")))
      (should (org-iw-discovery-excluded-id-p scan "x1"))
      (should-not (org-iw-discovery-excluded-id-p scan "y1"))
      (should-not (org-iw-discovery-problem-types scan "y1"))
      (should (markerp (org-iw-discovery-resolve scan "y1" file))))))

(ert-deftest org-iw-discovery-test-problem-types-nil-id-is-missing-id ()
  "An entry without an ID reports (missing-id), not other ID-less problems.
A misplaced-property problem also has no ID, but is not this entry's."
  (org-iw-test-with-corpus
      `(("body.org" . ,(org-iw-test-org
                        "* H" "Body text." ":PROPERTIES:" ":ID: b1"
                        ":IW_ESSAYS: 2" ":END:")))
    (let ((scan (org-iw-discovery-test--scan)))
      (should (equal (org-iw-discovery-test--problems scan)
                     '((misplaced-property "body.org" nil))))
      (should (equal (org-iw-discovery-problem-types scan nil)
                     '(missing-id))))))

(provide 'org-iw-discovery-test)
;;; org-iw-discovery-test.el ends here
