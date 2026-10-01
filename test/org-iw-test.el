;;; org-iw-test.el --- Tests for the org-iw commands  -*- lexical-binding: t; -*-

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

;; ERT tests for the command layer: `org-iw-add', the session and its
;; mode line, `org-iw-visit-next', `org-iw-continue',
;; `org-iw-end-session', and the private helpers the commands share.
;; Every prompt is stubbed, so that no test reads from standard input.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-iw-test-helpers)
(require 'org-iw)

;;;; Helpers

(defun org-iw-cmd-test--add-at (marker queue)
  "Call `org-iw-add' for QUEUE with point at MARKER, in its buffer.
Return its result."
  (with-current-buffer (marker-buffer marker)
    (goto-char marker)
    (org-iw-add queue)))

(defun org-iw-cmd-test--add (name title queue)
  "Add the heading TITLE of corpus file NAME to QUEUE; return the result."
  (org-iw-cmd-test--add-at (org-iw-test-marker name title) queue))

(defvar org-iw-cmd-test--prompts nil
  "The `completing-read' calls seen by `org-iw-cmd-test--with-prompt'.")

(defun org-iw-cmd-test--cycle-order (collection predicate)
  "Return the candidates of COLLECTION as a completion UI cycles them.
PREDICATE filters them, as in `all-completions'.  The order is the
table's `cycle-sort-function', or `string<' when it has none, as a
sorting UI would show them."
  (let ((all (all-completions "" collection predicate))
        (sort (completion-metadata-get
               (completion-metadata "" collection predicate)
               'cycle-sort-function)))
    (funcall (or sort (lambda (list) (sort list #'string<))) all)))

(defmacro org-iw-cmd-test--with-prompt (answer &rest body)
  "Run BODY with `completing-read' stubbed to answer from ANSWER.
ANSWER is a string, or a list of strings answering successive prompts.
A prompt with no answer left fails the test, so ANSWER nil proves BODY
never prompts.  Each call is recorded, in order, in
`org-iw-cmd-test--prompts' as a plist (:prompt :collection
:require-match :default :order :annotate), :order being
`org-iw-cmd-test--cycle-order'."
  (declare (indent 1) (debug t))
  (let ((answers (make-symbol "answers")))
    `(let ((org-iw-cmd-test--prompts nil)
           (,answers (ensure-list ,answer)))
       (cl-letf (((symbol-function 'completing-read)
                  (lambda (prompt collection &optional predicate require-match
                                  _initial _hist default &rest _)
                    (setq org-iw-cmd-test--prompts
                          (append
                           org-iw-cmd-test--prompts
                           (list
                            (list :prompt prompt :collection collection
                                  :require-match require-match
                                  :default default
                                  :order (org-iw-cmd-test--cycle-order
                                          collection predicate)
                                  :annotate (plist-get
                                             completion-extra-properties
                                             :annotation-function)))))
                    (or (pop ,answers)
                        (ert-fail (list "Unexpected prompt" prompt))))))
         ,@body))))

(ert-deftest org-iw-cmd-test-with-prompt-self-test ()
  "The prompt recorder answers in turn, records, and fails when out."
  (org-iw-cmd-test--with-prompt '("a" "b")
    (should (equal (completing-read "One: " '("y" "x") nil t nil nil "x") "a"))
    (should (equal (completing-read "Two: " '("z")) "b"))
    (should (equal (mapcar (lambda (call) (plist-get call :prompt))
                           org-iw-cmd-test--prompts)
                   '("One: " "Two: ")))
    (pcase-let ((`(,one ,two) org-iw-cmd-test--prompts))
      (should (equal (plist-get one :default) "x"))
      (should (eq (plist-get one :require-match) t))
      (should (equal (plist-get one :order) '("x" "y")))
      (should-not (plist-get two :default)))
    (should-error (completing-read "Three: " '("w")) :type 'ert-test-failed))
  (org-iw-cmd-test--with-prompt nil
    (should-error (completing-read "Any: " '("w")) :type 'ert-test-failed))
  (let ((table (lambda (string pred action)
                 (if (eq action 'metadata)
                     '(metadata (cycle-sort-function . identity))
                   (complete-with-action action '("b" "a") string pred)))))
    (should (equal (org-iw-cmd-test--cycle-order table nil) '("b" "a")))))

;;;; Private helpers

(defconst org-iw-cmd-test--no-room-at-end
  (concat "no room at the end in ESSAYS; redistribution is not yet"
          " available — choose another placement")
  "The refusal when ESSAYS has no rank left after its last member.")

(ert-deftest org-iw-cmd-test-files-honour-exclude-regexp ()
  "A file matching `org-iw-exclude-regexp' is not a source file."
  (org-iw-test-with-corpus '(("a.org" . "* A\n") ("skip.org" . "* S\n"))
    (let ((org-iw-exclude-regexp "skip"))
      (should (equal (org-iw--files) (list (org-iw-test-path "a.org")))))))

(ert-deftest org-iw-cmd-test-source-file-p ()
  "Corpus files and their indirect buffers are sources; others are not."
  (org-iw-test-with-corpus '(("a.org" . "* A\n") ("b.org" . "* B\n"))
    (let ((marker (org-iw-test-marker "a.org" "A")))
      (with-current-buffer (marker-buffer marker)
        (should (org-iw--source-file-p)))
      (org-iw-test-call-with-indirect
       marker (lambda (_) (should (org-iw--source-file-p))))
      (with-temp-buffer
        (org-mode)
        (should-not (org-iw--source-file-p)))
      (with-current-buffer (marker-buffer marker)
        (let ((org-iw-exclude-regexp "a\\.org"))
          (should-not (org-iw--source-file-p))))
      (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
        (with-current-buffer (org-iw-test-visit "b.org")
          (should-not (org-iw--source-file-p)))))))

(ert-deftest org-iw-cmd-test-queue-name ()
  "A configured :name is found whatever the key's case; else the ID."
  (let ((org-iw-queues '(("essays" :name "Essays") ("Ideas"))))
    (should (equal (org-iw--queue-name "ESSAYS") "Essays"))
    (should (equal (org-iw--queue-name "IDEAS") "IDEAS"))
    (should (equal (org-iw--queue-name "DRAFTS") "DRAFTS"))))

;;;; Vocabulary
;; The vocabulary helpers are tested directly (STD-001 item 6): they are
;; the one owner of reading placements from config, and every bad-config
;; shape is cheaper to pin here than through a command.  The commands'
;; own tests cover a sample of each through their entry points.

(defconst org-iw-cmd-test--standard
  '(("Soon" (after 2)) ("Later" (fraction 1 2)) ("End" end))
  "The standard placements, as a literal.")

(defconst org-iw-cmd-test--queues
  '(("articles" :name "Articles"
     :placements (("Soon" (after 2)) ("End" end)) :default "End")
    ("TWEETS" :placements (("Again" (after 5)) ("Later" (percent 75))))
    ("NOTES" :default "Soon"))
  "Queues configuring placements and a default, placements, or a default.")

(defun org-iw-cmd-test--standard-value (symbol)
  "Return the standard value of the user option SYMBOL."
  (eval (car (get symbol 'standard-value)) t))

(ert-deftest org-iw-cmd-test-placement-options-defaults ()
  "The standard vocabulary is Soon, Later and End, defaulting to End."
  (should (equal (org-iw-cmd-test--standard-value 'org-iw-placements)
                 '(("Soon" (after 2)) ("Later" (fraction 1 2)) ("End" end))))
  (should (equal (org-iw-cmd-test--standard-value 'org-iw-default-placement)
                 "End")))

(ert-deftest org-iw-cmd-test-placement-options-types ()
  "Each standard value and placement form matches its customize type."
  (require 'cus-edit)
  (let ((type (get 'org-iw-placements 'custom-type)))
    (should (widget-apply (widget-convert type) :match
                          (append org-iw-cmd-test--standard
                                  '(("P" (percent 75)) ("F" (fraction 0 1))))))
    (should-not (widget-apply (widget-convert type) :match '(("S" soon)))))
  (should (widget-apply (widget-convert
                         (get 'org-iw-default-placement 'custom-type))
                        :match nil))
  (should (widget-apply (widget-convert (get 'org-iw-queues 'custom-type))
                        :match org-iw-cmd-test--queues)))

(ert-deftest org-iw-cmd-test-queue-config ()
  "A queue's options are found whatever the key's case; else nil."
  (let ((org-iw-queues org-iw-cmd-test--queues))
    (should (equal (org-iw--queue-config "ARTICLES")
                   (cdar org-iw-cmd-test--queues)))
    (should (equal (org-iw--queue-config "NOTES") '(:default "Soon")))
    (should-not (org-iw--queue-config "OTHER"))))

(ert-deftest org-iw-cmd-test-vocabulary ()
  "A queue's placements and default come from its options, else the globals.
A queue with its own placements but no default uses the first."
  (let ((org-iw-queues org-iw-cmd-test--queues))
    (should (equal (org-iw--vocabulary "ARTICLES")
                   '("End" ("Soon" (after 2)) ("End" end))))
    (should (equal (org-iw--vocabulary "TWEETS")
                   '("Again" ("Again" (after 5)) ("Later" (percent 75)))))
    (should (equal (org-iw--vocabulary "NOTES")
                   (cons "Soon" org-iw-cmd-test--standard)))
    (should (equal (org-iw--vocabulary "OTHER")
                   (cons "End" org-iw-cmd-test--standard)))
    (let ((org-iw-default-placement nil))
      (should (equal (car (org-iw--vocabulary "OTHER")) "Soon")))
    (let ((org-iw-placements '(("A" end) ("B" (after 1))))
          (org-iw-default-placement "B"))
      (should (equal (org-iw--vocabulary "OTHER")
                     '("B" ("A" end) ("B" (after 1)))))
      (should (equal (car (org-iw--vocabulary "TWEETS")) "Again")))))

(ert-deftest org-iw-cmd-test-vocabulary-refuses-bad-config ()
  "Bad placements or a missing default refuse, naming the option at fault.
Each case is a queue's options, the global placements and default, and
the refusal."
  (pcase-dolist
      (`(,options ,placements ,default ,message)
       '(((:name "Articles" :placements (("Soon" (after -1)))) nil "End"
          "queue Articles :placements: invalid entry (\"Soon\" (after -1))")
         ((:placements (("A" end) ("A" (after 1)))) nil "End"
          "queue ARTICLES :placements: duplicate label \"A\"")
         ((:placements (("" end))) nil "End"
          "queue ARTICLES :placements: invalid entry (\"\" end)")
         ((:placements ((soon end))) nil "End"
          "queue ARTICLES :placements: invalid entry (soon end)")
         ((:placements (("A" end x))) nil "End"
          "queue ARTICLES :placements: invalid entry (\"A\" end x)")
         ((:placements nil) nil "End"
          "queue ARTICLES :placements: no placements")
         ((:placements end) nil "End"
          "queue ARTICLES :placements: not a list")
         ((:placements (("A" end)) :default "B") nil "End"
          "queue ARTICLES :default: \"B\" is not a placement label")
         ((:default nil) (("A" end)) "A"
          "queue ARTICLES :default: nil is not a placement label")
         ((:default "Nope") (("A" end)) "A"
          "queue ARTICLES :default: \"Nope\" is not a placement label")
         (nil nil "End" "org-iw-placements: no placements")
         (nil (("A" (fraction 1 0))) "A"
          "org-iw-placements: invalid entry (\"A\" (fraction 1 0))")
         (nil (("A" end)) "Nope"
          "org-iw-default-placement: \"Nope\" is not a placement label")))
    (let ((org-iw-queues (and options (list (cons "articles" options))))
          (org-iw-placements placements)
          (org-iw-default-placement default))
      (should (equal (cadr (should-error (org-iw--vocabulary "ARTICLES")
                                         :type 'org-iw-refusal))
                     message)))))

(ert-deftest org-iw-cmd-test-placement ()
  "A label names its placement; nil names the default's; others refuse."
  (let ((org-iw-queues org-iw-cmd-test--queues))
    (should (equal (org-iw--placement "ARTICLES" "Soon") '("Soon" after 2)))
    (should (equal (org-iw--placement "ARTICLES" nil) '("End" . end)))
    (should (equal (org-iw--placement "OTHER" "Later")
                   '("Later" fraction 1 2)))
    (should (equal (cadr (should-error (org-iw--placement "ARTICLES" "Later")
                                       :type 'org-iw-refusal))
                   "queue Articles has no placement \"Later\""))))

(ert-deftest org-iw-cmd-test-read-placement ()
  "The chooser offers the labels in configured order, defaulting.
It requires a match, and keeps the order in both cycling and
*Completions* listings."
  (let ((org-iw-queues org-iw-cmd-test--queues))
    (org-iw-cmd-test--with-prompt "Later"
      (should (equal (org-iw--read-placement "OTHER") "Later"))
      (pcase-let* ((`(,call) org-iw-cmd-test--prompts)
                   (table (plist-get call :collection)))
        (should (equal (plist-get call :prompt) "Placement: "))
        (should (equal (plist-get call :order) '("Soon" "Later" "End")))
        (should (equal (plist-get call :default) "End"))
        (should (eq (plist-get call :require-match) t))
        (should (eq (completion-metadata-get (completion-metadata "" table nil)
                                             'display-sort-function)
                    #'identity))
        (should (equal (all-completions "L" table) '("Later")))
        (should (eq (try-completion "End" table) t))))
    (org-iw-cmd-test--with-prompt "Soon"
      (org-iw--read-placement "ARTICLES")
      (should (equal (plist-get (car org-iw-cmd-test--prompts) :order)
                     '("Soon" "End"))))))

(ert-deftest org-iw-cmd-test-read-placement-refuses-before-prompting ()
  "Bad config refuses before the chooser prompts."
  (let ((org-iw-queues '(("ARTICLES" :placements nil))))
    (org-iw-cmd-test--with-prompt nil
      (should-error (org-iw--read-placement "ARTICLES")
                    :type 'org-iw-refusal))))

;;;; Add: success (VT-1, I2, I4, I5)

(defconst org-iw-cmd-test--target
  (concat (org-iw-test-heading "Target" "t1" ":IW_OTHER: 5"
                               ":IW_AFTER_ESSAYS: x" ":CUSTOM: keep")
          (org-iw-test-org "Body." "* Next" "Text."))
  "A file whose heading Target has an ID and other IW lines.")

(defconst org-iw-cmd-test--member
  (org-iw-test-heading "Member" "m1" ":IW_ESSAYS: 2048")
  "A file whose heading Member is in ESSAYS at 2048.")

(defconst org-iw-cmd-test--corpus
  `(("a.org" . ,org-iw-cmd-test--target)
    ("b.org" . ,org-iw-cmd-test--member))
  "Target, not yet queued, and a queue ESSAYS holding Member.")

(defun org-iw-cmd-test--order (queue)
  "Return the IDs of QUEUE's members in queue order, scanned afresh."
  (mapcar #'org-iw-entry-id (org-iw--order (org-iw--scan) queue)))

(ert-deftest org-iw-cmd-test-add-appends ()
  "Add appends; on disk only the new IW_ESSAYS line appears (I2, I4)."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((org-iw-queues '(("essays" :name "Essays"))))
      (should (equal (org-iw-cmd-test--add "a.org" "Target" "essays")
                     "Added to Essays at 2/2 (saved)"))
      (should (equal (org-iw-test-changed-lines
                      org-iw-cmd-test--target
                      (org-iw-test-file-string "a.org"))
                     '(nil ":IW_ESSAYS: 3072")))
      (should-not (buffer-modified-p (org-iw-test-visit "a.org")))
      (should (equal (org-iw-cmd-test--order "ESSAYS") '("m1" "t1"))))))

(ert-deftest org-iw-cmd-test-add-creates-drawer-and-id ()
  "A heading without drawer or ID gets both, and joins an empty queue."
  (let ((text (org-iw-test-org "* New" "Body.")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "New")))
        (should (equal (org-iw-cmd-test--add-at marker "ESSAYS")
                       "Added to ESSAYS at 1/1 (saved)"))
        (org-iw-test-should-add-drawer text marker "* New")))))

(ert-deftest org-iw-cmd-test-add-drawerless-before-drawer-heading ()
  "A drawerless heading is given its own drawer, not a later heading's."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-org "* New" "Body.")
                            (org-iw-test-heading "Later" "l1"))))
    (should (string-prefix-p "Added" (org-iw-cmd-test--add "a.org" "New"
                                                           "ESSAYS")))))

(ert-deftest org-iw-cmd-test-add-leaves-dirty-buffer-unsaved ()
  "A buffer with unsaved edits is changed but not saved (I5)."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-test-edit-elsewhere marker)
      (should (string-search "queue change not saved"
                             (org-iw-cmd-test--add-at marker "ESSAYS")))
      (should (buffer-modified-p (marker-buffer marker)))
      (should (equal (org-iw-test-file-string "a.org")
                     org-iw-cmd-test--target)))))

(ert-deftest org-iw-cmd-test-add-reports-failed-save ()
  "A failing save is reported with its error; the edit stands."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((write-file-functions (list (lambda () (error "Disk full")))))
      (should (equal (org-iw-cmd-test--add "a.org" "Target" "ESSAYS")
                     (concat "Added to ESSAYS at 2/2 (queue change applied"
                             " but not saved: Disk full)")))
      (should (buffer-modified-p (org-iw-test-visit "a.org")))
      (should (equal (org-iw-test-file-string "a.org")
                     org-iw-cmd-test--target)))))

;;;; Add: already a member (VT-1)

(defun org-iw-cmd-test--queue-of-three (target-line)
  "Return a corpus: ESSAYS holds A, Target (by TARGET-LINE) and C."
  `(("a.org" . ,(concat (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1024")
                        (org-iw-test-heading "Target" "t1" target-line)))
    ("c.org" . ,(org-iw-test-heading "C" "c1" ":IW_ESSAYS: 3072"))))

(defun org-iw-cmd-test--should-be-no-op (target-line)
  "Assert Add of a member by TARGET-LINE reports it and changes nothing."
  (org-iw-test-with-corpus (org-iw-cmd-test--queue-of-three target-line)
    (let* ((marker (org-iw-test-marker "a.org" "Target"))
           (before (org-iw-test-state)))
      (should (equal (org-iw-cmd-test--add-at marker "ESSAYS")
                     "Already in ESSAYS at 2/3"))
      (should (equal (org-iw-test-state) before)))))

(ert-deftest org-iw-cmd-test-add-member-is-no-op ()
  "Adding a member reports its position; nothing is written or saved."
  (org-iw-cmd-test--should-be-no-op ":IW_ESSAYS: 2048"))

(ert-deftest org-iw-cmd-test-add-lowercase-member-is-no-op ()
  "A member by a lowercase iw_essays key is a member too."
  (org-iw-cmd-test--should-be-no-op ":iw_essays: 2048"))

;;;; Add: refusals (VT-2, I7)

(defun org-iw-cmd-test--at (name title)
  "Return a marker at heading TITLE of corpus file NAME.
TITLE nil means the start of the file, before any heading."
  (if title
      (org-iw-test-marker name title)
    (with-current-buffer (org-iw-test-visit name)
      (copy-marker (point-min)))))

(defun org-iw-cmd-test--should-refuse (marker queue substring)
  "Assert Add at MARKER to QUEUE refuses with SUBSTRING, changing nothing.
The refusal must be an `org-iw-refusal', and the corpus files and
buffers must be as before.  Return the refusal message."
  (let* ((before (org-iw-test-state))
         (reason (cadr (should-error (org-iw-cmd-test--add-at marker queue)
                                     :type 'org-iw-refusal))))
    (should (string-search substring reason))
    (should (equal (org-iw-test-state) before))
    reason))

(defun org-iw-cmd-test--refuses (text queue substring &optional title)
  "Assert Add refuses with SUBSTRING in a corpus holding a.org as TEXT.
Add is at heading TITLE of a.org, or its start if TITLE is nil, to
QUEUE.  Return the refusal message."
  (org-iw-test-with-corpus `(("a.org" . ,text))
    (org-iw-cmd-test--should-refuse (org-iw-cmd-test--at "a.org" title)
                                    queue substring)))

(defconst org-iw-cmd-test--intro
  (org-iw-test-org "Intro." "* H")
  "A file with text before its first heading H.")

(ert-deftest org-iw-cmd-test-add-refuses-outside-sources ()
  "Add refuses a file outside the sources and a buffer with no file."
  (org-iw-test-with-corpus '(("a.org" . "* A\n") ("b.org" . "* B\n"))
    (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
      (org-iw-cmd-test--should-refuse (org-iw-test-marker "b.org" "B")
                                      "ESSAYS" "not under org-iw-sources"))
    (with-temp-buffer
      (insert "* H\n")
      (org-mode)
      (org-iw-cmd-test--should-refuse (copy-marker (point-min))
                                      "ESSAYS" "not under org-iw-sources"))))

(ert-deftest org-iw-cmd-test-add-refuses-document-target ()
  "Add refuses point before the first heading."
  (org-iw-cmd-test--refuses org-iw-cmd-test--intro "ESSAYS"
                            "document targets are not yet supported"))

(ert-deftest org-iw-cmd-test-add-refuses-invalid-queue ()
  "Add refuses a typed queue ID that is not valid, quoting it."
  (dolist (queue '("ess_ays" "" "straße"))
    (should (string-search (format "%S" queue)
                           (org-iw-cmd-test--refuses
                            "* H\n" queue "invalid queue ID" "H")))))

(ert-deftest org-iw-cmd-test-add-refuses-non-org-buffer ()
  "Add refuses a source file in a non-Org mode before prompting (F-3).
Nothing changes and no Org parsing runs, so no warnings appear."
  (org-iw-test-with-corpus `(("a.txt" . ,org-iw-cmd-test--target))
    (let ((org-iw-sources (list (org-iw-test-path "a.txt"))))
      (when (get-buffer "*Warnings*")
        (kill-buffer "*Warnings*"))
      (with-current-buffer (org-iw-test-visit "a.txt")
        (text-mode)
        (goto-char (point-min))
        (let ((before (org-iw-test-state)))
          (org-iw-cmd-test--with-prompt nil
            (should (string-search
                     "buffer not in Org mode"
                     (cadr (should-error (call-interactively #'org-iw-add)
                                         :type 'org-iw-refusal)))))
          (should (equal (org-iw-test-state) before))
          (should-not (get-buffer "*Warnings*")))))))

(ert-deftest org-iw-cmd-test-add-refuses-read-only-buffer ()
  "Add refuses in a read-only buffer, even `view-mode' (RV-002 F-1)."
  (dolist (mode '(read-only-mode view-mode))
    (org-iw-test-with-corpus org-iw-cmd-test--corpus
      (let ((marker (org-iw-test-marker "a.org" "Target")))
        (with-current-buffer (marker-buffer marker)
          (funcall mode 1))
        (org-iw-cmd-test--should-refuse marker "ESSAYS" "buffer is read-only")))))

(defconst org-iw-cmd-test--malformed
  (org-iw-test-org "* H" "Body." ":PROPERTIES:" ":ID: h1" ":END:")
  "A heading H whose drawer follows body text, so Org ignores it.")

(ert-deftest org-iw-cmd-test-add-refuses-malformed-drawer ()
  "Add refuses a drawer Org does not see, last heading or not."
  (dolist (text (list org-iw-cmd-test--malformed
                      (concat org-iw-cmd-test--malformed "* Next\n")))
    (org-iw-cmd-test--refuses text "ESSAYS"
                              "property drawer Org doesn't recognise" "H")))

(ert-deftest org-iw-cmd-test-add-ignores-drawer-text-in-block ()
  "A :PROPERTIES: line in a block is text; Add makes a real drawer."
  (let ((text (org-iw-test-org "* H" "#+begin_example" ":PROPERTIES:"
                               ":END:" "#+end_example")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "H")))
        (org-iw-cmd-test--add-at marker "ESSAYS")
        (org-iw-test-should-add-drawer text marker "* H")))))

(ert-deftest org-iw-cmd-test-add-refuses-excluded-property ()
  "Add refuses a heading whose IW_ESSAYS the scan excluded, naming why."
  (pcase-dolist (`(,id ,lines ,type)
                 '(("h1" (":IW_ESSAYS: soon") "invalid-rank")
                   ("h1" (":IW_ESSAYS: 1" ":iw_essays: 2")
                    "duplicate-property")
                   ("h1" (":IW_ESSAYS+: 1") "invalid-property")
                   (nil (":IW_ESSAYS: 1") "missing-id")))
    (org-iw-cmd-test--refuses (apply #'org-iw-test-heading "H" id lines)
                              "ESSAYS" (format "excluded (%s)" type) "H")))

(ert-deftest org-iw-cmd-test-add-refuses-at-rank-limit ()
  "Add refuses when the last rank leaves no room below the limit."
  (org-iw-cmd-test--refuses
   (concat (org-iw-test-heading "Last" "l1" ":IW_ESSAYS: 9007199254740991")
           (org-iw-test-heading "H" "h1"))
   "ESSAYS" org-iw-cmd-test--no-room-at-end "H"))

(ert-deftest org-iw-cmd-test-add-refusal-order ()
  "When two refusals apply, the earlier in the design's order wins."
  (org-iw-test-with-corpus `(("a.org" . "* A\n")
                             ("b.org" . ,org-iw-cmd-test--intro))
    (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
      (org-iw-cmd-test--should-refuse (org-iw-cmd-test--at "b.org" nil)
                                      "ESSAYS" "not under org-iw-sources")))
  (org-iw-cmd-test--refuses org-iw-cmd-test--intro "ess_ays"
                            "document targets")
  (org-iw-cmd-test--refuses org-iw-cmd-test--malformed "ess_ays"
                            "invalid queue ID" "H"))

(ert-deftest org-iw-cmd-test-add-refuses-before-prompting ()
  "Interactively, a non-source buffer or a document target never prompts."
  (org-iw-cmd-test--with-prompt nil
    (with-temp-buffer
      (insert "* H\n")
      (org-mode)
      (should-error (call-interactively #'org-iw-add)
                    :type 'org-iw-refusal))
    (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--intro))
      (with-current-buffer (org-iw-test-visit "a.org")
        (goto-char (point-min))
        (should (string-search "document targets"
                               (cadr (should-error
                                      (call-interactively #'org-iw-add)
                                      :type 'org-iw-refusal))))))))

;;;; Add: shared IDs (EX-3, RV-001 F-2)

(defun org-iw-cmd-test--copy (&rest lines)
  "Return a heading Copy with Member's ID m1 and drawer LINES."
  (apply #'org-iw-test-heading "Copy" "m1" lines))

(defun org-iw-cmd-test--should-refuse-shared (files)
  "Assert Add of Copy in a.org refuses as sharing an ID, given FILES.
The scan must be the same before and after.  Return the scan."
  (org-iw-test-with-corpus files
    (let ((scan (org-iw--scan)))
      (org-iw-cmd-test--should-refuse (org-iw-test-marker "a.org" "Copy")
                                      "ESSAYS"
                                      "ID shared with another heading")
      (should (equal (org-iw--scan) scan))
      scan)))

(ert-deftest org-iw-cmd-test-add-refuses-id-shared-in-file ()
  "Add refuses a heading whose ID a member in the same file has.
The scan already excludes both copies as duplicates; Add adds no
third, and Member's line is untouched."
  (let ((scan (org-iw-cmd-test--should-refuse-shared
               `(("a.org" . ,(concat org-iw-cmd-test--member
                                     (org-iw-cmd-test--copy)))))))
    (should-not (org-iw-scan-entries scan))))

(ert-deftest org-iw-cmd-test-add-refuses-nonmember-shared-id-in-file ()
  "Add refuses a heading whose ID another non-member in the file has."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "One" "x1")
                            (org-iw-test-heading "Two" "x1"))))
    (org-iw-cmd-test--should-refuse (org-iw-test-marker "a.org" "One")
                                    "ESSAYS"
                                    "ID shared with another heading")))

(ert-deftest org-iw-cmd-test-add-refuses-id-shared-across-files ()
  "Add refuses a heading whose ID a member in another file has.
The member stays in the queue at its rank."
  (let ((scan (org-iw-cmd-test--should-refuse-shared
               `(("a.org" . ,(org-iw-cmd-test--copy))
                 ("b.org" . ,org-iw-cmd-test--member)))))
    (should (equal (mapcar (lambda (entry)
                             (org-iw-core-rank entry "ESSAYS"))
                           (org-iw-core-queue-order
                            (org-iw-scan-entries scan) "ESSAYS"))
                   '(2048)))))

(ert-deftest org-iw-cmd-test-add-refuses-id-excluded-as-duplicate ()
  "Add refuses an ID the scan excluded as shared by two other files."
  (org-iw-cmd-test--should-refuse-shared
   `(("a.org" . ,(org-iw-cmd-test--copy))
     ("b.org" . ,org-iw-cmd-test--member)
     ("c.org" . ,(org-iw-test-heading "Other" "m1" ":IW_ESSAYS: 1")))))

(ert-deftest org-iw-cmd-test-add-shared-id-refusal-order ()
  "An excluded property wins over a shared ID, which wins over the limit."
  (org-iw-test-with-corpus `(("a.org" . ,(org-iw-cmd-test--copy
                                          ":IW_ESSAYS: soon"))
                             ("b.org" . ,org-iw-cmd-test--member))
    (org-iw-cmd-test--should-refuse (org-iw-test-marker "a.org" "Copy")
                                    "ESSAYS" "excluded"))
  (org-iw-cmd-test--should-refuse-shared
   `(("a.org" . ,(org-iw-cmd-test--copy))
     ("b.org" . ,(org-iw-test-heading "Member" "m1"
                                      ":IW_ESSAYS: 9007199254740991")))))

;;;; Add: indirect and narrowed buffers (EX-4, RV-001 F-5)

(defun org-iw-cmd-test--should-have-added (marker)
  "Assert Target at MARKER was added to ESSAYS at 2/2 and saved.
The base buffer is unmodified and holds the disk text, which differs
from the original only by the new IW_ESSAYS line."
  (should-not (buffer-modified-p (org-iw-test-base marker)))
  (should (equal (org-iw-test-text marker) (org-iw-test-file-string "a.org")))
  (should (equal (org-iw-test-changed-lines org-iw-cmd-test--target
                                            (org-iw-test-file-string "a.org"))
                 '(nil ":IW_ESSAYS: 3072"))))

(ert-deftest org-iw-cmd-test-add-from-indirect-buffer ()
  "Add works in an indirect buffer, made by `make-indirect-buffer'.
The edit goes through the base buffer, which is saved."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (org-iw-test-call-with-indirect
     (org-iw-test-marker "a.org" "Target")
     (lambda (indirect-marker)
       (should (equal (org-iw-cmd-test--add-at indirect-marker "ESSAYS")
                      "Added to ESSAYS at 2/2 (saved)"))
       (org-iw-cmd-test--should-have-added indirect-marker)))))

(ert-deftest org-iw-cmd-test-add-in-narrowed-buffer ()
  "Add works under `narrow-to-region' and keeps the narrowing.
The base buffer is narrowed to the subtree, and an indirect buffer to
the body alone, leaving the heading line outside."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (with-current-buffer (marker-buffer marker)
        (goto-char marker)
        (narrow-to-region marker (save-excursion (org-end-of-subtree t t)))
        (org-iw-cmd-test--add-at marker "ESSAYS")
        (should (equal (concat (buffer-string) "* Next\nText.\n")
                       (org-iw-test-file-string "a.org"))))
      (org-iw-cmd-test--should-have-added marker)))
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (org-iw-test-call-with-indirect
     (org-iw-test-marker "a.org" "Target")
     (lambda (indirect-marker)
       (goto-char (point-min))
       (search-forward "Body.")
       (narrow-to-region (line-beginning-position) (line-end-position))
       (org-iw-add "ESSAYS")
       (should (equal (buffer-string) "Body."))
       (org-iw-cmd-test--should-have-added indirect-marker)))))

;;;; Messages

(ert-deftest org-iw-cmd-test-add-counts-source-problems ()
  "The message counts the scan's problems; with none there is no count.
Without problems, see `org-iw-cmd-test-add-appends'."
  (org-iw-test-with-corpus
      `(,@org-iw-cmd-test--corpus
        ("c.org" . ,(org-iw-test-heading "No ID" nil ":IW_ESSAYS: 1")))
    (should (equal (org-iw-cmd-test--add "a.org" "Target" "ESSAYS")
                   "Added to ESSAYS at 2/2 (saved) [1 source problems ignored]"))))

;;;; Queue completion (EX-2, DEC-002)

(ert-deftest org-iw-cmd-test-read-queue-offers-known-queues ()
  "Completion offers configured and discovered queues, names annotated.
Invalid configured IDs are dropped; a new queue may be typed."
  (let ((text (concat (org-iw-test-heading "E" "e1" ":IW_ESSAYS: 1")
                      (org-iw-test-heading "D" "d1" ":IW_drafts: 1"))))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((org-iw-queues '(("essays" :name "Essays") ("Ideas" :name "Ideas")
                             ("bad_id" :name "Bad"))))
        (org-iw-cmd-test--with-prompt "new-queue"
          (should (equal (org-iw--read-queue (org-iw--scan)) "new-queue"))
          (pcase-let* ((`(,call) org-iw-cmd-test--prompts)
                       (annotate (plist-get call :annotate)))
            (should (equal (plist-get call :collection)
                           '("DRAFTS" "ESSAYS" "IDEAS")))
            (should-not (plist-get call :require-match))
            (should (string-search "Essays" (funcall annotate "ESSAYS")))
            (should-not (funcall annotate "DRAFTS"))))))))

(ert-deftest org-iw-cmd-test-add-interactively ()
  "Called interactively, Add prompts for the queue and adds the heading."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-cmd-test--with-prompt "essays"
        (with-current-buffer (marker-buffer marker)
          (goto-char marker)
          (call-interactively #'org-iw-add)))
      (should (equal (org-iw-cmd-test--order "ESSAYS") '("m1" "t1"))))))

;;;; Session and mode line (VT-1, DEC-005)

(defun org-iw-cmd-test--session (queue title)
  "Return a session in QUEUE on an entry titled TITLE, ID x1."
  (org-iw--session-create :queue queue :id "x1" :title title))

(ert-deftest org-iw-cmd-test-mode-line-escapes-percent ()
  "`org-iw--mode-line' shows the queue name and title, % escaped as %%.
A trailing space separates it from the next mode-line item."
  (let ((org-iw-queues '(("essays" :name "50% Club")))
        (org-iw--session (org-iw-cmd-test--session "ESSAYS" "100% done")))
    (should (equal (org-iw--mode-line) "IW[50%% Club: 100%% done] "))))

(ert-deftest org-iw-cmd-test-mode-line-unconfigured-queue ()
  "An unconfigured queue is shown by its ID."
  (let ((org-iw-queues nil)
        (org-iw--session (org-iw-cmd-test--session "ESSAYS" "A")))
    (should (equal (org-iw--mode-line) "IW[ESSAYS: A] "))))

(ert-deftest org-iw-cmd-test-mode-line-without-session ()
  "Without a session the mode line shows nothing."
  (let ((org-iw--session nil))
    (should-not (org-iw--mode-line))))

;;;; Visit (EX-1)

(defconst org-iw-cmd-test--a-file
  (concat (org-iw-test-org "* Other" "Other text.")
          (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1024")
          (org-iw-test-org "A body."))
  "A non-member heading Other, then A, in ESSAYS at 1024.")

(defconst org-iw-cmd-test--b-file
  (concat (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 2048")
          (org-iw-test-heading "C" "c1" ":IW_ESSAYS: 3072"))
  "B and C, in ESSAYS at 2048 and 3072.")

(defconst org-iw-cmd-test--queue
  `(("a.org" . ,org-iw-cmd-test--a-file)
    ("b.org" . ,org-iw-cmd-test--b-file)
    ("d.org" . ,(org-iw-test-heading "D" "d1" ":IW_DRAFTS: 1")))
  "ESSAYS holds A (a.org), B and C (b.org), in that order.
DRAFTS holds D (d.org).")

(defconst org-iw-cmd-test--problem
  (cons "c.org" (org-iw-test-heading "No ID" nil ":IW_ESSAYS: 1"))
  "A file whose heading is in ESSAYS but has no ID: one problem.")

(defun org-iw-cmd-test--entry (scan id)
  "Return the entry of SCAN with ID."
  (seq-find (lambda (entry) (equal (org-iw-entry-id entry) id))
            (org-iw-scan-entries scan)))

(defun org-iw-cmd-test--visit (id &optional scan)
  "Visit the entry ID as 1/3 of ESSAYS, from SCAN or a fresh scan.
Return the message."
  (let ((scan (or scan (org-iw--scan))))
    (org-iw--visit scan (org-iw-cmd-test--entry scan id) "ESSAYS" 1 3)))

(defun org-iw-cmd-test--shown ()
  "Return (BUFFER HEADING) for the selected window.
BUFFER is the corpus-relative file shown, or the buffer's name if it
has no file; HEADING the title of the heading at its point, or nil if
point is not at a heading."
  (with-current-buffer (window-buffer (selected-window))
    (save-excursion
      (goto-char (window-point))
      (list (if buffer-file-name
                (file-relative-name buffer-file-name org-iw-test-dir)
              (buffer-name))
            (and (derived-mode-p 'org-mode)
                 (org-at-heading-p)
                 (org-get-heading t t t t))))))

(defun org-iw-cmd-test--session-id ()
  "Return the ID of the session's entry, or nil without a session."
  (and org-iw--session (org-iw--session-id org-iw--session)))

(defun org-iw-cmd-test--body-hidden-p (name text)
  "Return non-nil if TEXT in corpus file NAME's buffer is invisible."
  (with-current-buffer (org-iw-test-visit name)
    (org-with-wide-buffer
     (goto-char (point-min))
     (search-forward text)
     (invisible-p (match-beginning 0)))))

(ert-deftest org-iw-cmd-test-visit-navigates-and-reveals ()
  "Visit shows the entry's buffer in the selected window, at its heading.
A folded entry is revealed, body included."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (with-current-buffer (org-iw-test-visit "a.org")
      (org-overview))
    (should (org-iw-cmd-test--body-hidden-p "a.org" "A body."))
    (org-iw-cmd-test--visit "a1")
    (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
    (should-not (invisible-p (window-point)))
    (should-not (org-iw-cmd-test--body-hidden-p "a.org" "A body."))))

(ert-deftest org-iw-cmd-test-visit-sets-session ()
  "Visit sets the session and shows it once in `global-mode-string'."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--visit "a1")
    (org-iw-cmd-test--visit "b1")
    (should (equal (list (org-iw--session-queue org-iw--session)
                         (org-iw--session-id org-iw--session)
                         (org-iw--session-title org-iw--session))
                   '("ESSAYS" "b1" "B")))
    (should (equal (cl-count org-iw--mode-line-construct global-mode-string
                             :test #'equal)
                   1))))

(ert-deftest org-iw-cmd-test-visit-message ()
  "Visit echoes and returns IW NAME POS/TOTAL: TITLE, counting problems.
The total is the size of the queue visited."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((org-iw-queues '(("essays" :name "Essays"))))
      (should (equal (org-iw-visit-next "essays") "IW Essays 1/3: A")))
    (should (equal (org-iw-visit-next "drafts") "IW DRAFTS 1/1: D")))
  (org-iw-test-with-corpus `(,@org-iw-cmd-test--queue
                             ,org-iw-cmd-test--problem)
    (should (equal (org-iw-visit-next "ESSAYS")
                   "IW ESSAYS 1/3: A [1 source problems ignored]"))))

(defun org-iw-cmd-test--narrow-to (name title)
  "Narrow corpus file NAME's buffer to the subtree of heading TITLE.
Return the buffer."
  (let ((marker (org-iw-test-marker name title)))
    (with-current-buffer (marker-buffer marker)
      (goto-char marker)
      (narrow-to-region marker (save-excursion (org-end-of-subtree t t)))
      (current-buffer))))

(ert-deftest org-iw-cmd-test-visit-widens-only-to-reach-entry ()
  "A narrowing that hides the entry is removed; one showing it is kept.
Narrowed to the previous subtree, the entry's heading starts at the
end of the accessible text, so it is hidden."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((buffer (org-iw-cmd-test--narrow-to "a.org" "Other")))
      (org-iw-cmd-test--visit "a1")
      (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
      (should-not (with-current-buffer buffer (buffer-narrowed-p)))))
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let* ((buffer (org-iw-cmd-test--narrow-to "a.org" "A"))
           (text (with-current-buffer buffer (buffer-string))))
      (org-iw-cmd-test--visit "a1")
      (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
      (should (equal (with-current-buffer buffer (buffer-string)) text)))))

(ert-deftest org-iw-cmd-test-visit-refusal-changes-nothing ()
  "A refused resolve leaves the session and the selected window alone.
The ID is copied after the scan, so resolve finds it ambiguous."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--visit "b1")
    (let ((session org-iw--session)
          (scan (org-iw--scan)))
      (with-current-buffer (org-iw-test-visit "a.org")
        (goto-char (point-min))
        (forward-line 1)
        (insert ":PROPERTIES:\n:ID: a1\n:END:\n"))
      (should (string-search
               "ambiguous"
               (cadr (should-error (org-iw-cmd-test--visit "a1" scan)
                                   :type 'org-iw-refusal))))
      (should (eq org-iw--session session))
      (should (equal (org-iw-cmd-test--shown) '("b.org" "B"))))))

;;;; Visit next (EX-2, VT-1, I1)

(defun org-iw-cmd-test--open-all ()
  "Visit every source file, so that a state compares every buffer."
  (mapc #'find-file-noselect (org-iw--files)))

(defun org-iw-cmd-test--should-change-nothing (fn)
  "Call FN and assert it changed nothing; return its value.
Nothing is the corpus state (see `org-iw-test-state'), the session
and what the selected window shows."
  (let ((state (org-iw-test-state))
        (session org-iw--session)
        (shown (org-iw-cmd-test--shown)))
    (prog1 (funcall fn)
      (should (equal (org-iw-test-state) state))
      (should (eq org-iw--session session))
      (should (equal (org-iw-cmd-test--shown) shown)))))

(defun org-iw-cmd-test--should-refuse-cleanly (substring fn)
  "Assert FN refuses with SUBSTRING and changes nothing.
The refusal must be an `org-iw-refusal'.  Return its message."
  (let ((reason (cadr (org-iw-cmd-test--should-change-nothing
                       (lambda ()
                         (should-error (funcall fn)
                                       :type 'org-iw-refusal))))))
    (should (string-search substring reason))
    reason))

(ert-deftest org-iw-cmd-test-visit-next-writes-nothing ()
  "`org-iw-visit-next' changes nothing and repeats the same entry (I1)."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (let ((state (org-iw-test-state)))
      (dotimes (_ 2)
        (should (equal (org-iw-visit-next "essays") "IW ESSAYS 1/3: A"))
        (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
        (should (equal (org-iw-cmd-test--session-id) "a1")))
      (should (equal (org-iw-test-state) state)))))

(ert-deftest org-iw-cmd-test-visit-next-opens-file-cleanly ()
  "A file `org-iw-visit-next' opens is unmodified; no disk changes (I1)."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((state (org-iw-test-state)))
      (org-iw-visit-next "ESSAYS")
      (should-not (buffer-modified-p (get-file-buffer
                                      (org-iw-test-path "a.org"))))
      (should (equal (seq-take (org-iw-test-state) (length state)) state)))))

(ert-deftest org-iw-cmd-test-visit-next-uses-session-queue ()
  "Interactively, with a session, the session's queue is used unasked."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "drafts")
    (org-iw-cmd-test--with-prompt nil
      (should (equal (call-interactively #'org-iw-visit-next)
                     "IW DRAFTS 1/1: D")))))

(ert-deftest org-iw-cmd-test-visit-next-prompts ()
  "Interactively, a prefix argument or no session prompts for the queue."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--with-prompt "essays"
      (should (equal (call-interactively #'org-iw-visit-next)
                     "IW ESSAYS 1/3: A"))
      (should (equal (length org-iw-cmd-test--prompts) 1)))
    (org-iw-cmd-test--with-prompt "drafts"
      (let ((current-prefix-arg '(4)))
        (should (equal (call-interactively #'org-iw-visit-next)
                       "IW DRAFTS 1/1: D")))
      (should (equal (length org-iw-cmd-test--prompts) 1)))
    (should (equal (org-iw--session-queue org-iw--session) "DRAFTS"))))

(ert-deftest org-iw-cmd-test-visit-next-refuses-non-org-buffer ()
  "A queue whose head is in a non-Org buffer is refused; no session (F-3)."
  (org-iw-test-with-corpus `(("a.txt" . ,org-iw-cmd-test--member))
    (let ((org-iw-sources (list (org-iw-test-path "a.txt"))))
      (org-iw-cmd-test--open-all)
      (org-iw-cmd-test--should-refuse-cleanly
       "buffer not in Org mode" (lambda () (org-iw-visit-next "ESSAYS")))
      (should-not org-iw--session))))

(ert-deftest org-iw-cmd-test-visit-next-refuses-invalid-queue ()
  "A typed queue ID that is not valid is refused; nothing changes."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--should-refuse-cleanly
     "invalid queue ID \"ess_ays\""
     (lambda () (org-iw-visit-next "ess_ays")))))

(ert-deftest org-iw-cmd-test-visit-next-empty-queue ()
  "An empty queue is reported; nothing changes, the session included."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((org-iw-queues '(("ideas" :name "Ideas"))))
      (org-iw-cmd-test--open-all)
      (org-iw-visit-next "ESSAYS")
      (should (equal (org-iw-cmd-test--should-change-nothing
                      (lambda () (org-iw-visit-next "ideas")))
                     "Queue Ideas is empty")))))

(ert-deftest org-iw-cmd-test-visit-next-widens ()
  "A buffer narrowed with `narrow-to-region' away from the entry is widened."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((buffer (org-iw-cmd-test--narrow-to "a.org" "Other")))
      (org-iw-visit-next "ESSAYS")
      (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
      (should-not (with-current-buffer buffer (buffer-narrowed-p))))))

(ert-deftest org-iw-cmd-test-visit-next-narrowed-to-later-subtree ()
  "A buffer narrowed to a later subtree is widened to reach the entry."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1")
                            (org-iw-test-org "* Later" "Text."))))
    (let ((marker (org-iw-test-marker "a.org" "Later")))
      (with-current-buffer (marker-buffer marker)
        (narrow-to-region marker (point-max))))
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))))

(ert-deftest org-iw-cmd-test-visit-next-reveals-nested-folded-entry ()
  "An entry under a folded parent is made visible when visited."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-org "* Parent" "Parent text.")
                            "*" (org-iw-test-heading
                                 "Child" "c1" ":IW_ESSAYS: 1")
                            (org-iw-test-org "Child body."))))
    (with-current-buffer (org-iw-test-visit "a.org")
      (org-overview))
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-iw-cmd-test--shown) '("a.org" "Child")))
    (with-current-buffer (window-buffer (selected-window))
      (should-not (invisible-p (window-point))))))

;;;; End session (EX-1, VT-1)

(ert-deftest org-iw-cmd-test-end-session-clears ()
  "`org-iw-end-session' clears the session and its mode-line item.
Other `global-mode-string' items stay; a second call is harmless."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (setq global-mode-string (list "x"))
    (org-iw-visit-next "ESSAYS")
    (should (equal global-mode-string
                   (list org-iw--mode-line-construct "x")))
    (should (equal (org-iw-end-session) "org-iw session ended"))
    (should-not org-iw--session)
    (should (equal global-mode-string '("x")))
    (should (equal (org-iw-end-session) "No org-iw session"))
    (should (equal global-mode-string '("x")))))

(ert-deftest org-iw-cmd-test-mode-line-item-with-non-list-global-mode-string ()
  "A bare-string or nil `global-mode-string' takes and sheds our item.
The string is kept as a one-element list; repeated cycles add one item."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (setq global-mode-string "user")
    (dotimes (_ 2)
      (org-iw-visit-next "ESSAYS")
      (should (member org-iw--mode-line-construct global-mode-string))
      (should (member "user" global-mode-string))
      (should (= 1 (cl-count org-iw--mode-line-construct
                             global-mode-string :test #'equal)))
      (org-iw-end-session)
      (should-not (member org-iw--mode-line-construct global-mode-string))
      (should (member "user" global-mode-string)))
    (setq global-mode-string nil)
    (org-iw-visit-next "ESSAYS")
    (should (equal global-mode-string (list org-iw--mode-line-construct)))
    (org-iw-end-session)
    (should-not global-mode-string)))

;;;; Continue to End (EX-3, VT-2, I2, I3)

(defun org-iw-cmd-test--disks ()
  "Return an alist (NAME . CONTENTS) of the corpus files on disk."
  (mapcar (lambda (file)
            (cons (file-relative-name file org-iw-test-dir)
                  (org-iw-test-file-string file)))
          (org-iw--files)))

(defun org-iw-cmd-test--should-move (fn file from to)
  "Call FN; assert on disk it changed only FILE's IW_ESSAYS FROM to TO.
FROM and TO are ranks.  Return FN's value."
  (let ((before (org-iw-cmd-test--disks)))
    (prog1 (funcall fn)
      (let ((after (org-iw-cmd-test--disks)))
        (should (equal (assoc-delete-all file (copy-sequence after))
                       (assoc-delete-all file (copy-sequence before))))
        (should (equal (org-iw-test-changed-lines
                        (alist-get file before nil nil #'equal)
                        (alist-get file after nil nil #'equal))
                       `((,(format ":IW_ESSAYS: %d" from))
                         ,(format ":IW_ESSAYS: %d" to))))))))

(defun org-iw-cmd-test--set-rank (name from to)
  "Change IW_ESSAYS FROM to TO in corpus file NAME's buffer, unsaved."
  (with-current-buffer (org-iw-test-visit name)
    (org-with-wide-buffer
     (goto-char (point-min))
     (search-forward (format ":IW_ESSAYS: %d" from))
     (replace-match (format ":IW_ESSAYS: %d" to) t t))))

(ert-deftest org-iw-cmd-test-continue-moves-to-end ()
  "`org-iw-continue' changes one line in one file and visits the next (I2)."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-iw-cmd-test--should-move #'org-iw-continue
                                                 "a.org" 1024 4096)
                   "Moved A to end (saved). Now 1/3: B"))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))
    (should (equal (org-iw-cmd-test--session-id) "b1"))
    (should (equal (org-iw-cmd-test--order "ESSAYS") '("b1" "c1" "a1")))))

(ert-deftest org-iw-cmd-test-continue-ignores-point ()
  "Continue moves the session's entry, not the one at point (I3)."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (let ((c (org-iw-test-marker "b.org" "C")))
      (pop-to-buffer-same-window (marker-buffer c))
      (goto-char c))
    (org-iw-cmd-test--should-move #'org-iw-continue "a.org" 1024 4096)
    (should (equal (org-iw-cmd-test--order "ESSAYS") '("b1" "c1" "a1")))))

(ert-deftest org-iw-cmd-test-continue-ignores-new-front ()
  "Continue moves the session's entry when another became the front.
C, in another file, is re-ranked first in its unsaved buffer; A goes
after B, the last of the rest, C is visited, and b.org is not saved."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--set-rank "b.org" 3072 1)
    (should (equal (org-iw-cmd-test--should-move #'org-iw-continue
                                                 "a.org" 1024 3072)
                   "Moved A to end (saved). Now 1/3: C"))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "C")))
    (should (buffer-modified-p (org-iw-test-visit "b.org")))
    (should (equal (org-iw-test-file-string "b.org")
                   org-iw-cmd-test--b-file))))

(ert-deftest org-iw-cmd-test-continue-full-cycle ()
  "Three Continues from A come back to A, one line in one file each."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--should-move #'org-iw-continue "a.org" 1024 4096)
    (org-iw-cmd-test--should-move #'org-iw-continue "b.org" 2048 5120)
    (org-iw-cmd-test--should-move #'org-iw-continue "b.org" 3072 6144)
    (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
    (should (equal (org-iw-cmd-test--session-id) "a1"))))

(ert-deftest org-iw-cmd-test-continue-after-buffer-killed ()
  "Continue works when the session entry's buffer was killed."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (kill-buffer (org-iw-test-visit "a.org"))
    (org-iw-cmd-test--should-move #'org-iw-continue "a.org" 1024 4096)
    (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))))

;;;; Continue: refusals and short cuts (EX-3, EX-5, VT-2)

(ert-deftest org-iw-cmd-test-continue-refuses-without-session ()
  "Without a session, Continue refuses before scanning."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (cl-letf (((symbol-function 'org-iw--scan)
               (lambda () (ert-fail "Scanned"))))
      (org-iw-cmd-test--should-refuse-cleanly "no session" #'org-iw-continue))))

(defun org-iw-cmd-test--delete-in-a (regexp)
  "Delete the text REGEXP matches in a.org's buffer, leaving it unsaved."
  (with-current-buffer (org-iw-test-visit "a.org")
    (org-with-wide-buffer
     (goto-char (point-min))
     (re-search-forward regexp)
     (replace-match ""))))

(ert-deftest org-iw-cmd-test-continue-refuses-removed-entry ()
  "An entry that left the queue, or was deleted, is not in queue order.
Continue refuses, writing and visiting nothing."
  (dolist (regexp '("^:IW_ESSAYS: 1024\n" "^\\* A\n\\(?:.*\n\\)*"))
    (org-iw-test-with-corpus org-iw-cmd-test--queue
      (org-iw-cmd-test--open-all)
      (org-iw-visit-next "ESSAYS")
      (org-iw-cmd-test--delete-in-a regexp)
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "no longer in queue" #'org-iw-continue)
                     "A is no longer in queue ESSAYS")))))

(ert-deftest org-iw-cmd-test-continue-refuses-duplicated-id ()
  "A same-file copy of the entry's ID makes Continue refuse (RV-001 F-1).
The copy is on a heading outside the queue; the scan excludes the ID.
Nothing is written: a.org's buffer and every file are unchanged."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (with-current-buffer (org-iw-test-visit "a.org")
      (goto-char (point-max))
      (insert (org-iw-test-heading "Copy" "a1")))
    (should (equal (org-iw-cmd-test--should-refuse-cleanly
                    "duplicated" #'org-iw-continue)
                   "ID a1 is duplicated; A not moved"))))

(ert-deftest org-iw-cmd-test-continue-only-entry ()
  "The only entry in a queue is left in place and stays the session's."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "DRAFTS")
    (should (equal (org-iw-cmd-test--should-change-nothing #'org-iw-continue)
                   "D is the only entry in queue DRAFTS"))))

(ert-deftest org-iw-cmd-test-continue-empty-queue ()
  "A session whose queue was emptied is reported, changing nothing."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "DRAFTS")
    (with-current-buffer (org-iw-test-visit "d.org")
      (org-with-wide-buffer
       (goto-char (point-min))
       (re-search-forward "^:IW_DRAFTS: 1\n")
       (replace-match "")))
    (should (equal (org-iw-cmd-test--should-change-nothing #'org-iw-continue)
                   "Queue DRAFTS is empty"))))

(ert-deftest org-iw-cmd-test-continue-already-last ()
  "An entry already last is not written; the head of the rest is visited.
B and C are re-ranked before A in b.org's unsaved buffer."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--set-rank "b.org" 2048 1)
    (org-iw-cmd-test--set-rank "b.org" 3072 2)
    (let ((state (org-iw-test-state)))
      (should (equal (org-iw-continue) "A already at end. Now 1/3: B"))
      (should (equal (org-iw-test-state) state)))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))
    (should (equal (org-iw-cmd-test--session-id) "b1"))))

(ert-deftest org-iw-cmd-test-continue-refuses-at-rank-limit ()
  "Continue refuses when the last rank leaves no room below the limit."
  (org-iw-test-with-corpus
      `(("a.org" . ,org-iw-cmd-test--a-file)
        ("b.org" . ,(org-iw-test-heading "B" "b1"
                                         ":IW_ESSAYS: 9007199254740991")))
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-iw-cmd-test--should-refuse-cleanly
                    "no room at the end in ESSAYS" #'org-iw-continue)
                   org-iw-cmd-test--no-room-at-end))))

(ert-deftest org-iw-cmd-test-continue-refuses-read-only-buffer ()
  "Continue refuses when the session entry's buffer is read-only (RV-002 F-1).
Nothing is written or visited, and the session is unchanged."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (with-current-buffer (org-iw-test-visit "a.org")
      (read-only-mode 1))
    (org-iw-cmd-test--should-refuse-cleanly "buffer is read-only"
                                            #'org-iw-continue)))

(ert-deftest org-iw-cmd-test-continue-propagates-write-refusal ()
  "A refusal from the write, here a file changed on disk, is passed on.
Nothing is written or visited, and the session is unchanged."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (org-iw-test-rewrite-behind "a.org" (concat org-iw-cmd-test--a-file
                                                "* Added outside\n"))
    (org-iw-cmd-test--should-refuse-cleanly "changed on disk"
                                            #'org-iw-continue)))

;;;; Continue: save status and problems (EX-4, VT-3, I5)

(ert-deftest org-iw-cmd-test-continue-leaves-dirty-buffer-unsaved ()
  "A visited entry edited and left unsaved is moved but not saved.
The corpus is a directory source and the edit's lock file is present
\(RV-001 F-3); the disk is unchanged (I5) and B is visited."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (org-iw-test-edit-elsewhere (org-iw-test-marker "a.org" "A"))
    (should (file-symlink-p (org-iw-test-path ".#a.org")))
    (should (string-search "queue change not saved" (org-iw-continue)))
    (should (equal (org-iw-test-file-string "a.org") org-iw-cmd-test--a-file))
    (with-current-buffer (org-iw-test-visit "a.org")
      (should (buffer-modified-p))
      (should (string-search ":IW_ESSAYS: 4096" (buffer-string))))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))))

(ert-deftest org-iw-cmd-test-continue-counts-source-problems ()
  "Continue's message counts the scan's problems."
  (org-iw-test-with-corpus `(,@org-iw-cmd-test--queue
                             ,org-iw-cmd-test--problem)
    (org-iw-visit-next "ESSAYS")
    (let ((message (org-iw-continue)))
      (should (string-search "source problems ignored" message))
      (should (equal message (concat "Moved A to end (saved). Now 1/3: B"
                                     " [1 source problems ignored]"))))))

(ert-deftest org-iw-cmd-test-continue-reports-failed-save ()
  "A failing save is reported; the edit stands and B is still visited."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (let ((write-file-functions (list (lambda () (error "Disk full")))))
      (should (equal (org-iw-continue)
                     (concat "Moved A to end (queue change applied but not"
                             " saved: Disk full). Now 1/3: B"))))
    (should (buffer-modified-p (org-iw-test-visit "a.org")))
    (should (equal (org-iw-test-file-string "a.org") org-iw-cmd-test--a-file))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))))

(provide 'org-iw-test)
;;; org-iw-test.el ends here
