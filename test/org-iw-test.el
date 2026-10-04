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
;; mode line, `org-iw-visit-next', `org-iw-continue', `org-iw-move',
;; `org-iw-end-session', `org-iw-remove', the queue view
;; (`org-iw-list-queue' and its commands), and the private helpers the
;; commands share.
;; Every prompt is stubbed, so that no test reads from standard input.

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-iw-test-helpers)
(require 'org-iw)

;;;; Helpers

(defun org-iw-cmd-test--call-at (marker fn &rest args)
  "Apply FN to ARGS in MARKER's buffer with point at MARKER; return its value.
A confirmation prompt fails the test.  To call a command
interactively, FN is `call-interactively' and ARGS the command."
  (cl-letf (((symbol-function 'y-or-n-p)
             (lambda (&rest _) (ert-fail "y-or-n-p")))
            ((symbol-function 'yes-or-no-p)
             (lambda (&rest _) (ert-fail "yes-or-no-p"))))
    (with-current-buffer (marker-buffer marker)
      (goto-char marker)
      (apply fn args))))

(defun org-iw-cmd-test--add (name title queue &optional label)
  "Add the heading TITLE of corpus file NAME to QUEUE at LABEL.
Return the result."
  (org-iw-cmd-test--call-at (org-iw-test-marker name title)
                            #'org-iw-add queue label))

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
  "Run BODY with `completing-read' and `y-or-n-p' stubbed to answer from ANSWER.
ANSWER is one answer, or a list answering successive prompts of either
kind.  A `completing-read' answer is a string; a `y-or-n-p' answer is
:yes or :no, since nil would read as no answer left.  A prompt with no
answer left fails the test, so ANSWER nil proves BODY never prompts,
as does an answer of the wrong kind, or one that is not a candidate
when REQUIRE-MATCH is t.  Each call is recorded, in order, in
`org-iw-cmd-test--prompts' as a plist: (:prompt :collection
:require-match :default :order :annotate) for `completing-read',
:order being `org-iw-cmd-test--cycle-order', and (:prompt) for
`y-or-n-p'."
  (declare (indent 1) (debug t))
  (let ((answers (make-symbol "answers"))
        (reply (make-symbol "reply")))
    `(let ((org-iw-cmd-test--prompts nil)
           (,answers (ensure-list ,answer)))
       (cl-flet ((,reply (call valid-p)
                   (setq org-iw-cmd-test--prompts
                         (append org-iw-cmd-test--prompts (list call)))
                   (let* ((prompt (plist-get call :prompt))
                          (reply (or (pop ,answers)
                                     (ert-fail (list "Unexpected prompt"
                                                     prompt)))))
                     (unless (funcall valid-p reply)
                       (ert-fail (list "Answer of the wrong kind" prompt
                                       reply)))
                     reply)))
         (cl-letf (((symbol-function 'completing-read)
                    (lambda (prompt collection &optional predicate
                                    require-match _initial _hist default
                                    &rest _)
                      (let ((reply
                             (,reply
                              (list :prompt prompt :collection collection
                                    :require-match require-match
                                    :default default
                                    :order (org-iw-cmd-test--cycle-order
                                            collection predicate)
                                    :annotate (plist-get
                                               completion-extra-properties
                                               :annotation-function))
                              #'stringp)))
                        (when (and (eq require-match t)
                                   (not (test-completion reply collection
                                                         predicate)))
                          (ert-fail (list "Answer must match" prompt reply)))
                        reply)))
                   ((symbol-function 'y-or-n-p)
                    (lambda (prompt)
                      (eq (,reply (list :prompt prompt)
                                  (lambda (reply) (memq reply '(:yes :no))))
                          :yes))))
           ,@body)))))

(defun org-iw-cmd-test--prompted (key)
  "Return the value of KEY in each recorded prompt, in order."
  (mapcar (lambda (call) (plist-get call key)) org-iw-cmd-test--prompts))

(ert-deftest org-iw-cmd-test-with-prompt-self-test ()
  "The prompt recorder answers in turn, records, and fails when out.
Under REQUIRE-MATCH t it fails an answer that is not a candidate.
`y-or-n-p' takes :yes or :no, and `completing-read' only a string."
  (org-iw-cmd-test--with-prompt '("y" "b")
    (should (equal (completing-read "One: " '("y" "x") nil t nil nil "x") "y"))
    (should (equal (completing-read "Two: " '("z")) "b"))
    (should (equal (org-iw-cmd-test--prompted :prompt) '("One: " "Two: ")))
    (pcase-let ((`(,one ,two) org-iw-cmd-test--prompts))
      (should (equal (plist-get one :default) "x"))
      (should (eq (plist-get one :require-match) t))
      (should (equal (plist-get one :order) '("x" "y")))
      (should-not (plist-get two :default)))
    (should-error (completing-read "Three: " '("w")) :type 'ert-test-failed))
  (org-iw-cmd-test--with-prompt nil
    (should-error (completing-read "Any: " '("w")) :type 'ert-test-failed))
  (org-iw-cmd-test--with-prompt '("new" "new")
    (should-error (completing-read "Must: " '("w") nil t)
                  :type 'ert-test-failed)
    (should (equal (completing-read "Free: " '("w")) "new")))
  (org-iw-cmd-test--with-prompt '("x" :yes :no)
    (should (equal (completing-read "Pick: " '("x")) "x"))
    (should (eq (y-or-n-p "Sure? ") t))
    (should (eq (y-or-n-p "Really? ") nil))
    (should (equal (org-iw-cmd-test--prompted :prompt)
                   '("Pick: " "Sure? " "Really? "))))
  (org-iw-cmd-test--with-prompt "y"
    (should-error (y-or-n-p "Sure? ") :type 'ert-test-failed))
  (org-iw-cmd-test--with-prompt :yes
    (should-error (completing-read "Pick: " '("x")) :type 'ert-test-failed))
  (org-iw-cmd-test--with-prompt nil
    (should-error (y-or-n-p "Sure? ") :type 'ert-test-failed))
  (let ((table (lambda (string pred action)
                 (if (eq action 'metadata)
                     '(metadata (cycle-sort-function . identity))
                   (complete-with-action action '("b" "a") string pred)))))
    (should (equal (org-iw-cmd-test--cycle-order table nil) '("b" "a")))))

;;;; Private helpers

(defun org-iw-cmd-test--no-room (where)
  "Return the refusal when ESSAYS has no rank left WHERE.
WHERE carries its preposition, as in \"at the end\"."
  (concat "no room " where " in ESSAYS; redistribution is not yet available"))

(defun org-iw-cmd-test--refusal (fn)
  "Call FN, assert it refuses, and return the refusal message."
  (cadr (should-error (funcall fn) :type 'org-iw-refusal)))

(ert-deftest org-iw-cmd-test-refuse-no-room ()
  "No room is refused naming where and the queue, with no advice."
  (should (equal (org-iw-cmd-test--no-room "at the end")
                 (concat "no room at the end in ESSAYS; redistribution is"
                         " not yet available")))
  (dolist (where '("at the end" "at Second" "at position 3/4" "before T"
                  "after T"))
    (should (equal (org-iw-cmd-test--refusal
                    (lambda () (org-iw--refuse-no-room where "ESSAYS")))
                   (org-iw-cmd-test--no-room where)))))

(ert-deftest org-iw-cmd-test-refuse-absent ()
  "An absent entry is refused as duplicated or as gone, naming no act.
The queue is shown by its configured name."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1")
                            (org-iw-test-heading "Copy" "a1"))))
    (let ((org-iw-queues '(("essays" :name "Essays")))
          (scan (org-iw--scan)))
      (should (equal (org-iw-cmd-test--refusal
                      (lambda ()
                        (org-iw--refuse-absent scan "ESSAYS" "a1" "A")))
                     "ID a1 is duplicated; A is excluded from queue Essays"))
      (should (equal (org-iw-cmd-test--refusal
                      (lambda ()
                        (org-iw--refuse-absent scan "ESSAYS" "b1" "B")))
                     "B is no longer in queue Essays")))))

(ert-deftest org-iw-cmd-test-find-entry ()
  "An entry is found by ID, case-sensitively, and by file too when given."
  (let* ((a (org-iw-entry-create :id "x1" :file "/a.org"))
         (b (org-iw-entry-create :id "x1" :file "/b.org"))
         (c (org-iw-entry-create :id "c1" :file "/a.org"))
         (entries (list c a b)))
    (should (eq (org-iw--find-entry entries "x1") a))
    (should (eq (org-iw--find-entry entries "c1") c))
    (should (eq (org-iw--find-entry entries "x1" "/b.org") b))
    (should-not (org-iw--find-entry entries "c1" "/b.org"))
    (should-not (org-iw--find-entry entries "zz"))
    (should-not (org-iw--find-entry entries "X1"))
    (should-not (org-iw--find-entry entries "X1" "/a.org"))
    (should-not (org-iw--find-entry nil "x1"))))

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
         ((:placements (("A" end) . x)) nil "End"
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

(ert-deftest org-iw-cmd-test-vocabulary-reserves-remove ()
  "A label Remove, in any case, refuses, naming the option and the label.
The label is echoed as configured.  A label merely starting with
Remove is allowed."
  (pcase-dolist (`(,options ,placements ,message)
                 '(((:name "Articles" :placements (("Soon" (after 2))
                                                   ("remove" end)))
                    nil
                    "queue Articles :placements: label \"remove\" is reserved")
                   (nil (("Soon" end) ("Remove" end))
                        "org-iw-placements: label \"Remove\" is reserved")
                   (nil (("REMOVE" end))
                        "org-iw-placements: label \"REMOVE\" is reserved")))
    (let ((org-iw-queues (and options (list (cons "articles" options))))
          (org-iw-placements placements)
          (org-iw-default-placement "Soon"))
      (should (equal (cadr (should-error (org-iw--vocabulary "ARTICLES")
                                         :type 'org-iw-refusal))
                     message))))
  (let ((org-iw-placements '(("Removed" end)))
        (org-iw-default-placement nil))
    (should (equal (org-iw--vocabulary "OTHER") '("Removed" ("Removed" end))))))

(ert-deftest org-iw-cmd-test-placement ()
  "A label names its placement; nil names the default's; others refuse."
  (let ((org-iw-queues org-iw-cmd-test--queues))
    (should (equal (org-iw--placement "ARTICLES" "Soon") '("Soon" after 2)))
    (should (equal (org-iw--placement "ARTICLES" nil) '("End" . end)))
    (should (equal (org-iw--placement "OTHER" "Later")
                   '("Later" fraction 1 2)))
    (should (equal (cadr (should-error (org-iw--placement "ARTICLES" "Later")
                                       :type 'org-iw-refusal))
                   "queue Articles has no placement \"Later\""))
    (should (equal (cadr (should-error (org-iw--placement "OTHER" "soon")
                                       :type 'org-iw-refusal))
                   "queue OTHER has no placement \"soon\""))))

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

(ert-deftest org-iw-cmd-test-read-placement-with-remove ()
  "With Remove the chooser offers it last, never as the default.
Choosing it returns the symbol remove; a label is returned as is."
  (let ((org-iw-queues org-iw-cmd-test--queues))
    (pcase-dolist (`(,answer ,result) '(("Remove" remove) ("Soon" "Soon")))
      (org-iw-cmd-test--with-prompt answer
        (should (equal (org-iw--read-placement "ARTICLES" t) result))
        (pcase-let ((`(,call) org-iw-cmd-test--prompts))
          (should (equal (plist-get call :order) '("Soon" "End" "Remove")))
          (should (equal (plist-get call :default) "End"))
          (should (eq (plist-get call :require-match) t)))))))

(ert-deftest org-iw-cmd-test-read-placement-refuses-before-prompting ()
  "Bad config refuses before the chooser prompts, with Remove or without."
  (let ((org-iw-queues '(("ARTICLES" :placements nil))))
    (org-iw-cmd-test--with-prompt nil
      (dolist (with-remove '(nil t))
        (should-error (org-iw--read-placement "ARTICLES" with-remove)
                      :type 'org-iw-refusal)))))

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
        (should (equal (org-iw-cmd-test--call-at marker #'org-iw-add "ESSAYS")
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
                             (org-iw-cmd-test--call-at marker
                                                       #'org-iw-add "ESSAYS")))
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
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (should (equal (org-iw-cmd-test--should-change-nothing
                      (lambda ()
                        (org-iw-cmd-test--call-at
                         marker #'org-iw-add "ESSAYS")))
                     "Already in ESSAYS at 2/3")))))

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
See `org-iw-cmd-test--should-refuse-cleanly'.  Return the refusal
message."
  (org-iw-cmd-test--should-refuse-cleanly
   substring (lambda () (org-iw-cmd-test--call-at marker #'org-iw-add queue))))

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
        (org-iw-cmd-test--call-at marker #'org-iw-add "ESSAYS")
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
   "ESSAYS" (org-iw-cmd-test--no-room "at the end") "H"))

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

;;;; Target at point

(defun org-iw-cmd-test--narrow-to-line (text)
  "Narrow the current buffer to the line holding TEXT, point on it."
  (goto-char (point-min))
  (search-forward text)
  (narrow-to-region (line-beginning-position) (line-end-position)))

(ert-deftest org-iw-cmd-test-target-at-point-document ()
  "Before the first heading the target is the document: the wide start.
Narrowing to the second line of the preamble does not move it."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-org "#+title: T" "Intro." "* H")))
    (with-current-buffer (org-iw-test-visit "a.org")
      (org-iw-cmd-test--narrow-to-line "Intro.")
      (let ((target (org-iw--target-at-point)))
        (should (eq (marker-buffer target) (current-buffer)))
        (should (= target 1))
        (should (org-with-point-at target (org-before-first-heading-p)))))))

(ert-deftest org-iw-cmd-test-add-first-line-heading ()
  "A heading on the first line is a heading, not the document: Add adds it.
Point is in its body, narrowed to that line."
  (let ((text (org-iw-test-org "* H" "Body.")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (with-current-buffer (org-iw-test-visit "a.org")
        (org-iw-cmd-test--narrow-to-line "Body.")
        (should (equal (org-iw-add "ESSAYS") "Added to ESSAYS at 1/1 (saved)")))
      (org-iw-test-should-add-drawer text (org-iw-test-marker "a.org" "H")
                                     "* H"))))

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
       (should (equal (org-iw-cmd-test--call-at indirect-marker
                                                #'org-iw-add "ESSAYS")
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
        (org-iw-cmd-test--call-at marker #'org-iw-add "ESSAYS")
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
          (should (equal (org-iw--read-queue
                          (org-iw--known-queues (org-iw--scan)))
                         "new-queue"))
          (pcase-let* ((`(,call) org-iw-cmd-test--prompts)
                       (annotate (plist-get call :annotate)))
            (should (equal (plist-get call :collection)
                           '("DRAFTS" "ESSAYS" "IDEAS")))
            (should-not (plist-get call :require-match))
            (should (string-search "Essays" (funcall annotate "ESSAYS")))
            (should-not (funcall annotate "DRAFTS"))))))))

(ert-deftest org-iw-cmd-test-read-queue-require-match ()
  "The queue prompt offers the queues given, requiring a match on request."
  (let ((org-iw-queues '(("essays" :name "Essays"))))
    (org-iw-cmd-test--with-prompt "ESSAYS"
      (should (equal (org-iw--read-queue '("ESSAYS" "DRAFTS") t) "ESSAYS"))
      (pcase-let ((`(,call) org-iw-cmd-test--prompts))
        (should (equal (plist-get call :prompt) "Queue: "))
        (should (equal (plist-get call :collection) '("ESSAYS" "DRAFTS")))
        (should (eq (plist-get call :require-match) t))
        (should (string-search "Essays"
                               (funcall (plist-get call :annotate)
                                        "ESSAYS")))))))

(ert-deftest org-iw-cmd-test-add-interactively ()
  "Called interactively, Add prompts for the queue and adds the heading.
The queue prompt does not require a match."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (org-iw-cmd-test--with-prompt "essays"
        (org-iw-cmd-test--call-at marker #'call-interactively #'org-iw-add)
        (should (equal (org-iw-cmd-test--prompted :require-match) '(nil))))
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

(ert-deftest org-iw-cmd-test-visit-window ()
  "Visit uses the selected window, or with OTHER-WINDOW another one.
The other window is selected, and the old one keeps its buffer."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((window (selected-window))
          (count (count-windows))
          (scan (org-iw--scan)))
      (org-iw--visit scan (org-iw-cmd-test--entry scan "a1") "ESSAYS" 1 3)
      (should (eq (selected-window) window))
      (should (equal (count-windows) count))
      (set-window-buffer window (org-iw-test-visit "d.org"))
      (org-iw--visit scan (org-iw-cmd-test--entry scan "a1") "ESSAYS" 1 3 t)
      (should-not (eq (selected-window) window))
      (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
      (should (equal (window-buffer window) (org-iw-test-visit "d.org"))))))

(ert-deftest org-iw-cmd-test-visit-other-window-not-same ()
  "OTHER-WINDOW shows the entry in another window, never the selected one.
That holds even where the buffer would otherwise take the selected one."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let* ((window (selected-window))
           (scan (org-iw--scan))
           (same-window-buffer-names (list "a.org")))
      (set-window-buffer window (org-iw-test-visit "d.org"))
      (org-iw--visit scan (org-iw-cmd-test--entry scan "a1") "ESSAYS" 1 3 t)
      (should-not (eq (selected-window) window))
      (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
      (should (equal (window-buffer window) (org-iw-test-visit "d.org"))))))

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

;;;; Add: placements

(defconst org-iw-cmd-test--eight
  `(("q.org" . ,(mapconcat (lambda (i)
                             (org-iw-test-heading
                              (format "E%d" i) (format "e%d" i)
                              (format ":IW_ESSAYS: %d" (* 1024 i))))
                           (number-sequence 1 8))))
  "E1 to E8, in ESSAYS at 1024 to 8192, so seven others for E1.")

(defconst org-iw-cmd-test--target-and-eight
  `(("a.org" . ,org-iw-cmd-test--target) ,@org-iw-cmd-test--eight)
  "Target, not yet queued, and ESSAYS holding E1 to E8.")

(defun org-iw-cmd-test--add-chosen (marker)
  "Call `org-iw-add' interactively with a prefix argument at MARKER."
  (let ((current-prefix-arg '(4)))
    (org-iw-cmd-test--call-at marker #'call-interactively #'org-iw-add)))

(ert-deftest org-iw-cmd-test-add-at-placement ()
  "Add at Soon ranks the heading 3rd of 9, writing one line."
  (org-iw-test-with-corpus org-iw-cmd-test--target-and-eight
    (should (equal (org-iw-cmd-test--add "a.org" "Target" "essays" "Soon")
                   "Added to ESSAYS at Soon, 3/9 (saved)"))
    (should (equal (org-iw-test-changed-lines
                    org-iw-cmd-test--target (org-iw-test-file-string "a.org"))
                   '(nil ":IW_ESSAYS: 2560")))
    (should (equal (seq-take (org-iw-cmd-test--order "ESSAYS") 3)
                   '("e1" "e2" "t1")))))

(ert-deftest org-iw-cmd-test-add-chooser ()
  "With a prefix argument Add reads the queue, then a placement.
The placement prompt defaults to the queue's default, not to the end."
  (org-iw-test-with-corpus org-iw-cmd-test--target-and-eight
    (let ((org-iw-queues '(("essays" :default "Soon"))))
      (org-iw-cmd-test--with-prompt '("essays" "Later")
        (should (equal (org-iw-cmd-test--add-chosen
                        (org-iw-test-marker "a.org" "Target"))
                       "Added to ESSAYS at Later, 5/9 (saved)"))
        (pcase-let ((`(,queue ,placement) org-iw-cmd-test--prompts))
          (should (equal (plist-get queue :prompt) "Queue: "))
          (should (equal (plist-get placement :prompt) "Placement: "))
          (should (equal (plist-get placement :order) '("Soon" "Later" "End")))
          (should (equal (plist-get placement :default) "Soon")))))))

(ert-deftest org-iw-cmd-test-add-chooser-refuses-before-prompting ()
  "Bad config refuses after the queue prompt, before the placement prompt."
  (org-iw-test-with-corpus org-iw-cmd-test--target-and-eight
    (org-iw-cmd-test--open-all)
    (let ((org-iw-queues '(("essays" :placements nil))))
      (org-iw-cmd-test--with-prompt '("essays")
        (should (equal (cadr (org-iw-cmd-test--should-write-nothing
                              (lambda ()
                                (should-error
                                 (org-iw-cmd-test--add-chosen
                                  (org-iw-test-marker "a.org" "Target"))
                                 :type 'org-iw-refusal))))
                       "queue ESSAYS :placements: no placements"))
        (should (= (length org-iw-cmd-test--prompts) 1))))))

(ert-deftest org-iw-cmd-test-add-plain-appends-whatever-the-default ()
  "Without a label Add appends, even where the queue's default is not End."
  (org-iw-test-with-corpus org-iw-cmd-test--target-and-eight
    (let ((org-iw-queues '(("essays" :default "Soon"))))
      (should (equal (org-iw-cmd-test--add "a.org" "Target" "essays")
                     "Added to ESSAYS at 9/9 (saved)"))
      (should (equal (car (last (org-iw-cmd-test--order "ESSAYS"))) "t1")))))

(ert-deftest org-iw-cmd-test-add-chooser-refuses-invalid-queue-first ()
  "An invalid queue ID refuses before the placement prompt."
  (org-iw-test-with-corpus org-iw-cmd-test--target-and-eight
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--with-prompt '("ess_ays")
      (should (equal (cadr (org-iw-cmd-test--should-write-nothing
                            (lambda ()
                              (should-error
                               (org-iw-cmd-test--add-chosen
                                (org-iw-test-marker "a.org" "Target"))
                               :type 'org-iw-refusal))))
                     "invalid queue ID \"ess_ays\""))
      (should (= (length org-iw-cmd-test--prompts) 1)))))

(ert-deftest org-iw-cmd-test-add-refuses-placement-before-scan ()
  "An unknown label refuses Add before any scan."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (org-iw-cmd-test--open-all)
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (cl-letf (((symbol-function 'org-iw--scan)
                 (lambda () (ert-fail "Scanned"))))
        (should (equal (cadr (org-iw-cmd-test--should-write-nothing
                              (lambda ()
                                (should-error
                                 (org-iw-cmd-test--call-at
                                  marker #'org-iw-add "ESSAYS" "Nope")
                                 :type 'org-iw-refusal))))
                       "queue ESSAYS has no placement \"Nope\""))))))

(ert-deftest org-iw-cmd-test-add-member-at-placement ()
  "A member is left alone at any valid label; an unknown label refuses."
  (org-iw-test-with-corpus org-iw-cmd-test--corpus
    (org-iw-cmd-test--open-all)
    (let ((member (org-iw-test-marker "b.org" "Member")))
      (should (equal (org-iw-cmd-test--should-write-nothing
                      (lambda ()
                        (org-iw-cmd-test--call-at
                         member #'org-iw-add "ESSAYS" "Soon")))
                     "Already in ESSAYS at 1/1"))
      (should (equal (cadr (org-iw-cmd-test--should-write-nothing
                            (lambda ()
                              (should-error
                               (org-iw-cmd-test--call-at
                                member #'org-iw-add "ESSAYS" "Nope")
                               :type 'org-iw-refusal))))
                     "queue ESSAYS has no placement \"Nope\"")))))

(ert-deftest org-iw-cmd-test-add-refuses-without-gap ()
  "Add at a label between neighbours ranked 5 and 6 refuses."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 5")
                            (org-iw-test-heading "C" "c1" ":IW_ESSAYS: 6")
                            (org-iw-test-heading "H" "h1"))))
    (let ((org-iw-queues '(("essays" :placements (("Second" (after 1)))))))
      (org-iw-cmd-test--open-all)
      (should (equal (cadr (org-iw-cmd-test--should-write-nothing
                            (lambda ()
                              (should-error
                               (org-iw-cmd-test--add "a.org" "H" "ESSAYS"
                                                     "Second")
                               :type 'org-iw-refusal))))
                     (org-iw-cmd-test--no-room "at Second"))))))

;;;; Visit next (EX-2, VT-1, I1)

(defun org-iw-cmd-test--open-all ()
  "Visit every source file, so that a state compares every buffer."
  (mapc #'find-file-noselect (org-iw--files)))

(defun org-iw-cmd-test--should-write-nothing (fn)
  "Call FN and assert the corpus state is unchanged; return its value.
See `org-iw-test-state'.  Unlike `org-iw-cmd-test--should-change-nothing',
FN may visit and start a session."
  (let ((state (org-iw-test-state)))
    (prog1 (funcall fn)
      (should (equal (org-iw-test-state) state)))))

(ert-deftest org-iw-cmd-test-should-write-nothing-self-test ()
  "The write-nothing oracle fails on an unsaved edit and on a save."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (should (equal (org-iw-cmd-test--should-write-nothing (lambda () 'x)) 'x))
    (dolist (edit (list (lambda () (insert "x"))
                        (lambda () (insert "x") (save-buffer))))
      (should-error (org-iw-cmd-test--should-write-nothing
                     (lambda ()
                       (with-current-buffer (org-iw-test-visit "d.org")
                         (funcall edit))))
                    :type 'ert-test-failed))))

(defun org-iw-cmd-test--should-change-nothing (fn)
  "Call FN and assert it changed nothing; return its value.
Nothing is the corpus state (see `org-iw-test-state'), the session
and what the selected window shows."
  (let ((session org-iw--session)
        (shown (org-iw-cmd-test--shown)))
    (prog1 (org-iw-cmd-test--should-write-nothing fn)
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

(ert-deftest org-iw-cmd-test-should-refuse-cleanly-self-test ()
  "The clean-refusal oracle fails on a wrong refusal or any change.
That is another refusal, a plain error, an edit, a changed session or
a navigation."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-iw-cmd-test--should-refuse-cleanly
                    "no" (lambda () (org-iw-core-refuse "no way")))
                   "no way"))
    (dolist (fn (list (lambda () (org-iw-core-refuse "other"))
                      (lambda () (error "No"))
                      (lambda ()
                        (with-current-buffer (org-iw-test-visit "d.org")
                          (insert "x"))
                        (org-iw-core-refuse "no"))
                      (lambda ()
                        (setq org-iw--session nil)
                        (org-iw-core-refuse "no"))
                      (lambda ()
                        (pop-to-buffer-same-window (org-iw-test-visit "d.org"))
                        (org-iw-core-refuse "no"))))
      (should-error (org-iw-cmd-test--should-refuse-cleanly "no" fn)
                    :type 'ert-test-failed))))

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
  "Interactively, a prefix argument or no session prompts for the queue.
The queue prompt does not require a match."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--with-prompt "essays"
      (should (equal (call-interactively #'org-iw-visit-next)
                     "IW ESSAYS 1/3: A"))
      (should (equal (org-iw-cmd-test--prompted :require-match) '(nil))))
    (org-iw-cmd-test--with-prompt "drafts"
      (let ((current-prefix-arg '(4)))
        (should (equal (call-interactively #'org-iw-visit-next)
                       "IW DRAFTS 1/1: D")))
      (should (equal (org-iw-cmd-test--prompted :require-match) '(nil))))
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

(defun org-iw-cmd-test--should-change-lines (fn file removed added)
  "Call FN; assert on disk it changed only FILE, lines REMOVED to ADDED.
REMOVED and ADDED are lists of lines, as `org-iw-test-changed-lines'
gives them.  Return FN's value."
  (let ((before (org-iw-cmd-test--disks)))
    (prog1 (funcall fn)
      (let ((after (org-iw-cmd-test--disks)))
        (should (equal (assoc-delete-all file (copy-sequence after))
                       (assoc-delete-all file (copy-sequence before))))
        (should (equal (org-iw-test-changed-lines
                        (alist-get file before nil nil #'equal)
                        (alist-get file after nil nil #'equal))
                       (cons removed added)))))))

(defun org-iw-cmd-test--should-move (fn file from to)
  "Call FN; assert on disk it changed only FILE's IW_ESSAYS FROM to TO.
FROM and TO are ranks.  Return FN's value."
  (org-iw-cmd-test--should-change-lines
   fn file (list (format ":IW_ESSAYS: %d" from))
   (list (format ":IW_ESSAYS: %d" to))))

(defun org-iw-cmd-test--should-delete (fn file line)
  "Call FN; assert on disk it deleted only LINE, of FILE.
Return FN's value."
  (org-iw-cmd-test--should-change-lines fn file (list line) nil))

(ert-deftest org-iw-cmd-test-should-delete-self-test ()
  "The delete oracle fails on no change, another line, or another file."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((delete (lambda (name line)
                    (lambda ()
                      (with-current-buffer (org-iw-test-visit name)
                        (goto-char (point-min))
                        (search-forward (concat line "\n"))
                        (replace-match "")
                        (save-buffer))))))
      (dolist (fn (list #'ignore
                        (funcall delete "b.org" ":IW_ESSAYS: 2048")
                        (funcall delete "a.org" ":ID: a1")))
        (should-error (org-iw-cmd-test--should-delete
                       fn "a.org" ":IW_ESSAYS: 1024")
                      :type 'ert-test-failed))
      (org-iw-cmd-test--should-delete
       (funcall delete "a.org" ":IW_ESSAYS: 1024")
       "a.org" ":IW_ESSAYS: 1024"))))

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
                   "Moved A to End, 3/3 (saved). Now 1/3: B"))
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
                   "Moved A to End, 3/3 (saved). Now 1/3: C"))
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
  "Without a session, Continue refuses before scanning, Remove included."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (cl-letf (((symbol-function 'org-iw--scan)
               (lambda () (ert-fail "Scanned"))))
      (dolist (label '(nil remove))
        (org-iw-cmd-test--should-refuse-cleanly
         "no session" (lambda () (org-iw-continue label)))))))

(defun org-iw-cmd-test--delete-in-a (regexp)
  "Delete the text REGEXP matches in a.org's buffer, leaving it unsaved."
  (with-current-buffer (org-iw-test-visit "a.org")
    (org-with-wide-buffer
     (goto-char (point-min))
     (re-search-forward regexp)
     (replace-match ""))))

(ert-deftest org-iw-cmd-test-continue-refuses-removed-entry ()
  "An entry that left the queue, or was deleted, is not in queue order.
Continue refuses, writing and visiting nothing, Remove included."
  (dolist (regexp '("^:IW_ESSAYS: 1024\n" "^\\* A\n\\(?:.*\n\\)*"))
    (org-iw-test-with-corpus org-iw-cmd-test--queue
      (org-iw-cmd-test--open-all)
      (org-iw-visit-next "ESSAYS")
      (org-iw-cmd-test--delete-in-a regexp)
      (dolist (label '(nil remove))
        (should (equal (org-iw-cmd-test--should-refuse-cleanly
                        "no longer in queue"
                        (lambda () (org-iw-continue label)))
                       "A is no longer in queue ESSAYS"))))))

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
    (dolist (label '(nil remove))
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "duplicated" (lambda () (org-iw-continue label)))
                     "ID a1 is duplicated; A is excluded from queue ESSAYS")))))

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
    (dolist (label '(nil remove))
      (should (equal (org-iw-cmd-test--should-change-nothing
                      (lambda () (org-iw-continue label)))
                     "Queue DRAFTS is empty")))))

(ert-deftest org-iw-cmd-test-continue-already-last ()
  "An entry already last is not written; the head of the rest is visited.
B and C are re-ranked before A in b.org's unsaved buffer."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--set-rank "b.org" 2048 1)
    (org-iw-cmd-test--set-rank "b.org" 3072 2)
    (should (equal (org-iw-cmd-test--should-write-nothing #'org-iw-continue)
                   "A already at End, 3/3. Now 1/3: B"))
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
                    "no room at End" #'org-iw-continue)
                   (org-iw-cmd-test--no-room "at End")))))

(ert-deftest org-iw-cmd-test-continue-refuses-without-gap ()
  "Between neighbours ranked 5 and 6 there is no room: nothing changes (I9)."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1"))
        ("b.org" . ,(concat (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 5")
                            (org-iw-test-heading "C" "c1" ":IW_ESSAYS: 6"))))
    (let ((org-iw-queues '(("essays" :placements (("Second" (after 1)))))))
      (org-iw-cmd-test--open-all)
      (org-iw-visit-next "ESSAYS")
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "no room" #'org-iw-continue)
                     (org-iw-cmd-test--no-room "at Second"))))))

(ert-deftest org-iw-cmd-test-continue-refuses-read-only-buffer ()
  "Continue refuses when the session entry's buffer is read-only (RV-002 F-1).
Nothing is written or visited, and the session is unchanged."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (with-current-buffer (org-iw-test-visit "a.org")
      (read-only-mode 1))
    (dolist (label '(nil remove))
      (org-iw-cmd-test--should-refuse-cleanly
       "buffer is read-only" (lambda () (org-iw-continue label))))))

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

;;;; Moving a member

(defun org-iw-cmd-test--move (scan id placement &optional where)
  "Move entry ID of ESSAYS in SCAN to PLACEMENT, WHERE its text if given.
Return the result of `org-iw--move'."
  (org-iw--move scan (org-iw--order scan "ESSAYS")
                (org-iw-cmd-test--entry scan id) "ESSAYS" placement where))

(ert-deftest org-iw-cmd-test-move-writes-rank ()
  "A move writes one line, the new rank over the scanned one.
It returns the depth and the save status."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((scan (org-iw--scan)))
      (should (equal (org-iw-cmd-test--should-move
                      (lambda ()
                        (org-iw-cmd-test--move scan "a1" 'end "at End"))
                      "a.org" 1024 4096)
                     '(moved 2 saved))))))

(ert-deftest org-iw-cmd-test-move-unchanged-writes-nothing ()
  "A member already at its placement is not written, not even attempted.
Its buffer is read-only, which would refuse any write."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (with-current-buffer (org-iw-test-visit "b.org")
      (read-only-mode 1))
    (let ((scan (org-iw--scan)))
      (should (equal (org-iw-cmd-test--should-write-nothing
                      (lambda ()
                        (org-iw-cmd-test--move scan "c1" 'end "at End")))
                     '(unchanged 2))))))

(ert-deftest org-iw-cmd-test-move-refuses-stale-rank ()
  "A rank changed since the scan refuses the move; nothing is written."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (let ((scan (org-iw--scan)))
      (org-iw-cmd-test--set-rank "a.org" 1024 1500)
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "changed since scan"
                      (lambda ()
                        (org-iw-cmd-test--move scan "a1" 'end "at End")))
                     (concat (org-iw-test-path "a.org")
                             ": IW_ESSAYS changed since scan"))))))

(ert-deftest org-iw-cmd-test-move-refuses-without-gap ()
  "Between neighbours ranked 5 and 6 there is no room; nothing changes.
The refusal names the queue by its configured name."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1")
                            (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 5")
                            (org-iw-test-heading "C" "c1" ":IW_ESSAYS: 6"))))
    (org-iw-cmd-test--open-all)
    (let ((org-iw-queues '(("essays" :name "Essays")))
          (scan (org-iw--scan)))
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "no room"
                      (lambda ()
                        (org-iw-cmd-test--move scan "a1" '(after 1)
                                               "at Second")))
                     (concat "no room at Second in Essays; redistribution"
                             " is not yet available")))
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "no room"
                      (lambda ()
                        (org-iw-cmd-test--move scan "a1" '(after 1))))
                     (concat "no room at position 2/3 in Essays;"
                             " redistribution is not yet available"))))))

(ert-deftest org-iw-cmd-test-moved-text ()
  "The move text gives the placement when WHERE is given, else only D/N."
  (pcase-dolist (`(,result ,where ,text)
                 '(((moved 1 saved) "Soon" "Moved T to Soon, 2/3 (saved)")
                   ((unchanged 2) "Soon" "T already at Soon, 3/3")
                   ((moved 1 saved) nil "Moved T to 2/3 (saved)")
                   ((unchanged 2) nil "T already at 3/3")))
    (should (equal (org-iw--moved-text result "T" where 3) text))))

;;;; Continue: placements

(defun org-iw-cmd-test--continue-chosen ()
  "Call `org-iw-continue' interactively with a prefix argument."
  (let ((current-prefix-arg '(4)))
    (call-interactively #'org-iw-continue)))

(ert-deftest org-iw-cmd-test-continue-standard-placements ()
  "Soon, Later and End put E1 3rd, 4th and 8th, one line each.
The head of the rest is visited, and the message names the label."
  (pcase-dolist (`(,label ,rank ,order)
                 '(("Soon" 3584 ("e2" "e3" "e1" "e4" "e5" "e6" "e7" "e8"))
                   ("Later" 4608 ("e2" "e3" "e4" "e1" "e5" "e6" "e7" "e8"))
                   ("End" 9216 ("e2" "e3" "e4" "e5" "e6" "e7" "e8" "e1"))))
    (org-iw-test-with-corpus org-iw-cmd-test--eight
      (org-iw-visit-next "ESSAYS")
      (should (equal (org-iw-cmd-test--should-move
                      (lambda () (org-iw-continue label)) "q.org" 1024 rank)
                     (format "Moved E1 to %s, %d/8 (saved). Now 1/8: E2"
                             label (1+ (seq-position order "e1")))))
      (should (equal (org-iw-cmd-test--order "ESSAYS") order))
      (should (equal (org-iw-cmd-test--shown) '("q.org" "E2")))
      (should (equal (org-iw-cmd-test--session-id) "e2")))))

(ert-deftest org-iw-cmd-test-continue-default-never-prompts ()
  "Without a prefix argument Continue uses the default, End, unprompted."
  (org-iw-test-with-corpus org-iw-cmd-test--eight
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--with-prompt nil
      (should (string-prefix-p "Moved E1 to End, 8/8"
                               (call-interactively #'org-iw-continue))))))

(ert-deftest org-iw-cmd-test-continue-chooser ()
  "With a prefix argument Continue reads one of the queue's own labels.
They are offered in configured order, then Remove, with the queue's
default, which plain Continue then uses."
  (org-iw-test-with-corpus org-iw-cmd-test--eight
    (let ((org-iw-queues '(("essays" :placements (("Later" (fraction 1 2))
                                                  ("Again" (after 0))
                                                  ("Soon" (after 2)))
                            :default "Soon"))))
      (org-iw-visit-next "ESSAYS")
      (org-iw-cmd-test--with-prompt "Later"
        (should (equal (org-iw-cmd-test--continue-chosen)
                       "Moved E1 to Later, 4/8 (saved). Now 1/8: E2"))
        (pcase-let ((`(,call) org-iw-cmd-test--prompts))
          (should (equal (plist-get call :prompt) "Placement: "))
          (should (equal (plist-get call :order)
                         '("Later" "Again" "Soon" "Remove")))
          (should (equal (plist-get call :default) "Soon"))))
      (should (string-prefix-p "Moved E2 to Soon, 3/8" (org-iw-continue))))))

(ert-deftest org-iw-cmd-test-continue-configured-defaults ()
  "Own placements without :default use the first; :default alone the standard."
  (pcase-dolist (`(,options ,message)
                 '(((:placements (("Again" (after 0)) ("Soon" (after 2))))
                    "E1 already at Again, 1/8. Now 1/8: E1")
                   ((:default "Soon")
                    "Moved E1 to Soon, 3/8 (saved). Now 1/8: E2")))
    (org-iw-test-with-corpus org-iw-cmd-test--eight
      (let ((org-iw-queues (list (cons "essays" options))))
        (org-iw-visit-next "ESSAYS")
        (should (equal (org-iw-continue) message))))))

(ert-deftest org-iw-cmd-test-continue-chooser-refuses-before-prompting ()
  "With a prefix, Continue refuses unprompted: no session, or bad config."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--with-prompt nil
      (org-iw-cmd-test--should-refuse-cleanly
       "no session" #'org-iw-cmd-test--continue-chosen)
      (org-iw-visit-next "ESSAYS")
      (let ((org-iw-queues '(("essays" :placements nil))))
        (org-iw-cmd-test--should-refuse-cleanly
         "queue ESSAYS :placements: no placements"
         #'org-iw-cmd-test--continue-chosen)))))

(ert-deftest org-iw-cmd-test-continue-refuses-placement-before-scan ()
  "A bad label or bad config refuses before any scan, naming its source."
  (pcase-dolist (`(,queues ,placements ,label ,message)
                 `((nil ,org-iw-cmd-test--standard "Nope"
                        "queue ESSAYS has no placement \"Nope\"")
                   ((("essays" :default "Nope")) ,org-iw-cmd-test--standard nil
                    "queue ESSAYS :default: \"Nope\" is not a placement label")
                   (nil (("Soon" (after -1))) "Soon"
                        "org-iw-placements: invalid entry (\"Soon\" (after -1))")))
    (org-iw-test-with-corpus org-iw-cmd-test--queue
      (org-iw-cmd-test--open-all)
      (org-iw-visit-next "ESSAYS")
      (let ((org-iw-queues queues)
            (org-iw-placements placements)
            (org-iw-default-placement "Soon"))
        (cl-letf (((symbol-function 'org-iw--scan)
                   (lambda () (ert-fail "Scanned"))))
          (should (equal (org-iw-cmd-test--should-refuse-cleanly
                          "" (lambda () (org-iw-continue label)))
                         message)))))))

(ert-deftest org-iw-cmd-test-continue-unchanged-writes-nothing ()
  "An entry already at its placement is not written, nor its buffer modified."
  (org-iw-test-with-corpus org-iw-cmd-test--eight
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (with-current-buffer (org-iw-test-visit "q.org")
      (org-iw-cmd-test--set-rank "q.org" 1024 3500)
      (save-buffer))
    (should (equal (org-iw-cmd-test--should-write-nothing
                    (lambda () (org-iw-continue "Soon")))
                   "E1 already at Soon, 3/8. Now 1/8: E2"))
    (should-not (buffer-modified-p (org-iw-test-visit "q.org")))
    (should (equal (org-iw-cmd-test--shown) '("q.org" "E2")))))

(ert-deftest org-iw-cmd-test-continue-front-reopens ()
  "At depth 0 Continue reopens the entry, moved there or already there."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((org-iw-queues '(("essays" :placements (("Again" (after 0)))))))
      (org-iw-cmd-test--open-all)
      (org-iw-visit-next "ESSAYS")
      (should (equal (org-iw-cmd-test--should-write-nothing #'org-iw-continue)
                     "A already at Again, 1/3. Now 1/3: A"))
      (org-iw-cmd-test--set-rank "b.org" 2048 1)
      (should (equal (org-iw-cmd-test--should-move #'org-iw-continue
                                                   "a.org" 1024 -1023)
                     "Moved A to Again, 1/3 (saved). Now 1/3: A"))
      (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))
      (should (equal (org-iw-cmd-test--order "ESSAYS") '("a1" "b1" "c1"))))))

(ert-deftest org-iw-cmd-test-continue-later-in-two ()
  "In a queue of two, Later is the front: it reopens the same entry."
  (org-iw-test-with-corpus
      `(("a.org" . ,org-iw-cmd-test--a-file)
        ("b.org" . ,(org-iw-test-heading "B" "b1" ":IW_ESSAYS: 2048")))
    (org-iw-cmd-test--open-all)
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-iw-cmd-test--should-write-nothing
                    (lambda () (org-iw-continue "Later")))
                   "A already at Later, 1/2. Now 1/2: A"))
    (should (equal (org-iw-cmd-test--shown) '("a.org" "A")))))

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
      (should (equal message (concat "Moved A to End, 3/3 (saved). Now 1/3: B"
                                     " [1 source problems ignored]"))))))

(ert-deftest org-iw-cmd-test-continue-reports-failed-save ()
  "A failing save is reported; the edit stands and B is still visited."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (let ((write-file-functions (list (lambda () (error "Disk full")))))
      (should (equal (org-iw-continue)
                     (concat "Moved A to End, 3/3 (queue change applied but"
                             " not saved: Disk full). Now 1/3: B"))))
    (should (buffer-modified-p (org-iw-test-visit "a.org")))
    (should (equal (org-iw-test-file-string "a.org") org-iw-cmd-test--a-file))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))))

;;;; Move from the source: the entry at point

(defconst org-iw-cmd-test--document
  (concat (org-iw-test-org ":PROPERTIES:" ":ID: doc1" ":IW_ESSAYS: 1024" ":END:"
                           "#+title: Doc" "Intro.")
          (org-iw-test-heading "H" "h1"))
  "A member document, in ESSAYS at 1024, with text and a heading after it.")

(defun org-iw-cmd-test--scanned-at (marker)
  "Return the scanned entry at MARKER, from a fresh scan."
  (org-iw--scanned-entry-at marker (org-iw--scan)))

(defun org-iw-cmd-test--scanned-refusal (marker)
  "Return the refusal of `org-iw--scanned-entry-at' at MARKER."
  (org-iw-cmd-test--refusal (lambda () (org-iw-cmd-test--scanned-at marker))))

(ert-deftest org-iw-cmd-test-scanned-entry-at-finds-member ()
  "The entry at a member heading is the scan's own element."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let* ((scan (org-iw--scan))
           (entry (org-iw--scanned-entry-at
                   (org-iw-test-marker "b.org" "C") scan)))
      (should (eq entry (org-iw-cmd-test--entry scan "c1"))))))

(ert-deftest org-iw-cmd-test-scanned-entry-at-matches-file ()
  "A heading sharing a member's ID in another file is not that member."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-heading "A" "m1" ":IW_ESSAYS: 1"))
        ("b.org" . ,(org-iw-test-heading "Copy" "m1")))
    (should (equal (org-iw-entry-file
                    (org-iw-cmd-test--scanned-at
                     (org-iw-test-marker "a.org" "A")))
                   (org-iw-test-path "a.org")))
    (should (equal (org-iw-cmd-test--scanned-refusal
                    (org-iw-test-marker "b.org" "Copy"))
                   "entry at point is not in any queue"))))

(ert-deftest org-iw-cmd-test-scanned-entry-at-refuses-excluded ()
  "An ID the scan has problems with is excluded, naming the types.
Distinct types are listed once each, in scan order; no ID is shown."
  (pcase-dolist (`(,files ,name ,title ,message)
                 `(((("a.org" . ,(org-iw-test-heading "H" "h1" ":IW_ESSAYS+: 1")))
                    "a.org" "H" "entry at point is excluded (invalid-property)")
                   ((("a.org" . ,(concat (org-iw-test-heading "H" "h1"
                                                              ":IW_ESSAYS: 1")
                                         (org-iw-test-heading "Copy" "h1"))))
                    "a.org" "H" "entry at point is excluded (duplicate-id)")
                   ((("a.org" . ,(org-iw-test-heading "H" "h1" ":IW_ESSAYS+: 1"))
                     ("b.org" . ,(org-iw-test-heading "B" "h1" ":IW_ESSAYS: x")))
                    "a.org" "H"
                    "entry at point is excluded (invalid-property, invalid-rank)")))
    (org-iw-test-with-corpus files
      (should (equal (org-iw-cmd-test--scanned-refusal
                      (org-iw-test-marker name title))
                     message)))))

(ert-deftest org-iw-cmd-test-scanned-entry-at-refuses-no-queue ()
  "An entry with no ID, or an ID and no IW line, is in no queue.
Without an ID the scan's own missing-id problem is not shown as exclusion."
  (pcase-dolist (`(,text ,title)
                 `((,(org-iw-test-heading "H" nil ":IW_ESSAYS: 1") "H")
                   (,(org-iw-test-heading "H" "h1") "H")
                   (,(org-iw-test-heading "H" "h1" ":IW_ESSAYS: 1") nil)))
    (org-iw-test-with-corpus
        `(("a.org" . ,(if title text (concat (org-iw-test-org "Intro.") text))))
      (should (equal (org-iw-cmd-test--scanned-refusal
                      (org-iw-cmd-test--at "a.org" title))
                     "entry at point is not in any queue")))))

(ert-deftest org-iw-cmd-test-scanned-entry-at-document ()
  "A document with an ID and an IW line is found; without an ID it is in no queue."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--document)
                             ("b.org" . ,org-iw-cmd-test--intro))
    (should (equal (org-iw-entry-id
                    (org-iw-cmd-test--scanned-at
                     (org-iw-cmd-test--at "a.org" nil)))
                   "doc1"))
    (should (equal (org-iw-cmd-test--scanned-refusal
                    (org-iw-cmd-test--at "b.org" nil))
                   "entry at point is not in any queue"))))

(ert-deftest org-iw-cmd-test-scanned-entry-at-narrowed-and-indirect ()
  "A marker in a narrowed buffer or an indirect buffer finds its entry."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((marker (org-iw-test-marker "b.org" "C")))
      (with-current-buffer (marker-buffer marker)
        (org-iw-cmd-test--narrow-to-line "* B"))
      (should (equal (org-iw-entry-id (org-iw-cmd-test--scanned-at marker))
                     "c1"))
      (org-iw-test-call-with-indirect
       marker (lambda (indirect-marker)
                (should (equal (org-iw-entry-id
                                (org-iw-cmd-test--scanned-at indirect-marker))
                               "c1")))))))

;;;; Move from the source: choosing the queue

(defconst org-iw-cmd-test--multi
  `(,@org-iw-cmd-test--queue
    ("m.org" . ,(org-iw-test-heading "M" "m1" ":IW_ESSAYS: 5000"
                                     ":IW_DRAFTS: 1000"))
    ("n.org" . ,(org-iw-test-heading "N" "n1" ":IW_NOTES: 1")))
  "The queue corpus, M in ESSAYS (last) and DRAFTS (after D), N in NOTES.")

(defun org-iw-cmd-test--membership-queue (name title)
  "Return `org-iw--membership-queue' of the entry TITLE in corpus file NAME."
  (org-iw--membership-queue
   (org-iw-cmd-test--scanned-at (org-iw-test-marker name title))))

(ert-deftest org-iw-cmd-test-membership-queue-single ()
  "An entry in one queue has that queue, unprompted, with or without a session."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--with-prompt nil
      (should (equal (org-iw-cmd-test--membership-queue "a.org" "A") "ESSAYS"))
      (let ((org-iw--session (org-iw-cmd-test--session "NOTES" "N")))
        (should (equal (org-iw-cmd-test--membership-queue "a.org" "A")
                       "ESSAYS"))))))

(ert-deftest org-iw-cmd-test-membership-queue-prompts-over-its-queues ()
  "With several queues and no session, one must-match prompt offers only them."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--with-prompt "DRAFTS"
      (should (equal (org-iw-cmd-test--membership-queue "m.org" "M") "DRAFTS"))
      (pcase-let ((`(,call) org-iw-cmd-test--prompts))
        (should (equal (plist-get call :prompt) "Queue: "))
        (should (equal (plist-get call :order) '("DRAFTS" "ESSAYS")))
        (should (eq (plist-get call :require-match) t))))))

(ert-deftest org-iw-cmd-test-membership-queue-session ()
  "A session in one of the entry's queues chooses it; any other prompts.
The session is not changed."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (dolist (queue '("ESSAYS" "DRAFTS"))
      (let* ((session (org-iw-cmd-test--session queue "S"))
             (org-iw--session session))
        (org-iw-cmd-test--with-prompt nil
          (should (equal (org-iw-cmd-test--membership-queue "m.org" "M")
                         queue)))
        (should (eq org-iw--session session))))
    (let* ((session (org-iw-cmd-test--session "NOTES" "N"))
           (org-iw--session session))
      (org-iw-cmd-test--with-prompt "ESSAYS"
        (should (equal (org-iw-cmd-test--membership-queue "m.org" "M")
                       "ESSAYS"))
        (should (= (length org-iw-cmd-test--prompts) 1)))
      (should (eq org-iw--session session)))))

;;;; Move from the source: the command

(defconst org-iw-cmd-test--source-refusals
  (let ((no-queue "entry at point is not in any queue"))
    `((,(org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1")
       "ess_ays" "A" "invalid queue ID \"ess_ays\"")
      (,(org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1")
       "DRAFTS" "A" "A is not in queue DRAFTS")
      (,(org-iw-test-heading "H" "h1") "ESSAYS" "H" ,no-queue)
      (,(org-iw-test-heading "H" nil ":IW_ESSAYS: 1") "ESSAYS" "H" ,no-queue)
      (,(org-iw-test-heading "H" "h1" ":IW_ESSAYS+: 1")
       "ESSAYS" "H" "entry at point is excluded (invalid-property)")
      (,(org-iw-test-heading "H" "h1" ":IW_DRAFTS: 1" ":IW_DRAFTS+: 2"
                             ":IW_ESSAYS: 5")
       "DRAFTS" "H" "entry at point is excluded (duplicate-property)")
      (,(org-iw-test-heading "H" "h1" ":IW_ESSAYS: 1" ":IW_DRAFTS: x")
       "DRAFTS" "H" "entry at point is excluded (invalid-rank)")
      (,org-iw-cmd-test--intro "ESSAYS" nil ,no-queue)))
  "Refusals of a command on the entry at point, given a queue.
Each is (TEXT QUEUE TITLE MESSAGE): a.org holds TEXT, and the command
at heading TITLE, or the start if nil, for QUEUE refuses with MESSAGE.")

(defun org-iw-cmd-test--should-refuse-at (command)
  "Assert COMMAND refuses each of `org-iw-cmd-test--source-refusals'.
COMMAND is called at the entry with the queue, and must change nothing."
  (pcase-dolist (`(,text ,queue ,title ,message)
                 org-iw-cmd-test--source-refusals)
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-cmd-test--at "a.org" title)))
        (should (equal (org-iw-cmd-test--should-refuse-cleanly
                        "" (lambda ()
                             (org-iw-cmd-test--call-at marker command queue)))
                       message))))))

(ert-deftest org-iw-cmd-test-move-command-moves-one-line ()
  "Move writes one rank, canonicalising QUEUE, and names the queue and place.
Without a label it uses the queue's default."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((org-iw-queues '(("essays" :name "Essays"))))
      (should (equal (org-iw-cmd-test--should-move
                      (lambda ()
                        (org-iw-cmd-test--call-at
                         (org-iw-test-marker "a.org" "A")
                         #'org-iw-move "essays"))
                      "a.org" 1024 4096)
                     "Moved A to End in Essays, 3/3 (saved)"))
      (should (equal (org-iw-cmd-test--order "ESSAYS") '("b1" "c1" "a1"))))))

(ert-deftest org-iw-cmd-test-move-command-leaves-other-memberships ()
  "Only the chosen queue's line changes; the entry's other IW lines stand."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (should (equal (org-iw-cmd-test--should-move
                    (lambda ()
                      (org-iw-cmd-test--call-at
                       (org-iw-test-marker "m.org" "M")
                       #'org-iw-move "ESSAYS" "Later"))
                    "m.org" 5000 1536)
                   "Moved M to Later in ESSAYS, 2/4 (saved)"))
    (should (equal (org-iw-cmd-test--order "DRAFTS") '("d1" "m1")))))

(ert-deftest org-iw-cmd-test-move-command-already-there ()
  "An entry already at its place is reported and nothing is written.
Its buffer is read-only, which would refuse any write."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (with-current-buffer (org-iw-test-visit "b.org")
      (read-only-mode 1))
    (should (equal (org-iw-cmd-test--should-change-nothing
                    (lambda ()
                      (org-iw-cmd-test--call-at
                       (org-iw-test-marker "b.org" "C")
                       #'org-iw-move "ESSAYS" "End")))
                   "C already at End in ESSAYS, 3/3"))))

(ert-deftest org-iw-cmd-test-move-command-counts-source-problems ()
  "Move's message counts the scan's problems."
  (org-iw-test-with-corpus `(,@org-iw-cmd-test--queue ,org-iw-cmd-test--problem)
    (should (equal (org-iw-cmd-test--call-at
                    (org-iw-test-marker "a.org" "A") #'org-iw-move "ESSAYS")
                   (concat "Moved A to End in ESSAYS, 3/3 (saved)"
                           " [1 source problems ignored]")))))

(ert-deftest org-iw-cmd-test-move-command-keeps-session-and-window ()
  "Move starts no session, ends none, and shows nothing (I13)."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((marker (org-iw-test-marker "a.org" "A")))
      (pcase-dolist (`(,visiting ,label) '((nil "Soon") (t "Later")))
        (when visiting
          (org-iw-visit-next "DRAFTS"))
        (let ((session org-iw--session)
              (window (selected-window))
              (buffer (current-buffer))
              (shown (org-iw-cmd-test--shown)))
          (should (string-prefix-p
                   "Moved A" (org-iw-cmd-test--call-at
                              marker #'org-iw-move "ESSAYS" label)))
          (should (eq org-iw--session session))
          (should (eq (selected-window) window))
          (should (eq (current-buffer) buffer))
          (should (equal (org-iw-cmd-test--shown) shown))
          (should (equal (null org-iw--session) (not visiting))))))))

(ert-deftest org-iw-cmd-test-move-command-no-room ()
  "Between neighbours ranked 5 and 6 there is no room; nothing changes."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1")
                            (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 5")
                            (org-iw-test-heading "C" "c1" ":IW_ESSAYS: 6"))))
    (org-iw-cmd-test--open-all)
    (let ((org-iw-queues '(("essays" :placements (("Second" (after 1)))))))
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "no room"
                      (lambda ()
                        (org-iw-cmd-test--call-at
                         (org-iw-test-marker "a.org" "A")
                         #'org-iw-move "ESSAYS" "Second")))
                     (org-iw-cmd-test--no-room "at Second"))))))

(ert-deftest org-iw-cmd-test-move-command-member-document ()
  "A member document moves, as a heading does, from within its preamble."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--document)
                             ("b.org" . ,org-iw-cmd-test--b-file))
    (with-current-buffer (org-iw-test-visit "a.org")
      (org-iw-cmd-test--narrow-to-line "Intro.")
      (should (equal (org-iw-cmd-test--should-move
                      (lambda () (org-iw-move "ESSAYS"))
                      "a.org" 1024 4096)
                     "Moved Doc to End in ESSAYS, 3/3 (saved)")))))

(ert-deftest org-iw-cmd-test-move-command-first-line-heading ()
  "A heading on the first line moves; it is not mistaken for a document."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1024")
                            (org-iw-test-org "Body.")))
        ("b.org" . ,org-iw-cmd-test--b-file))
    (with-current-buffer (org-iw-test-visit "a.org")
      (org-iw-cmd-test--narrow-to-line "Body.")
      (should (equal (org-iw-move "ESSAYS")
                     "Moved A to End in ESSAYS, 3/3 (saved)")))))

(ert-deftest org-iw-cmd-test-move-command-member-with-other-problems ()
  "A member whose ID also has a problem elsewhere is still moved.
The problem, a bad line for another queue, does not exclude it from
ESSAYS: only an entry the scan left out of a queue is excluded."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "H" "h1" ":IW_ESSAYS: 1"
                                                 ":IW_DRAFTS: x")
                            (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 2"))))
    (should (string-prefix-p
             "Moved H to End in ESSAYS, 2/2"
             (org-iw-cmd-test--call-at (org-iw-test-marker "a.org" "H")
                                       #'org-iw-move "ESSAYS")))))

(ert-deftest org-iw-cmd-test-move-command-refuses ()
  "Move refuses, changing nothing, where the entry cannot be moved."
  (org-iw-cmd-test--should-refuse-at #'org-iw-move))

(ert-deftest org-iw-cmd-test-move-command-refuses-outside-sources ()
  "Move refuses a file outside the sources and a buffer not in Org mode."
  (org-iw-test-with-corpus '(("a.org" . "* A\n") ("b.org" . "* B\n"))
    (let ((org-iw-sources (list (org-iw-test-path "a.org")))
          (marker (org-iw-test-marker "b.org" "B")))
      (org-iw-cmd-test--should-refuse-cleanly
       "not under org-iw-sources"
       (lambda () (org-iw-cmd-test--call-at marker #'org-iw-move "ESSAYS")))))
  (org-iw-test-with-corpus `(("a.txt" . ,org-iw-cmd-test--member))
    (let ((org-iw-sources (list (org-iw-test-path "a.txt"))))
      (with-current-buffer (org-iw-test-visit "a.txt")
        (text-mode)
        (should (string-search "buffer not in Org mode"
                               (cadr (should-error (org-iw-move "ESSAYS")
                                                   :type 'org-iw-refusal))))))))

(ert-deftest org-iw-cmd-test-move-command-refuses-placement-before-scan ()
  "A bad queue, label or configuration refuses before any scan."
  (pcase-dolist (`(,queues ,queue ,label ,message)
                 '((nil "ess_ays" nil "invalid queue ID \"ess_ays\"")
                   (nil "ESSAYS" "Nope" "queue ESSAYS has no placement \"Nope\"")
                   ((("essays" :placements nil)) "ESSAYS" nil
                    "queue ESSAYS :placements: no placements")))
    (org-iw-test-with-corpus org-iw-cmd-test--queue
      (let ((org-iw-queues queues)
            (marker (org-iw-test-marker "a.org" "A")))
        (cl-letf (((symbol-function 'org-iw--scan)
                   (lambda () (ert-fail "Scanned"))))
          (should (equal (org-iw-cmd-test--should-refuse-cleanly
                          ""
                          (lambda ()
                            (org-iw-cmd-test--call-at
                             marker #'org-iw-move queue label)))
                         message)))))))

;;;; Move from the source: interactively

(ert-deftest org-iw-cmd-test-move-chosen-one-queue ()
  "An entry in one queue is asked for a placement only, default last."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (let ((org-iw-queues '(("essays" :placements (("Again" (after 0))
                                                  ("Back" end))
                            :default "Back"))))
      (org-iw-cmd-test--with-prompt "Again"
        (should (equal (org-iw-cmd-test--call-at
                        (org-iw-test-marker "a.org" "A")
                        #'call-interactively #'org-iw-move)
                       "A already at Again in ESSAYS, 1/4"))
        (pcase-let ((`(,call) org-iw-cmd-test--prompts))
          (should (equal (plist-get call :prompt) "Placement: "))
          (should (equal (plist-get call :order) '("Again" "Back")))
          (should (equal (plist-get call :default) "Back")))))))

(ert-deftest org-iw-cmd-test-move-chosen-two-queues ()
  "With two queues and no session, Move asks for the queue, then a placement.
The queue prompt offers the entry's queues only."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--with-prompt '("DRAFTS" "Soon")
      (should (equal (org-iw-cmd-test--call-at
                      (org-iw-test-marker "m.org" "M")
                      #'call-interactively #'org-iw-move)
                     "M already at Soon in DRAFTS, 2/2"))
      (should (equal (org-iw-cmd-test--prompted :prompt)
                     '("Queue: " "Placement: ")))
      (should (equal (plist-get (car org-iw-cmd-test--prompts) :order)
                     '("DRAFTS" "ESSAYS")))
      (should (eq (plist-get (car org-iw-cmd-test--prompts) :require-match) t)))))

(ert-deftest org-iw-cmd-test-move-chosen-session-queue ()
  "With a session in one of the entry's queues Move asks for a placement only."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (let ((org-iw--session (org-iw-cmd-test--session "ESSAYS" "S")))
      (org-iw-cmd-test--with-prompt "Later"
        (should (string-prefix-p
                 "Moved M to Later in ESSAYS"
                 (org-iw-cmd-test--call-at
                  (org-iw-test-marker "m.org" "M")
                  #'call-interactively #'org-iw-move)))
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       '("Placement: ")))))))

(ert-deftest org-iw-cmd-test-move-chosen-refuses-before-prompting ()
  "Interactively, nothing is prompted for an entry in no queue or bad config."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--with-prompt nil
      (org-iw-cmd-test--should-refuse-cleanly
       "queue ESSAYS :placements: no placements"
       (lambda ()
         (let ((org-iw-queues '(("essays" :placements nil))))
           (org-iw-cmd-test--call-at (org-iw-test-marker "a.org" "A")
                                     #'call-interactively #'org-iw-move))))
      (org-iw-cmd-test--should-refuse-cleanly
       "entry at point is not in any queue"
       (lambda ()
         (org-iw-cmd-test--call-at (org-iw-cmd-test--at "a.org" nil)
                                   #'call-interactively #'org-iw-move))))))

;;;; Remove: helpers

(defconst org-iw-cmd-test--hint
  (concat "The session still names it: org-iw-visit-next to go on,"
          " org-iw-end-session to stop")
  "The hint shown when the removed entry is still the session's.")

(ert-deftest org-iw-cmd-test-session-hint ()
  "The hint names the commands to go on and to stop, with no final period."
  (should (equal (org-iw--session-hint) org-iw-cmd-test--hint)))

(ert-deftest org-iw-cmd-test-removed-text ()
  "The removed text gains the hint only while the session names the entry.
That is the entry's ID in the queue removed from; a further sentence
comes before the hint."
  (let ((org-iw-queues '(("essays" :name "Essays")))
        (entry (org-iw-entry-create :id "x1" :title "A"))
        (removed "Removed A from Essays (saved)"))
    (pcase-dolist (`(,session ,then ,text)
                   `((nil nil ,removed)
                     ((:queue "ESSAYS" :id "b1") nil ,removed)
                     ((:queue "DRAFTS" :id "x1") nil ,removed)
                     ((:queue "ESSAYS" :id "x1") nil
                      ,(concat removed ". " org-iw-cmd-test--hint))
                     (nil "Now 1/2: B" ,(concat removed ". Now 1/2: B"))
                     ((:queue "ESSAYS" :id "x1") "Queue Essays is empty"
                      ,(concat removed ". Queue Essays is empty. "
                               org-iw-cmd-test--hint))))
      (let ((org-iw--session (and session
                                  (apply #'org-iw--session-create session))))
        (should (equal (org-iw--removed-text entry "ESSAYS" 'saved then)
                       text))))))

(ert-deftest org-iw-cmd-test-delete-rank-deletes-one-line ()
  "Deleting a rank removes its one line and returns the save status."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((scan (org-iw--scan)))
      (should (eq (org-iw-cmd-test--should-delete
                   (lambda ()
                     (org-iw--delete-rank
                      scan (org-iw-cmd-test--entry scan "b1") "ESSAYS"))
                   "b.org" ":IW_ESSAYS: 2048")
                  'saved))
      (should (equal (org-iw-cmd-test--order "ESSAYS") '("a1" "c1"))))))

(ert-deftest org-iw-cmd-test-delete-rank-refuses-stale-rank ()
  "A rank changed since the scan refuses the delete; nothing is written."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (let ((scan (org-iw--scan)))
      (org-iw-cmd-test--set-rank "a.org" 1024 1500)
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "changed since scan"
                      (lambda ()
                        (org-iw--delete-rank
                         scan (org-iw-cmd-test--entry scan "a1") "ESSAYS")))
                     (concat (org-iw-test-path "a.org")
                             ": IW_ESSAYS changed since scan"))))))

;;;; Continue: Remove

(ert-deftest org-iw-cmd-test-continue-remove-visits-new-head ()
  "Remove deletes the entry's line and visits the head of the rest.
The entry is not reinserted, and the hint is not given: the session
names the new head."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-iw-cmd-test--should-delete
                    (lambda () (org-iw-continue 'remove))
                    "a.org" ":IW_ESSAYS: 1024")
                   "Removed A from ESSAYS (saved). Now 1/2: B"))
    (should (equal (org-iw-cmd-test--order "ESSAYS") '("b1" "c1")))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))
    (should (equal (org-iw-cmd-test--session-id) "b1"))))

(ert-deftest org-iw-cmd-test-continue-remove-head-in-same-file ()
  "The new head, below the deleted line in the same file, is visited."
  (org-iw-test-with-corpus `(("b.org" . ,org-iw-cmd-test--b-file))
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-iw-cmd-test--should-delete
                    (lambda () (org-iw-continue 'remove))
                    "b.org" ":IW_ESSAYS: 2048")
                   "Removed B from ESSAYS (saved). Now 1/1: C"))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "C")))
    (should (equal (org-iw-cmd-test--session-id) "c1"))))

(ert-deftest org-iw-cmd-test-continue-remove-entry-not-at-head ()
  "Remove deletes the session's entry wherever it now stands in the queue.
A is moved last behind the session's back; B, the head of the rest,
is visited, not C, the second of the order."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--set-rank "a.org" 1024 4096)
    (with-current-buffer (org-iw-test-visit "a.org") (save-buffer))
    (should (equal (org-iw-cmd-test--should-delete
                    (lambda () (org-iw-continue 'remove))
                    "a.org" ":IW_ESSAYS: 4096")
                   "Removed A from ESSAYS (saved). Now 1/2: B"))
    (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))
    (should (equal (org-iw-cmd-test--session-id) "b1"))))

(ert-deftest org-iw-cmd-test-continue-remove-chosen ()
  "The chooser offers Remove after the labels, not as the default."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--with-prompt "Remove"
      (should (equal (org-iw-cmd-test--continue-chosen)
                     "Removed A from ESSAYS (saved). Now 1/2: B"))
      (pcase-let ((`(,call) org-iw-cmd-test--prompts))
        (should (equal (plist-get call :prompt) "Placement: "))
        (should (equal (plist-get call :order)
                       '("Soon" "Later" "End" "Remove")))
        (should (equal (plist-get call :default) "End"))))))

(ert-deftest org-iw-cmd-test-continue-remove-sole-entry ()
  "Removing the only entry reports the empty queue and the hint.
The session is kept, and nothing else is shown."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "DRAFTS")
    (let ((session org-iw--session)
          (shown (org-iw-cmd-test--shown)))
      (should (equal (org-iw-cmd-test--should-delete
                      (lambda () (org-iw-continue 'remove))
                      "d.org" ":IW_DRAFTS: 1")
                     (concat "Removed D from DRAFTS (saved). Queue DRAFTS is"
                             " empty. " org-iw-cmd-test--hint)))
      (should (eq org-iw--session session))
      (should (equal (org-iw-cmd-test--shown) shown)))))

(ert-deftest org-iw-cmd-test-continue-remove-ignores-vocabulary ()
  "From Lisp, Remove works whatever the placements' configuration."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (let ((org-iw-placements nil)
          (org-iw-queues '(("essays" :placements (("Remove" end))))))
      (should (equal (org-iw-continue 'remove)
                     "Removed A from ESSAYS (saved). Now 1/2: B")))))

;;;; Remove from the source

(ert-deftest org-iw-cmd-test-remove-command-deletes-one-line ()
  "Remove deletes one line, unconfirmed, canonicalising QUEUE (I11)."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((org-iw-queues '(("essays" :name "Essays"))))
      (should (equal (org-iw-cmd-test--should-delete
                      (lambda ()
                        (org-iw-cmd-test--call-at
                         (org-iw-test-marker "b.org" "B")
                         #'org-iw-remove "essays"))
                      "b.org" ":IW_ESSAYS: 2048")
                     "Removed B from Essays (saved)"))
      (should (equal (org-iw-cmd-test--order "ESSAYS") '("a1" "c1"))))))

(ert-deftest org-iw-cmd-test-remove-command-leaves-other-memberships ()
  "Only the chosen queue's line goes; the entry stays in its other queue."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--should-delete
     (lambda ()
       (org-iw-cmd-test--call-at (org-iw-test-marker "m.org" "M")
                                 #'org-iw-remove "ESSAYS"))
     "m.org" ":IW_ESSAYS: 5000")
    (should (equal (org-iw-cmd-test--order "DRAFTS") '("d1" "m1")))))

(ert-deftest org-iw-cmd-test-remove-command-hint-and-session ()
  "Remove keeps the session and the window, hinting only for its entry.
The hint is for the session's entry in the session's queue (I13)."
  (pcase-dolist (`(,session ,title ,message)
                 `((nil "A" "Removed A from ESSAYS (saved)")
                   (("ESSAYS" "b1" "B") "A" "Removed A from ESSAYS (saved)")
                   (("DRAFTS" "m1" "M") "M" "Removed M from ESSAYS (saved)")
                   (("ESSAYS" "m1" "M") "M"
                    ,(concat "Removed M from ESSAYS (saved). "
                             org-iw-cmd-test--hint))))
    (org-iw-test-with-corpus org-iw-cmd-test--multi
      (let* ((marker (org-iw-test-marker (if (equal title "A") "a.org" "m.org")
                                         title))
             (org-iw--session
              (and session
                   (pcase-let ((`(,queue ,id ,title) session))
                     (org-iw--session-create :queue queue :id id
                                             :title title))))
             (before org-iw--session)
             (window (selected-window))
             (buffer (current-buffer))
             (shown (org-iw-cmd-test--shown)))
        (should (equal (org-iw-cmd-test--call-at
                        marker #'org-iw-remove "ESSAYS") message))
        (should (eq org-iw--session before))
        (should (eq (selected-window) window))
        (should (eq (current-buffer) buffer))
        (should (equal (org-iw-cmd-test--shown) shown))
        (should-not (member (if (equal title "A") "a1" "m1")
                            (org-iw-cmd-test--order "ESSAYS")))))))

(ert-deftest org-iw-cmd-test-remove-command-member-document ()
  "A member document is removed from within its preamble; its drawer stays."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--document)
                             ("b.org" . ,org-iw-cmd-test--b-file))
    (let ((marker (with-current-buffer (org-iw-test-visit "a.org")
                    (org-iw-cmd-test--narrow-to-line "Intro.")
                    (point-marker))))
      (should (equal (org-iw-cmd-test--should-delete
                      (lambda ()
                        (org-iw-cmd-test--call-at
                         marker #'org-iw-remove "ESSAYS"))
                      "a.org" ":IW_ESSAYS: 1024")
                     "Removed Doc from ESSAYS (saved)")))))

(ert-deftest org-iw-cmd-test-remove-command-lowercase-key ()
  "A member by a lowercase key loses that line."
  (org-iw-test-with-corpus (org-iw-cmd-test--queue-of-three ":iw_essays: 2048")
    (should (equal (org-iw-cmd-test--should-delete
                    (lambda ()
                      (org-iw-cmd-test--call-at
                       (org-iw-test-marker "a.org" "Target")
                       #'org-iw-remove "ESSAYS"))
                    "a.org" ":iw_essays: 2048")
                   "Removed Target from ESSAYS (saved)"))))

(ert-deftest org-iw-cmd-test-remove-command-refuses ()
  "Remove refuses, changing nothing, where the entry cannot be removed."
  (org-iw-cmd-test--should-refuse-at #'org-iw-remove))

(ert-deftest org-iw-cmd-test-remove-chosen-one-queue ()
  "Interactively, an entry in one queue is removed unprompted."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--with-prompt nil
      (should (equal (org-iw-cmd-test--call-at
                      (org-iw-test-marker "a.org" "A")
                      #'call-interactively #'org-iw-remove)
                     "Removed A from ESSAYS (saved)")))))

(ert-deftest org-iw-cmd-test-remove-chosen-two-queues ()
  "With two queues and no session, Remove asks which, offering only them."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--with-prompt "DRAFTS"
      (should (equal (org-iw-cmd-test--should-delete
                      (lambda ()
                        (org-iw-cmd-test--call-at
                         (org-iw-test-marker "m.org" "M")
                         #'call-interactively #'org-iw-remove))
                      "m.org" ":IW_DRAFTS: 1000")
                     "Removed M from DRAFTS (saved)"))
      (should (equal (org-iw-cmd-test--prompted :order)
                     '(("DRAFTS" "ESSAYS")))))))

(ert-deftest org-iw-cmd-test-remove-chosen-refuses-before-prompting ()
  "Interactively, an entry in no queue refuses unprompted."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--with-prompt nil
      (org-iw-cmd-test--should-refuse-cleanly
       "entry at point is not in any queue"
       (lambda ()
         (org-iw-cmd-test--call-at (org-iw-cmd-test--at "a.org" nil)
                                   #'call-interactively #'org-iw-remove))))))

;;;; Queue view: context text (EX-2, VT-1)

(ert-deftest org-iw-cmd-test-outline-text ()
  "The outline joins with \" / \", dropping outer ancestors behind \"…/\".
An over-long nearest ancestor keeps its right end.  Each text fits
WIDTH exactly at the boundaries.  The helper is pure and is tested
directly, at widths the view does not use."
  (pcase-dolist (`(,outline ,width ,text)
                 '((nil 12 "")
                   (("A" "B") 12 "A / B")
                   (("Alpha" "Beta" "Gamma") 20 "Alpha / Beta / Gamma")
                   (("Alpha" "Beta" "Gamma") 19 "…/Beta / Gamma")
                   (("Alpha" "Beta" "Gamma") 14 "…/Beta / Gamma")
                   (("Alpha" "Beta" "Gamma") 13 "…/Gamma")
                   (("Root" "Abcdefghijklmnop") 12 "…/ghijklmnop")
                   (("Abcdefghijklmnop") 16 "Abcdefghijklmnop")
                   (("Abcdefghijklmnop") 12 "…/ghijklmnop")))
    (should (equal (list outline width (org-iw--outline-text outline width))
                   (list outline width text)))))

;;;; Queue view: rows and buffers (EX-1, EX-3, VT-1)

(defconst org-iw-cmd-test--view-corpus
  `(("notes.org"
     . ,(org-iw-test-org "* Essays [[id:x][Ideas]]"
                         "** Craft"
                         "*** Draft"
                         ":PROPERTIES:" ":ID: n1"
                         ":IW_ESSAYS: 7" ":IW_DRAFTS: 1" ":END:"
                         "* Notes on a very long parent heading"
                         "** Draft"
                         ":PROPERTIES:" ":ID: n2" ":IW_ESSAYS: 9000" ":END:"))
    ("sub/r.org"
     . ,(org-iw-test-heading "Read [[https://x.org][the paper]]" "r1"
                             ":IW_ESSAYS: 50")))
  "ESSAYS holds n1, r1 and n2, at gapped ranks; DRAFTS holds n1.
n1 and n2 are both titled Draft, under different parents.")

(defun org-iw-cmd-test--view (queue)
  "Show QUEUE with `org-iw-list-queue'; return the selected window's buffer."
  (org-iw-list-queue queue)
  (window-buffer (selected-window)))

(defun org-iw-cmd-test--view-rows (queue)
  "Show QUEUE with `org-iw-list-queue'; return its `tabulated-list-entries'."
  (buffer-local-value 'tabulated-list-entries (org-iw-cmd-test--view queue)))

(defun org-iw-cmd-test--cell-face (rows id column)
  "Return the face of cell COLUMN of the row ID in ROWS."
  (get-text-property 0 'face (aref (cadr (assoc id rows)) column)))

(ert-deftest org-iw-cmd-test-fixture-kills-views ()
  "The fixture kills the queue views and restores the windows."
  (let ((count (count-windows))
        view)
    (org-iw-test-with-corpus org-iw-cmd-test--queue
      (setq view (org-iw-cmd-test--view "ESSAYS"))
      (split-window))
    (should-not (buffer-live-p view))
    (should (equal (count-windows) count))))

(defmacro org-iw-cmd-test--with-outside-view (queue &rest body)
  "Run BODY with VIEW bound to a queue view of QUEUE made outside any fixture.
The view is killed afterwards, if it is still live."
  (declare (indent 1) (debug t))
  `(let ((view (with-current-buffer (generate-new-buffer "*org-iw: user*")
                 (org-iw-view-mode)
                 (setq org-iw--view-queue ,queue)
                 (current-buffer))))
     (unwind-protect
         (progn ,@body)
       (when (buffer-live-p view)
         (kill-buffer view)))))

(ert-deftest org-iw-cmd-test-fixture-spares-outside-views ()
  "A queue view made before the fixture is neither reused nor killed.
Showing the outside view's queue fails the test before it is redrawn."
  (org-iw-cmd-test--with-outside-view "READING"
    (let (inside)
      (org-iw-test-with-corpus org-iw-cmd-test--queue
        (setq inside (org-iw-cmd-test--view "ESSAYS")))
      (should-not (buffer-live-p inside))
      (should (buffer-live-p view))))
  (org-iw-cmd-test--with-outside-view "ESSAYS"
    (should-error (org-iw-test-with-corpus org-iw-cmd-test--queue
                    (org-iw-list-queue "ESSAYS"))
                  :type 'ert-test-failed)
    (should (buffer-live-p view))
    (should-not (buffer-local-value 'tabulated-list-entries view))))

(ert-deftest org-iw-cmd-test-list-queue-rows ()
  "A row per member in order: ordinal, link-reduced title, context, file.
Ordinals count from 1 whatever the ranks; the context is shadowed and
tells same-titled entries apart; without a session nothing is starred."
  (org-iw-test-with-corpus org-iw-cmd-test--view-corpus
    (let* ((rows (org-iw-cmd-test--view-rows "essays"))
           (view (window-buffer (selected-window))))
      (should (equal rows
                     '(("n1" ["1" "Draft" "Essays Ideas / Craft" "notes.org"])
                       ("r1" ["2" "Read the paper" "" "r.org"])
                       ("n2" ["3" "Draft" "…/n a very long parent heading"
                              "notes.org"]))))
      (should (equal (buffer-local-value 'tabulated-list-format view)
                     [("#" 5 nil :right-align t) ("Title" 40 nil)
                      ("Context" 30 nil) ("File" 0 nil)]))
      (should (eq (org-iw-cmd-test--cell-face rows "n1" 2) 'shadow))
      (should-not (org-iw-cmd-test--cell-face rows "n1" 1)))))

(ert-deftest org-iw-cmd-test-list-queue-session-row ()
  "The session's row is starred and bold, only in the session's queue."
  (org-iw-test-with-corpus org-iw-cmd-test--view-corpus
    (org-iw-visit-next "essays")
    (let ((rows (org-iw-cmd-test--view-rows "essays")))
      (should (equal (mapcar (lambda (row) (aref (cadr row) 0)) rows)
                     '("1*" "2" "3")))
      (should (equal (mapcar (lambda (row)
                               (org-iw-cmd-test--cell-face rows (car row) 1))
                             rows)
                     '(bold nil nil))))
    (org-iw-visit-next "drafts")
    (let ((rows (org-iw-cmd-test--view-rows "essays")))
      (should (equal (mapcar (lambda (row) (aref (cadr row) 0)) rows)
                     '("1" "2" "3")))
      (should-not (org-iw-cmd-test--cell-face rows "n1" 1)))))

(ert-deftest org-iw-cmd-test-list-queue-prompts ()
  "Without a session the queue is read over the known queues (REQ-013 AC1).
With one, the session's queue is shown unprompted."
  (org-iw-test-with-corpus org-iw-cmd-test--view-corpus
    (let ((org-iw-queues '(("ideas" :name "Ideas"))))
      (org-iw-cmd-test--with-prompt "essays"
        (call-interactively #'org-iw-list-queue)
        (should (equal (org-iw-cmd-test--prompted :collection)
                       '(("DRAFTS" "ESSAYS" "IDEAS"))))
        (should (equal (org-iw-cmd-test--prompted :require-match) '(nil))))
      (org-iw-visit-next "drafts")
      (org-iw-cmd-test--with-prompt nil
        (call-interactively #'org-iw-list-queue))
      (should (equal (buffer-local-value 'org-iw--view-queue
                                         (window-buffer (selected-window)))
                     "DRAFTS")))))

(ert-deftest org-iw-cmd-test-list-queue-empty ()
  "An empty queue shows an empty view and reports it."
  (org-iw-test-with-corpus org-iw-cmd-test--view-corpus
    (let ((org-iw-queues '(("ideas" :name "Ideas"))))
      (should (equal (org-iw-list-queue "ideas") "Queue Ideas is empty"))
      (let ((view (window-buffer (selected-window))))
        (should (equal (buffer-name view) "*org-iw: Ideas*"))
        (should-not (buffer-local-value 'tabulated-list-entries view))))))

(ert-deftest org-iw-cmd-test-list-queue-reports-count ()
  "Showing or refreshing a view reports its queue's count.
One member is \"1 entry\", none an empty queue.  The source problems
are noted, as by every command."
  (org-iw-test-with-corpus `(,@org-iw-cmd-test--queue
                             ,org-iw-cmd-test--problem)
    (let ((org-iw-queues '(("ideas" :name "Ideas")))
          (suffix " [1 source problems ignored]"))
      (pcase-dolist (`(,queue ,message)
                     '(("ESSAYS" "Queue ESSAYS: 3 entries")
                       ("DRAFTS" "Queue DRAFTS: 1 entry")
                       ("ideas" "Queue Ideas is empty")))
        (should (equal (org-iw-list-queue queue) (concat message suffix)))
        (should (equal (revert-buffer) (concat message suffix)))))))

(ert-deftest org-iw-cmd-test-view-buffer-per-queue ()
  "Each queue has its own view, found by queue ID, not name.
Showing a queue again reuses its view without setting it up again.
`org-iw--view-buffer' is called directly to show the lookup is by ID."
  (org-iw-test-with-corpus org-iw-cmd-test--view-corpus
    (let* ((org-iw-queues '(("essays" :name "Work") ("drafts" :name "Work")))
           (setups 0)
           (org-iw-view-mode-hook (list (lambda () (cl-incf setups))))
           (essays (org-iw-cmd-test--view "essays"))
           (drafts (org-iw-cmd-test--view "drafts")))
      (should-not (eq essays drafts))
      (should (equal (mapcar (lambda (view)
                               (list (buffer-name view)
                                     (buffer-local-value 'org-iw--view-queue
                                                         view)))
                             (list essays drafts))
                     '(("*org-iw: Work*" "ESSAYS")
                       ("*org-iw: Work*<2>" "DRAFTS"))))
      (should (eq (org-iw--view-buffer "ESSAYS") essays))
      (should (eq (org-iw-cmd-test--view "essays") essays))
      (should (equal setups 2)))))

(ert-deftest org-iw-cmd-test-view-mode-again-keeps-queue ()
  "Turning the view's mode on again keeps its queue.
Refresh still shows the queue, and showing the queue reuses the view."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (org-iw-cmd-test--view "ESSAYS")))
      (org-iw-view-mode)
      (revert-buffer)
      (should (equal (org-iw-cmd-test--view-ids view) '("a1" "b1" "c1")))
      (should (eq (org-iw-cmd-test--view "ESSAYS") view)))))

(ert-deftest org-iw-cmd-test-view-refresh-refuses-without-queue ()
  "Refresh refuses in a view buffer that shows no queue."
  (with-temp-buffer
    (org-iw-view-mode)
    (should (equal (cadr (should-error (revert-buffer) :type 'org-iw-refusal))
                   "no queue in this view; run org-iw-list-queue"))))

(ert-deftest org-iw-cmd-test-view-mode-keys ()
  "In the view, RET opens the entry, g refreshes, and the actions are bound."
  (org-iw-test-with-corpus org-iw-cmd-test--view-corpus
    (with-current-buffer (org-iw-cmd-test--view "essays")
      (pcase-dolist (`(,key . ,command)
                     '(("RET" . org-iw-view-open) ("g" . revert-buffer)
                       ("M-<up>" . org-iw-view-move-up)
                       ("M-<down>" . org-iw-view-move-down)
                       ("m" . org-iw-view-mark) ("u" . org-iw-view-unmark)
                       ("b" . org-iw-view-place-before)
                       ("a" . org-iw-view-place-after)
                       ("D" . org-iw-view-remove)))
        (should (eq (key-binding (kbd key)) command))))))

;;;; Queue view: open (EX-4, EX-5, VT-2)

(defun org-iw-cmd-test--window-row (window)
  "Return the ID of the view row at WINDOW's point.
WINDOW's point, not its buffer's: they differ while it is unselected."
  (with-current-buffer (window-buffer window)
    (save-excursion
      (goto-char (window-point window))
      (tabulated-list-get-id))))

(defun org-iw-cmd-test--view-on-row (queue n)
  "Show QUEUE's view with point on its row N; return the view's window.
Point is moved in the selected window, which shows the view."
  (org-iw-list-queue queue)
  (goto-char (point-min))
  (forward-line (1- n))
  (selected-window))

(defun org-iw-cmd-test--leave (window)
  "Select another window, showing d.org, leaving WINDOW unselected.
Assert WINDOW is still on its row."
  (let ((id (org-iw-cmd-test--window-row window)))
    (pop-to-buffer (org-iw-test-visit "d.org") t)
    (should-not (eq (selected-window) window))
    (should (equal (org-iw-cmd-test--window-row window) id))))

(ert-deftest org-iw-cmd-test-view-redraw-keeps-window-point ()
  "A redraw leaves an unselected window showing the view on its row.
The redraw is called directly: this pins its window step alone."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((window (org-iw-cmd-test--view-on-row "ESSAYS" 2)))
      (org-iw-cmd-test--leave window)
      (with-current-buffer (window-buffer window)
        (org-iw--view-redraw (org-iw--scan)))
      (should (equal (org-iw-cmd-test--window-row window) "b1")))))

(ert-deftest org-iw-cmd-test-view-redraw-goto-id ()
  "Given GOTO-ID, the redraw puts point on its row, if it is listed.
Called directly: `org-iw-view-open' passes GOTO-ID, but the row it
names is the row at point, which the redraw keeps anyway."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--view-on-row "ESSAYS" 2)
    (org-iw--view-redraw (org-iw--scan) "c1")
    (should (equal (tabulated-list-get-id) "c1"))
    (org-iw--view-redraw (org-iw--scan) "d1")
    (should (equal (tabulated-list-get-id) "c1"))))

(ert-deftest org-iw-cmd-test-view-open-keeps-view-row ()
  "RET visits the entry in another window and sets the session.
The view's star moves to it, and its window stays on its row (REQ-013
AC4)."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "essays")
    (let* ((window (org-iw-cmd-test--view-on-row "ESSAYS" 2))
           (view (window-buffer window)))
      (should (equal (org-iw-view-open) "IW ESSAYS 2/3: B"))
      (should-not (eq (selected-window) window))
      (should (equal (org-iw-cmd-test--shown) '("b.org" "B")))
      (should (equal (list (org-iw--session-queue org-iw--session)
                           (org-iw--session-id org-iw--session)
                           (org-iw--session-title org-iw--session))
                     '("ESSAYS" "b1" "B")))
      (should (equal (mapcar (lambda (row) (aref (cadr row) 0))
                             (buffer-local-value 'tabulated-list-entries view))
                     '("1" "2*" "3")))
      (should (equal (org-iw-cmd-test--window-row window) "b1"))
      (select-window window)
      (should (equal (tabulated-list-get-id) "b1")))))

(ert-deftest org-iw-cmd-test-list-queue-keeps-view-row ()
  "Showing a view again from another window finds it on its row."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((window (org-iw-cmd-test--view-on-row "ESSAYS" 3)))
      (org-iw-cmd-test--leave window)
      (org-iw-list-queue "ESSAYS")
      (should (eq (selected-window) window))
      (should (equal (tabulated-list-get-id) "c1")))))

(ert-deftest org-iw-cmd-test-view-open-acts-afresh ()
  "RET opens the row's entry in the view's queue, at its fresh position.
The session is in another queue, and the order changed after the view
was drawn."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "drafts")
    (org-iw-cmd-test--view-on-row "ESSAYS" 2)
    (org-iw-cmd-test--set-rank "a.org" 1024 4096)
    (should (equal (org-iw-view-open) "IW ESSAYS 1/3: B"))
    (should (equal (org-iw--session-queue org-iw--session) "ESSAYS"))))

(ert-deftest org-iw-cmd-test-view-open-refuses-off-row ()
  "RET off a row refuses: in an empty view, and past the last row."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (let ((org-iw-queues '(("ideas" :name "Ideas"))))
      (org-iw-list-queue "ideas"))
    (org-iw-cmd-test--should-refuse-cleanly "no entry at point"
                                            #'org-iw-view-open)
    (org-iw-list-queue "ESSAYS")
    (goto-char (point-max))
    (org-iw-cmd-test--should-refuse-cleanly "no entry at point"
                                            #'org-iw-view-open)))

(ert-deftest org-iw-cmd-test-view-open-refuses-absent-entry ()
  "RET on a row whose entry has left the queue refuses, naming it.
The row is the session's, its title bold; the refusal is plain text."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-visit-next "ESSAYS")
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--view-on-row "ESSAYS" 1)
    (org-iw-cmd-test--delete-in-a "^:IW_ESSAYS: 1024\n")
    (should (equal-including-properties
             (org-iw-cmd-test--should-refuse-cleanly "" #'org-iw-view-open)
             "A is no longer in queue ESSAYS"))))

;;;; Queue view: refresh (EX-5, VT-1)

(defun org-iw-cmd-test--view-ids (view)
  "Return the IDs of the rows of VIEW, in order."
  (mapcar #'car (buffer-local-value 'tabulated-list-entries view)))

(ert-deftest org-iw-cmd-test-view-refresh-after-undo ()
  "Refresh rescans: it shows an edit, then its undo (REQ-013 AC3).
Point follows its entry by ID."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (org-iw-cmd-test--view "ESSAYS")))
      (should (equal (org-iw-cmd-test--view-ids view) '("a1" "b1" "c1")))
      (goto-char (point-min))
      (with-current-buffer (org-iw-test-visit "a.org")
        (undo-boundary)
        (org-iw-cmd-test--set-rank "a.org" 1024 4096)
        (undo-boundary))
      (revert-buffer)
      (should (equal (org-iw-cmd-test--view-ids view) '("b1" "c1" "a1")))
      (should (equal (tabulated-list-get-id) "a1"))
      (should (equal (line-number-at-pos) 3))
      (with-current-buffer (org-iw-test-visit "a.org")
        (undo))
      (revert-buffer)
      (should (equal (org-iw-cmd-test--view-ids view) '("a1" "b1" "c1"))))))

(ert-deftest org-iw-cmd-test-view-refresh-keeps-line-of-gone-entry ()
  "When the row's entry has left the queue, refresh keeps point on its line.
With fewer rows than that line left, point goes to the last row."
  (pcase-dolist (`(,row ,title ,id) '((2 "B" "c1") (3 "C" "b1")))
    (org-iw-test-with-corpus org-iw-cmd-test--queue
      (org-iw-cmd-test--view-on-row "ESSAYS" row)
      (org-iw-cmd-test--call-at (org-iw-test-marker "b.org" title)
                                #'org-iw-remove "ESSAYS")
      (revert-buffer)
      (should (equal (tabulated-list-get-id) id)))))

;;;; Queue view: move (EX-2, EX-6, VT-2)

(defmacro org-iw-cmd-test--with-session (&rest body)
  "Run BODY after starting a session on ESSAYS; assert BODY keeps it `eq'.
Return BODY's value.  The session is set first, so that the check is
not vacuous."
  (declare (indent 0) (debug t))
  (let ((session (make-symbol "session")))
    `(progn
       (org-iw-visit-next "ESSAYS")
       (let ((,session org-iw--session))
         (should ,session)
         (prog1 (progn ,@body)
           (should (eq org-iw--session ,session)))))))

(defconst org-iw-cmd-test--tied
  `(("a.org" . ,(org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1"))
    ("b.org" . ,(concat (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 5")
                        (org-iw-test-heading "C" "c1" ":IW_ESSAYS: 5")))
    ("d.org" . ,(org-iw-test-heading "D" "d1" ":IW_ESSAYS: 9")))
  "ESSAYS holds A, B, C and D, in that order; B and C are tied at 5.")

(ert-deftest org-iw-cmd-test-view-move-down ()
  "M-<down> moves the entry at point one row down, and point follows.
At the end it is already there, and nothing is written."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--with-session
      (let ((view (window-buffer (org-iw-cmd-test--view-on-row "ESSAYS" 1))))
        (should (equal (org-iw-cmd-test--should-move
                        #'org-iw-view-move-down "a.org" 1024 2560)
                       "Moved A to 2/3 (saved)"))
        (should (equal (org-iw-cmd-test--view-ids view) '("b1" "a1" "c1")))
        (should (equal (tabulated-list-get-id) "a1"))
        (forward-line 1)
        (should (equal (org-iw-cmd-test--should-write-nothing
                        #'org-iw-view-move-down)
                       "C already at 3/3"))))))

(ert-deftest org-iw-cmd-test-view-move-up ()
  "M-<up> moves the entry at point one row up, and point follows.
At the front it is already there, and nothing is written."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--with-session
      (let ((view (window-buffer (org-iw-cmd-test--view-on-row "ESSAYS" 3))))
        (should (equal (org-iw-cmd-test--should-move
                        #'org-iw-view-move-up "b.org" 3072 1536)
                       "Moved C to 2/3 (saved)"))
        (should (equal (org-iw-cmd-test--view-ids view) '("a1" "c1" "b1")))
        (should (equal (tabulated-list-get-id) "c1"))
        (goto-char (point-min))
        (should (equal (org-iw-cmd-test--should-write-nothing
                        #'org-iw-view-move-up)
                       "A already at 1/3"))))))

(ert-deftest org-iw-cmd-test-view-move-ties ()
  "Moving out of a tied pair succeeds; moving between it refuses."
  (pcase-dolist (`(,row ,command ,to ,text)
                 '((3 org-iw-view-move-up 3 "Moved C to 2/4 (saved)")
                   (2 org-iw-view-move-down 7 "Moved B to 3/4 (saved)")))
    (org-iw-test-with-corpus org-iw-cmd-test--tied
      (org-iw-cmd-test--open-all)
      (org-iw-cmd-test--with-session
        (org-iw-cmd-test--view-on-row "ESSAYS" row)
        (should (equal (org-iw-cmd-test--should-move command "b.org" 5 to)
                       text)))))
  (org-iw-test-with-corpus org-iw-cmd-test--tied
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--view-on-row "ESSAYS" 4)
    (should (equal (org-iw-cmd-test--should-refuse-cleanly
                    "" #'org-iw-view-move-up)
                   (org-iw-cmd-test--no-room "at position 3/4")))))

;;;; Queue view: mark (EX-3, EX-4, VT-3)

(defun org-iw-cmd-test--goto-row (id)
  "Put point on the view row of the entry ID, in the current buffer."
  (goto-char (point-min))
  (while (not (equal (tabulated-list-get-id) id))
    (when (eobp)
      (ert-fail (list "No row" id)))
    (forward-line 1)))

(defun org-iw-cmd-test--view-tags (view)
  "Return (ID . TAG) for each row of VIEW with a tag, in order.
The tag is the row's first 2 columns, the padding, if not blank."
  (with-current-buffer view
    (save-excursion
      (goto-char (point-min))
      (let (tags)
        (while (not (eobp))
          (let ((id (tabulated-list-get-id))
                (tag (string-trim (buffer-substring-no-properties
                                   (point) (min (+ (point) 2)
                                                (line-end-position))))))
            (when (and id (not (string-empty-p tag)))
              (push (cons id tag) tags)))
          (forward-line 1))
        (nreverse tags)))))

(ert-deftest org-iw-cmd-test-view-mark ()
  "Mark tags the entry at point, replacing any mark; unmark clears it.
Neither rescans, and neither shows a message."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let* ((view (window-buffer (org-iw-cmd-test--view-on-row "ESSAYS" 2)))
           (rows tabulated-list-entries))
      (should-not (org-iw-view-mark))
      (should (equal (org-iw-cmd-test--view-tags view) '(("b1" . ">"))))
      (org-iw-cmd-test--goto-row "c1")
      (should-not (org-iw-view-mark))
      (should (equal (org-iw-cmd-test--view-tags view) '(("c1" . ">"))))
      (org-iw-cmd-test--goto-row "a1")
      (should-not (org-iw-view-unmark))
      (should-not (org-iw-cmd-test--view-tags view))
      (should (eq tabulated-list-entries rows)))))

(ert-deftest org-iw-cmd-test-view-mark-survives-refresh ()
  "The mark survives `revert-buffer' and `org-iw-list-queue', tag shown.
The tag is asserted before `org-iw--view-mark': a refresh that prints
again after re-tagging erases the tag but keeps the variable."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (window-buffer (org-iw-cmd-test--view-on-row "ESSAYS" 2))))
      (org-iw-view-mark)
      (revert-buffer)
      (should (equal (org-iw-cmd-test--view-tags view) '(("b1" . ">"))))
      (should (equal (buffer-local-value 'org-iw--view-mark view) "b1"))
      (org-iw-cmd-test--goto-row "a1")
      (should (equal (org-iw-cmd-test--should-move
                      #'org-iw-view-place-before "b.org" 2048 0)
                     "Moved B to 1/3 (saved)"))
      (org-iw-cmd-test--goto-row "c1")
      (org-iw-view-mark)
      (org-iw-list-queue "ESSAYS")
      (should (eq (current-buffer) view))
      (should (equal (org-iw-cmd-test--view-tags view) '(("c1" . ">")))))))

(ert-deftest org-iw-cmd-test-view-mark-survives-reprint ()
  "The mark's tag survives tabulated-list's own reprints, as by }.
So b and a act only on a mark the user can see."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (org-iw-cmd-test--view "ESSAYS")))
      (org-iw-cmd-test--mark-row "b1")
      (call-interactively #'tabulated-list-widen-current-column)
      (should (equal (org-iw-cmd-test--view-tags view) '(("b1" . ">")))))))

(ert-deftest org-iw-cmd-test-view-mark-cleared-when-entry-leaves ()
  "A refresh clears the mark when its entry has left the queue."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (window-buffer (org-iw-cmd-test--view-on-row "ESSAYS" 2))))
      (org-iw-view-mark)
      (org-iw-cmd-test--call-at (org-iw-test-marker "b.org" "B")
                                #'org-iw-remove "ESSAYS")
      (with-current-buffer view
        (revert-buffer)
        (should-not (org-iw-cmd-test--view-tags view))
        (org-iw-cmd-test--goto-row "a1")
        (should (equal (org-iw-cmd-test--refusal #'org-iw-view-place-before)
                       "no marked entry; mark one with m"))))))

;;;; Queue view: place (EX-3, EX-6, VT-2)

(defun org-iw-cmd-test--mark-row (id)
  "Mark the entry ID in the view in the current buffer."
  (org-iw-cmd-test--goto-row id)
  (org-iw-view-mark))

(ert-deftest org-iw-cmd-test-view-place ()
  "Place the marked entry before or after the entry at point.
Point follows the marked entry, and the mark clears."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--with-session
      (let ((view (org-iw-cmd-test--view "ESSAYS")))
        (org-iw-cmd-test--mark-row "c1")
        (org-iw-cmd-test--goto-row "a1")
        (should (equal (org-iw-cmd-test--should-move
                        #'org-iw-view-place-before "b.org" 3072 0)
                       "Moved C to 1/3 (saved)"))
        (should (equal (org-iw-cmd-test--view-ids view) '("c1" "a1" "b1")))
        (should (equal (tabulated-list-get-id) "c1"))
        (should-not (org-iw-cmd-test--view-tags view))
        (should-not (buffer-local-value 'org-iw--view-mark view)))))
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--with-session
      (org-iw-cmd-test--view "ESSAYS")
      (org-iw-cmd-test--mark-row "a1")
      (org-iw-cmd-test--goto-row "c1")
      (should (equal (org-iw-cmd-test--should-move
                      #'org-iw-view-place-after "a.org" 1024 4096)
                     "Moved A to 3/3 (saved)")))))

(ert-deftest org-iw-cmd-test-view-mark-is-per-view ()
  "Each view keeps its own mark: showing another queue leaves it."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (org-iw-cmd-test--view "ESSAYS")))
      (org-iw-cmd-test--mark-row "c1")
      (org-iw-cmd-test--view "DRAFTS")
      (set-window-buffer (selected-window) view)
      (with-current-buffer view
        (should (equal (org-iw-cmd-test--view-tags view) '(("c1" . ">"))))
        (org-iw-cmd-test--goto-row "a1")
        (should (equal (org-iw-view-place-before)
                       "Moved C to 1/3 (saved)"))))))

(ert-deftest org-iw-cmd-test-view-place-adjacent ()
  "Placing the marked entry where it is writes nothing; the mark clears.
That includes placing it beside itself."
  (pcase-dolist (`(,marked ,anchor ,text) '(("a1" "b1" "A already at 1/3")
                                            ("b1" "b1" "B already at 2/3")))
    (org-iw-test-with-corpus org-iw-cmd-test--queue
      (org-iw-cmd-test--open-all)
      (let ((view (org-iw-cmd-test--view "ESSAYS")))
        (org-iw-cmd-test--mark-row marked)
        (org-iw-cmd-test--goto-row anchor)
        (should (equal (org-iw-cmd-test--should-write-nothing
                        #'org-iw-view-place-before)
                       text))
        (should-not (org-iw-cmd-test--view-tags view))))))

(defun org-iw-cmd-test--should-refuse-keeping-mark (view text fn)
  "Assert FN refuses with exactly TEXT, changing nothing; VIEW keeps its mark.
The mark must be tagged before and after."
  (let ((tags (org-iw-cmd-test--view-tags view)))
    (should tags)
    (should (equal (org-iw-cmd-test--should-refuse-cleanly "" fn) text))
    (should (equal (org-iw-cmd-test--view-tags view) tags))))

(ert-deftest org-iw-cmd-test-view-place-refusals ()
  "A refused place writes nothing and keeps the mark.
It refuses without a mark, without room, or when the marked entry or
the entry at point has left the queue."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--view-on-row "ESSAYS" 1)
    (should (equal (org-iw-cmd-test--should-refuse-cleanly
                    "" #'org-iw-view-place-before)
                   "no marked entry; mark one with m")))
  (pcase-dolist (`(,anchor ,command ,where)
                 '(("c1" org-iw-view-place-before "before C")
                   ("b1" org-iw-view-place-after "after B")))
    (org-iw-test-with-corpus org-iw-cmd-test--tied
      (org-iw-cmd-test--open-all)
      (let ((view (org-iw-cmd-test--view "ESSAYS")))
        (org-iw-cmd-test--mark-row "d1")
        (org-iw-cmd-test--goto-row anchor)
        (org-iw-cmd-test--should-refuse-keeping-mark
         view (org-iw-cmd-test--no-room where) command))))
  (pcase-dolist (`(,marked ,anchor ,command)
                 '(("a1" "c1" org-iw-view-place-after)
                   ("c1" "a1" org-iw-view-place-before)))
    (org-iw-test-with-corpus org-iw-cmd-test--queue
      (org-iw-cmd-test--open-all)
      (let ((view (org-iw-cmd-test--view "ESSAYS")))
        (org-iw-cmd-test--mark-row marked)
        (org-iw-cmd-test--goto-row anchor)
        (org-iw-cmd-test--delete-in-a "^:IW_ESSAYS: 1024\n")
        (org-iw-cmd-test--should-refuse-keeping-mark
         view "A is no longer in queue ESSAYS" command)))))

;;;; Queue view: remove (EX-3, EX-5, EX-6, VT-2)

(ert-deftest org-iw-cmd-test-view-remove ()
  "D confirms, then deletes the entry's rank from its file.
Point goes to the next row, else to the previous one."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--with-session
      (let ((view (org-iw-cmd-test--view "ESSAYS")))
        (org-iw-cmd-test--goto-row "b1")
        (org-iw-cmd-test--with-prompt :yes
          (should (equal (org-iw-cmd-test--should-delete
                          #'org-iw-view-remove "b.org" ":IW_ESSAYS: 2048")
                         "Removed B from ESSAYS (saved)"))
          (should (equal (org-iw-cmd-test--prompted :prompt)
                         '("Remove B from ESSAYS? "))))
        (should (equal (org-iw-cmd-test--view-ids view) '("a1" "c1")))
        (should (equal (tabulated-list-get-id) "c1"))
        (let ((org-iw-queues '(("essays" :name "Essays"))))
          (org-iw-cmd-test--with-prompt :yes
            (should (equal (org-iw-cmd-test--should-delete
                            #'org-iw-view-remove "b.org" ":IW_ESSAYS: 3072")
                           "Removed C from Essays (saved)"))
            (should (equal (org-iw-cmd-test--prompted :prompt)
                           '("Remove C from Essays? ")))))
        (should (equal (org-iw-cmd-test--view-ids view) '("a1")))
        (should (equal (tabulated-list-get-id) "a1"))))))

(ert-deftest org-iw-cmd-test-view-remove-declined ()
  "D answered no changes nothing, shows no message and does not redraw.
The prompt gives the scanned title, links and all, not the row's."
  (org-iw-test-with-corpus org-iw-cmd-test--view-corpus
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--view-on-row "ESSAYS" 2)
    (let ((rows tabulated-list-entries))
      (org-iw-cmd-test--with-prompt :no
        (should-not (org-iw-cmd-test--should-change-nothing
                     #'org-iw-view-remove))
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       '("Remove Read [[https://x.org][the paper]] from ESSAYS? "))))
      (should (eq tabulated-list-entries rows)))))

(ert-deftest org-iw-cmd-test-view-remove-absent-before-prompt ()
  "D on an entry that has left the queue refuses before confirming."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--view-on-row "ESSAYS" 1)
    (org-iw-cmd-test--delete-in-a "^:IW_ESSAYS: 1024\n")
    (org-iw-cmd-test--with-prompt nil
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "" #'org-iw-view-remove)
                     "A is no longer in queue ESSAYS")))))

(ert-deftest org-iw-cmd-test-view-remove-session-entry ()
  "D on the session's entry keeps the session and gives the hint.
The view no longer stars any row."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--with-session
      (org-iw-cmd-test--view-on-row "ESSAYS" 1)
      (org-iw-cmd-test--with-prompt :yes
        (should (equal (org-iw-view-remove)
                       (concat "Removed A from ESSAYS (saved). "
                               org-iw-cmd-test--hint))))
      (should-not (seq-find (lambda (row)
                              (string-suffix-p "*" (aref (cadr row) 0)))
                            tabulated-list-entries)))))

(ert-deftest org-iw-cmd-test-view-remove-marked-entry ()
  "D on the marked entry clears the mark."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (org-iw-cmd-test--view "ESSAYS")))
      (org-iw-cmd-test--mark-row "b1")
      (org-iw-cmd-test--with-prompt :yes
        (org-iw-view-remove))
      (should-not (org-iw-cmd-test--view-tags view))
      (org-iw-cmd-test--goto-row "a1")
      (should (equal (org-iw-cmd-test--refusal #'org-iw-view-place-before)
                     "no marked entry; mark one with m")))))

;;;; Queue view: stale rows and off-row actions (EX-5, EX-6)

(defun org-iw-cmd-test--stale-view ()
  "Show ESSAYS with A on row 3, then undo A's move to the end behind it.
The rows are stale: A is first in truth.  Return the view."
  (let ((view (org-iw-cmd-test--view "ESSAYS")))
    (with-current-buffer (org-iw-test-visit "a.org")
      (undo-boundary)
      (org-iw-cmd-test--set-rank "a.org" 1024 4096)
      (undo-boundary))
    (revert-buffer)
    (should (equal (org-iw-cmd-test--view-ids view) '("b1" "c1" "a1")))
    (with-current-buffer (org-iw-test-visit "a.org")
      (undo))
    (org-iw-cmd-test--goto-row "a1")
    view))

(ert-deftest org-iw-cmd-test-view-acts-on-fresh-state ()
  "An action on a stale row acts on a fresh scan, not on the row (I12)."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--stale-view)
    (should (equal (org-iw-cmd-test--should-write-nothing
                    #'org-iw-view-move-up)
                   "A already at 1/3")))
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--stale-view)
    (org-iw-cmd-test--with-prompt :yes
      (should (equal (org-iw-cmd-test--should-delete
                      #'org-iw-view-remove "a.org" ":IW_ESSAYS: 1024")
                     "Removed A from ESSAYS (saved)")))))

(ert-deftest org-iw-cmd-test-view-remove-stale-goes-to-next-row ()
  "D on a stale row puts point on the next row shown, not the next scanned.
The rows show B C A; in truth the order is A B C.  Removing C, point
goes to A."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (org-iw-cmd-test--stale-view)))
      (org-iw-cmd-test--goto-row "c1")
      (org-iw-cmd-test--with-prompt :yes
        (org-iw-view-remove))
      (should (equal (org-iw-cmd-test--view-ids view) '("a1" "b1")))
      (should (equal (tabulated-list-get-id) "a1")))))

(ert-deftest org-iw-cmd-test-view-actions-refuse-off-row ()
  "Each view action refuses off a row: in an empty view, or past the rows.
Placing refuses so even with a mark set."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (org-iw-cmd-test--open-all)
    (dolist (queue '("ideas" "ESSAYS"))
      (org-iw-cmd-test--view-on-row queue 1)
      (when (tabulated-list-get-id)
        (org-iw-view-mark))
      (goto-char (point-max))
      (dolist (command '(org-iw-view-move-up org-iw-view-move-down
                         org-iw-view-mark org-iw-view-unmark
                         org-iw-view-place-before org-iw-view-place-after
                         org-iw-view-remove))
        (org-iw-cmd-test--with-prompt nil
          (should (equal (org-iw-cmd-test--should-refuse-cleanly "" command)
                         "no entry at point")))))))

(provide 'org-iw-test)
;;; org-iw-test.el ends here
