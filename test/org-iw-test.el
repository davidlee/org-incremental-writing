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

;; ERT tests for the command layer: `org-iw-add',
;; `org-iw-add-document', `org-iw-add-files', the session and its mode
;; line, `org-iw-visit-next', `org-iw-continue', `org-iw-move',
;; `org-iw-end-session', `org-iw-remove', the queue view
;; (`org-iw-list-queue' and its commands), redistribution and
;; `org-iw-normalise', and the private helpers the commands share.
;; Every prompt is stubbed, so that no test reads from standard input.

;;; Code:

(require 'cl-lib)
(require 'dired)
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
when REQUIRE-MATCH is t.  An answer that is a function is called
with no arguments when its turn comes, and its value is the answer,
so it may change buffers or files while the prompt is up.  Each call
is recorded, in order, in `org-iw-cmd-test--prompts' as a
plist: (:prompt :collection :require-match :default :order :annotate)
for `completing-read', :order being `org-iw-cmd-test--cycle-order',
and (:prompt) for `y-or-n-p'."
  (declare (indent 1) (debug t))
  (let ((answers (make-symbol "answers"))
        (reply (make-symbol "reply")))
    `(let ((org-iw-cmd-test--prompts nil)
           (,answers (ensure-list ,answer)))
       (cl-flet ((,reply (call valid-p)
                   (setq org-iw-cmd-test--prompts
                         (append org-iw-cmd-test--prompts (list call)))
                   (let* ((prompt (plist-get call :prompt))
                          (reply (or (let ((answer (pop ,answers)))
                                       (if (functionp answer)
                                           (funcall answer)
                                         answer))
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

(ert-deftest org-iw-cmd-test-with-prompt-function-answer ()
  "A function answer is called once, in turn, and its value is the answer."
  (let ((calls nil))
    (org-iw-cmd-test--with-prompt
        (list :yes
              (lambda () (push 'second calls) :no)
              (lambda () (push 'third calls) "text"))
      (should (eq (y-or-n-p "One? ") t))
      (should-not calls)
      (should (eq (y-or-n-p "Two? ") nil))
      (should (equal calls '(second)))
      (should (equal (completing-read "Three: " '("w")) "text"))
      (should (equal calls '(third second)))
      (should (equal (org-iw-cmd-test--prompted :prompt)
                     '("One? " "Two? " "Three: ")))))
  (org-iw-cmd-test--with-prompt (lambda () "yes")
    (should-error (y-or-n-p "Sure? ") :type 'ert-test-failed))
  (org-iw-cmd-test--with-prompt (lambda () nil)
    (should-error (y-or-n-p "Sure? ") :type 'ert-test-failed)))

;;;; Private helpers

(defun org-iw-cmd-test--no-room (where)
  "Return the refusal when ESSAYS has no rank left WHERE.
WHERE carries its preposition, as in \"at the end\"."
  (concat "no room " where " in ESSAYS; normalise it with org-iw-normalise"))

(defun org-iw-cmd-test--refusal (fn)
  "Call FN, assert it refuses, and return the refusal message."
  (cadr (should-error (funcall fn) :type 'org-iw-refusal)))

(ert-deftest org-iw-cmd-test-refuse-no-room ()
  "No room is refused naming where and the queue, with no advice."
  (should (equal (org-iw-cmd-test--no-room "at the end")
                 (concat "no room at the end in ESSAYS; normalise it with"
                         " org-iw-normalise")))
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
        (should (equal (plist-get call :prompt) "Placement in OTHER: "))
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
      (pcase-let ((`(,call) org-iw-cmd-test--prompts))
        (should (equal (plist-get call :prompt) "Placement in Articles: "))
        (should (equal (plist-get call :order) '("Soon" "End")))))))

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

;;;; The add step (`org-iw--add-entry')

;; Tested apart: its plain-data result is what a batch of adds consumes.

(defun org-iw-cmd-test--add-entry (marker document)
  "Return `org-iw--add-entry' of MARKER, a DOCUMENT or not, to ESSAYS.
The entry goes at the end, against a fresh scan."
  (let ((scan (org-iw--scan)))
    (org-iw--add-entry scan (org-iw--order scan "ESSAYS") marker "ESSAYS"
                       'end document)))

(defun org-iw-cmd-test--should-add-entry (marker document depth memberships)
  "Assert the add step adds MARKER, a DOCUMENT or not, at DEPTH, saved.
Its entry must have MEMBERSHIPS and be `equal' to the one a fresh
scan reads.  Return the entry."
  (pcase-let ((`(added ,added-depth ,status ,entry)
               (org-iw-cmd-test--add-entry marker document)))
    (should (equal added-depth depth))
    (should (eq status 'saved))
    (should (equal (org-iw-entry-memberships entry) memberships))
    (should (equal entry (org-iw--find-entry
                          (org-iw-scan-entries (org-iw--scan))
                          (org-iw-entry-id entry) (org-iw-entry-file entry))))
    entry))

(ert-deftest org-iw-cmd-test-add-entry-added-entry-equals-rescan ()
  "The added entry is the member a fresh scan reads after the write.
For a heading without an ID, a nested heading in another queue, and
the document."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-org "Intro.")
                            (org-iw-test-heading "Member" "m1"
                                                 ":IW_ESSAYS: 1024")
                            (org-iw-test-org "* New")
                            "*" (org-iw-test-heading "Nested" "n1"
                                                     ":IW_OTHER: 5"))))
    (let ((new (org-iw-cmd-test--should-add-entry
                (org-iw-test-marker "a.org" "New") nil 1
                '(("ESSAYS" . 2048))))
          (nested (org-iw-cmd-test--should-add-entry
                   (with-current-buffer (org-iw-test-visit "a.org")
                     (goto-char (point-max))
                     (org-back-to-heading)
                     (point-marker))
                   nil 2 '(("OTHER" . 5) ("ESSAYS" . 3072))))
          (document (org-iw-cmd-test--should-add-entry
                     (org-iw-test-marker "a.org" nil) t 3
                     '(("ESSAYS" . 4096)))))
      (should (org-iw-entry-id new))
      (should (equal (org-iw-entry-outline nested) '("New")))
      (should (equal (org-iw-entry-title document) "a")))))

(ert-deftest org-iw-cmd-test-add-entry-existing ()
  "The add step finds a member at its 1-based position; nothing changes."
  (org-iw-test-with-corpus (org-iw-cmd-test--queue-of-three ":IW_ESSAYS: 2048")
    (let ((marker (org-iw-test-marker "a.org" "Target")))
      (should (equal (org-iw-cmd-test--should-change-nothing
                      (lambda () (org-iw-cmd-test--add-entry marker nil)))
                     '(existing 2))))))

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

(defun org-iw-cmd-test--should-refuse (marker queue substring
                                              &optional command)
  "Assert COMMAND at MARKER to QUEUE refuses with SUBSTRING, changing nothing.
COMMAND defaults to `org-iw-add'.  See
`org-iw-cmd-test--should-refuse-cleanly'.  Return the refusal message."
  (org-iw-cmd-test--should-refuse-cleanly
   substring (lambda ()
               (org-iw-cmd-test--call-at marker (or command #'org-iw-add)
                                         queue))))

(defun org-iw-cmd-test--refuses (text queue substring
                                      &optional title command)
  "Assert COMMAND refuses with SUBSTRING in a corpus holding a.org as TEXT.
COMMAND, by default `org-iw-add', is called at heading TITLE of a.org,
or its start if TITLE is nil, to QUEUE.  Return the refusal message."
  (org-iw-test-with-corpus `(("a.org" . ,text))
    (org-iw-cmd-test--should-refuse (org-iw-test-marker "a.org" title)
                                    queue substring command)))

(defconst org-iw-cmd-test--intro
  (org-iw-test-org "Intro." "* H")
  "A file with text before its first heading H.")

(ert-deftest org-iw-cmd-test-add-refuses-outside-sources ()
  "Add refuses a file outside the sources and a buffer with no file."
  (org-iw-test-with-corpus '(("a.org" . "* A\n") ("b.org" . "* B\n"))
    (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
      (org-iw-cmd-test--should-refuse (org-iw-test-marker "b.org" "B")
                                      "ESSAYS" "not a source file"))
    (with-temp-buffer
      (insert "* H\n")
      (org-mode)
      (org-iw-cmd-test--should-refuse (copy-marker (point-min))
                                      "ESSAYS" "not a source file"))))


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
                              "ESSAYS"
                              (format "entry at point is excluded (%s)" type)
                              "H")))

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
      (org-iw-cmd-test--should-refuse (org-iw-test-marker "b.org" nil)
                                      "ESSAYS" "not a source file")))
  (org-iw-cmd-test--refuses org-iw-cmd-test--intro "ess_ays"
                            "invalid queue ID")
  (org-iw-cmd-test--refuses org-iw-cmd-test--malformed "ess_ays"
                            "invalid queue ID" "H"))

(ert-deftest org-iw-cmd-test-add-refuses-before-prompting ()
  "Interactively, a non-source buffer never prompts."
  (org-iw-cmd-test--with-prompt nil
    (with-temp-buffer
      (insert "* H\n")
      (org-mode)
      (should-error (call-interactively #'org-iw-add)
                    :type 'org-iw-refusal))))

;;;; Add: the document (EX-3)

(ert-deftest org-iw-cmd-test-add-before-first-heading-enrols-document ()
  "Before the first heading Add enrols the document, in a drawer at the top.
It replaces org-iw-cmd-test-add-refuses-document-target: Add no longer
refuses there.  The heading is untouched, and a fresh scan has the
document as a member, titled by its file."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--intro))
    (let ((marker (org-iw-test-marker "a.org" nil)))
      (should (equal (org-iw-cmd-test--call-at marker #'org-iw-add "ESSAYS")
                     "Added to ESSAYS at 1/1 (saved)"))
      (org-iw-test-should-add-drawer org-iw-cmd-test--intro marker nil)
      (should (equal (mapcar #'org-iw-entry-title
                             (org-iw--order (org-iw--scan) "ESSAYS"))
                     '("a"))))))

(defconst org-iw-cmd-test--nested
  (org-iw-test-org "#+title: Doc" "Intro." "* A" "** B" "Body of B." "* C")
  "A document with a preamble, titled Doc, and a nested heading B.")

(defun org-iw-cmd-test--at-text (name text)
  "Return a marker at TEXT in corpus file NAME, after it."
  (with-current-buffer (org-iw-test-visit name)
    (org-with-wide-buffer
     (goto-char (point-min))
     (search-forward text)
     (point-marker))))

(defun org-iw-cmd-test--should-have-added-document (marker &optional title)
  "Assert the document of MARKER's file is in ESSAYS, alone, titled TITLE.
Its file must be `org-iw-cmd-test--nested' plus a drawer at the top,
saved, and its base buffer unmodified.  TITLE defaults to Doc."
  (should-not (buffer-modified-p (org-iw-test-base marker)))
  (org-iw-test-should-add-drawer org-iw-cmd-test--nested marker nil)
  (should (equal (mapcar #'org-iw-entry-title
                         (org-iw--order (org-iw--scan) "ESSAYS"))
                 (list (or title "Doc")))))

(ert-deftest org-iw-cmd-test-add-document-from-heading ()
  "Add-document from a nested heading's body adds the document only."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--nested))
    (let ((marker (org-iw-cmd-test--at-text "a.org" "Body of B.")))
      (should (equal (org-iw-cmd-test--call-at marker #'org-iw-add-document
                                               "ESSAYS")
                     "Added to ESSAYS at 1/1 (saved)"))
      (org-iw-cmd-test--should-have-added-document marker))))

(ert-deftest org-iw-cmd-test-add-document-narrowed ()
  "Add-document ignores a narrowing to a subtree, and keeps it."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--nested))
    (let ((marker (org-iw-cmd-test--at-text "a.org" "Body of B.")))
      (with-current-buffer (marker-buffer marker)
        (goto-char marker)
        (org-narrow-to-subtree)
        (let ((narrowed (buffer-string)))
          (org-iw-add-document "ESSAYS")
          (should (equal (buffer-string) narrowed))))
      (org-iw-cmd-test--should-have-added-document marker))))

(ert-deftest org-iw-cmd-test-add-document-from-indirect-buffer ()
  "Add-document works in a narrowed indirect buffer; the base is saved."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--nested))
    (org-iw-test-call-with-indirect
     (org-iw-cmd-test--at-text "a.org" "Body of B.")
     (lambda (indirect-marker)
       (org-iw-cmd-test--narrow-to-line "Body of B.")
       (should (equal (org-iw-add-document "ESSAYS")
                      "Added to ESSAYS at 1/1 (saved)"))
       (should (equal (buffer-string) "Body of B."))
       (org-iw-cmd-test--should-have-added-document indirect-marker)))))

(ert-deftest org-iw-cmd-test-add-document-refuses-before-prompting ()
  "Interactively, Add-document refuses a buffer it cannot use first.
That is one with no source file, and a source file not in Org mode."
  (org-iw-cmd-test--with-prompt nil
    (with-temp-buffer
      (insert "Intro.\n")
      (org-mode)
      (should (string-search "not a source file"
                             (cadr (should-error
                                    (call-interactively #'org-iw-add-document)
                                    :type 'org-iw-refusal)))))
    (org-iw-test-with-corpus `(("a.txt" . "Intro.\n"))
      (let ((org-iw-sources (list (org-iw-test-path "a.txt"))))
        (with-current-buffer (org-iw-test-visit "a.txt")
          (text-mode)
          (should (string-search
                   "buffer not in Org mode"
                   (cadr (should-error
                          (call-interactively #'org-iw-add-document)
                          :type 'org-iw-refusal)))))))))

(ert-deftest org-iw-cmd-test-add-document-refuses-outside-sources ()
  "Called from Lisp too, Add-document refuses a file outside the sources."
  (org-iw-test-with-corpus `(("a.org" . "* A\n")
                             ("b.org" . ,org-iw-cmd-test--intro))
    (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
      (org-iw-cmd-test--should-refuse (org-iw-test-marker "b.org" nil)
                                      "ESSAYS" "not a source file"
                                      #'org-iw-add-document))))

;;;; Add-document: identity (EX-4)

(defun org-iw-cmd-test--add-document-at-start (name)
  "Call `org-iw-add-document' to ESSAYS at the start of corpus file NAME.
Return the message."
  (org-iw-cmd-test--call-at (org-iw-test-marker name nil)
                            #'org-iw-add-document "ESSAYS"))

(ert-deftest org-iw-cmd-test-add-denote-note-no-id ()
  "A Denote note gains only a drawer and its rank, never an ID (I2).
With a preamble, by Add before the first heading, and starting with a
heading, by Add-document; the heading is byte-identical.  The member's
ID is the Denote identifier."
  (pcase-dolist (`(,text ,command)
                 `((,(org-iw-test-org "#+title: T" "Text." "* H") org-iw-add)
                   (,(org-iw-test-heading "H" "h1") org-iw-add-document)))
    (let ((note (org-iw-test-denote-file org-iw-test-denote-id text)))
      (org-iw-test-with-corpus (list note)
        (should (equal (org-iw-cmd-test--call-at
                        (org-iw-test-marker (car note) nil) command "ESSAYS")
                       "Added to ESSAYS at 1/1 (saved)"))
        (should (equal (org-iw-test-changed-lines
                        text (org-iw-test-file-string (car note)))
                       '(nil ":PROPERTIES:" ":IW_ESSAYS: 1024" ":END:")))
        (should (equal (org-iw-cmd-test--order "ESSAYS")
                       (list org-iw-test-denote-id)))))))

(ert-deftest org-iw-cmd-test-add-document-inserts-id ()
  "A document with neither an ID nor a Denote name is given an ID."
  (let ((text (org-iw-test-org "#+title: T" "Text." "* H")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (org-iw-cmd-test--add-document-at-start "a.org")
      (org-iw-test-should-add-drawer text (org-iw-test-marker "a.org" nil)
                                     nil))))

(ert-deftest org-iw-cmd-test-add-denote-name-without-denote-gets-id ()
  "Without Denote, a file named in its scheme is a plain file: it gains an ID.
It needs no Denote, so it runs where Denote is not installed."
  (let ((text (org-iw-test-org "Text." "* H"))
        (name (org-iw-test-denote-name org-iw-test-denote-id)))
    (org-iw-test-without-denote
      (org-iw-test-with-corpus `((,name . ,text))
        (org-iw-cmd-test--add-document-at-start name)
        (org-iw-test-should-add-drawer
         text (org-iw-test-marker name nil) nil)))))

(ert-deftest org-iw-cmd-test-add-document-heading-first-file ()
  "A file starting with a heading gains a drawer above the heading.
The heading and its drawer are byte-identical (I3).  A first heading
already in the queue, with an ID, is not taken for the document."
  (pcase-dolist (`(,text ,rank ,order)
                 `((,(org-iw-test-org "* H" "Body.") 1024 1)
                   (,(concat (org-iw-test-heading "H" "h1" ":IW_ESSAYS: 1024")
                             (org-iw-test-org "Body."))
                    2048 2)))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "H")))
        (should (string-prefix-p
                 "Added to ESSAYS"
                 (org-iw-cmd-test--call-at marker #'org-iw-add-document
                                           "ESSAYS")))
        (org-iw-test-should-add-drawer text marker nil rank)
        (should (equal (length (org-iw-cmd-test--order "ESSAYS")) order))))))

;;;; Add-document: members and refusals (EX-5)

(defconst org-iw-cmd-test--document-in-other
  (org-iw-test-org ":PROPERTIES:" ":ID: d1" ":IW_OTHER: 5" ":END:"
                   "#+title: Doc" "* H")
  "A document d1 in queue OTHER at 5.")

(ert-deftest org-iw-cmd-test-add-document-member-is-no-op ()
  "Adding a member document reports its position; nothing changes."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-org ":PROPERTIES:" ":ID: d1"
                                     ":IW_ESSAYS: 1024" ":END:" "* H")))
    (org-iw-cmd-test--open-all)
    (should (equal (org-iw-cmd-test--should-change-nothing
                    (lambda ()
                      (org-iw-cmd-test--add-document-at-start "a.org")))
                   "Already in ESSAYS at 1/1"))))

(ert-deftest org-iw-cmd-test-add-document-keeps-other-queue ()
  "A document in another queue gains one line; that queue is untouched."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--document-in-other))
    (org-iw-cmd-test--add-document-at-start "a.org")
    (should (equal (org-iw-test-changed-lines
                    org-iw-cmd-test--document-in-other
                    (org-iw-test-file-string "a.org"))
                   '(nil ":IW_ESSAYS: 1024")))
    (should (equal (mapcar (lambda (entry) (org-iw-core-rank entry "OTHER"))
                           (org-iw--order (org-iw--scan) "OTHER"))
                   '(5)))))

(ert-deftest org-iw-cmd-test-add-document-refuses-excluded ()
  "Add-document refuses a document whose IW_ESSAYS the scan excluded."
  (org-iw-cmd-test--refuses
   (org-iw-test-org ":PROPERTIES:" ":ID: d1" ":IW_ESSAYS: soon" ":END:" "* H")
   "ESSAYS" "entry at point is excluded (invalid-rank)" nil
   #'org-iw-add-document))

(ert-deftest org-iw-cmd-test-add-denote-refuses-heading-sharing-identifier ()
  "A heading whose :ID: is the note's Denote identifier blocks the note."
  (org-iw-test-with-corpus
      (list (org-iw-test-denote-file
             org-iw-test-denote-id
             (concat (org-iw-test-org "Intro.")
                     (org-iw-test-heading "H" org-iw-test-denote-id))))
    (org-iw-cmd-test--should-refuse
     (org-iw-test-marker (org-iw-test-denote-name org-iw-test-denote-id)
                         nil)
     "ESSAYS" "ID shared with another entry" #'org-iw-add-document)))

(ert-deftest org-iw-cmd-test-add-denote-refuses-identifier-shared-across-files ()
  "A member file with the same Denote identifier blocks the note."
  (let ((note (org-iw-test-denote-file org-iw-test-denote-id
                                       (org-iw-test-org "Intro.") "one"))
        (other (org-iw-test-denote-file
                org-iw-test-denote-id
                (org-iw-test-org ":PROPERTIES:" ":IW_OTHER: 5" ":END:")
                "two")))
    (org-iw-test-with-corpus (list note other)
      (org-iw-cmd-test--should-refuse (org-iw-test-marker (car note) nil)
                                      "ESSAYS" "ID shared with another entry"
                                      #'org-iw-add-document))))

(ert-deftest org-iw-cmd-test-add-document-refuses-shared-file-level-id ()
  "A document whose file-level :ID: a member heading elsewhere has is refused.
Without Denote: the shared-ID check covers documents, not only Denote
identifiers."
  (org-iw-test-with-corpus
      `(("doc.org" . ,(org-iw-test-org ":PROPERTIES:" ":ID: d1" ":END:"
                                       "#+title: D"))
        ("other.org" . ,(org-iw-test-heading "O" "d1" ":IW_NOTES: 1")))
    (org-iw-cmd-test--should-refuse (org-iw-test-marker "doc.org" nil)
                                    "ESSAYS" "ID shared with another entry"
                                    #'org-iw-add-document)))

(ert-deftest org-iw-cmd-test-add-document-refuses-at-rank-limit ()
  "Add-document refuses when the last rank leaves no room below the limit."
  (org-iw-test-with-corpus
      `(("a.org" . ,org-iw-cmd-test--intro)
        ("b.org" . ,(org-iw-test-heading "Last" "l1"
                                         ":IW_ESSAYS: 9007199254740991")))
    (org-iw-cmd-test--should-refuse (org-iw-test-marker "a.org" nil) "ESSAYS"
                                    (org-iw-cmd-test--no-room "at the end")
                                    #'org-iw-add-document)))

;;;; Batch add: helpers

(defconst org-iw-cmd-test--batch-corpus
  `(("m.org" . ,(org-iw-test-heading "M" "m1" ":IW_ESSAYS: 1024"))
    ("a.org" . ,(org-iw-test-org "#+title: A"))
    ("b.org" . ,(org-iw-test-org "#+title: B"))
    ("sub/c.org" . ,(org-iw-test-org "#+title: C")))
  "A heading M in ESSAYS at 1024, and three documents not yet queued.")

(defconst org-iw-cmd-test--stray-drawer
  (org-iw-test-org "#+title: R" ":PROPERTIES:" ":END:")
  "A document whose drawer follows its title, so Org does not see it.")

(defun org-iw-cmd-test--batch-files (&rest files)
  "Return `org-iw-cmd-test--batch-corpus' with FILES, (NAME . CONTENT).
A file of FILES replaces the corpus file of the same NAME."
  (append files
          (seq-remove (lambda (file) (assoc (car file) files))
                      org-iw-cmd-test--batch-corpus)))

(defun org-iw-cmd-test--relative (outcomes)
  "Return batch OUTCOMES with each file relative to the corpus."
  (mapcar (lambda (outcome)
            (cons (org-iw-test-relative (car outcome))
                  (cdr outcome)))
          outcomes))

(defun org-iw-cmd-test--batch (queue names &optional on-outcome)
  "Return the outcomes of `org-iw--batch-add' of corpus NAMES to QUEUE.
NAMES are files and directories.  The selection, sources and scan are
computed as `org-iw-add-files' computes them.  The outcomes are those
the batch passes to its ON-OUTCOME, in order; ON-OUTCOME, if given,
is called with each too.  Files in the outcomes are relative to the
corpus."
  (let ((sources (org-iw--files))
        (outcomes nil))
    (org-iw--batch-add (org-iw-discovery-scan sources) queue
                       (org-iw-discovery-files
                        (mapcar #'org-iw-test-path names) nil)
                       sources
                       (lambda (outcome)
                         (push outcome outcomes)
                         (when on-outcome
                           (funcall on-outcome outcome))))
    (org-iw-cmd-test--relative (nreverse outcomes))))

(defun org-iw-cmd-test--report-lines ()
  "Return the lines of the shown batch report after its heading and label.
A corpus file at the start of a line is made relative to the corpus.
Fail unless the report is shown."
  (let ((report (get-buffer "*org-iw batch*")))
    (should (get-buffer-window report))
    (mapcar (lambda (line) (string-remove-prefix org-iw-test-dir line))
            (nthcdr 2 (split-string
                       (with-current-buffer report (buffer-string))
                       "\n" t)))))

(defun org-iw-cmd-test--ranks (queue)
  "Return QUEUE's members, scanned afresh, as (FILE . RANK) in order.
FILE is relative to the corpus."
  (mapcar (lambda (entry)
            (cons (org-iw-test-relative (org-iw-entry-file entry))
                  (org-iw-core-rank entry queue)))
          (org-iw--order (org-iw--scan) queue)))

(defun org-iw-cmd-test--visited (name)
  "Return the buffer visiting corpus file NAME, or nil; visit nothing."
  (find-buffer-visiting (org-iw-test-path name)))

(defun org-iw-cmd-test--last-message ()
  "Return the last line logged in *Messages*.
Under --batch `current-message' is always nil, so the log is read."
  (with-current-buffer (messages-buffer)
    (save-excursion
      (goto-char (point-max))
      (skip-chars-backward "\n")
      (buffer-substring-no-properties (line-beginning-position) (point)))))

(defun org-iw-cmd-test--counting (fns body-fn)
  "Call BODY-FN, counting the calls to each of FNS; return the counts.
The result is an alist (FN . COUNT) in the order of FNS.  Each count
is kept by :around advice, added by `advice-add' and removed
afterwards."
  (let* ((counts (mapcar (lambda (fn) (cons fn 0)) fns))
         (advice (mapcar (lambda (count)
                           (lambda (original &rest args)
                             (cl-incf (cdr count))
                             (apply original args)))
                         counts)))
    (cl-mapc (lambda (fn piece) (advice-add fn :around piece)) fns advice)
    (unwind-protect
        (funcall body-fn)
      (cl-mapc #'advice-remove fns advice))
    counts))

(defun org-iw-cmd-test--diverting (symbol test divert fn)
  "Call FN with SYMBOL calling DIVERT when TEST holds; return FN's value.
TEST and DIVERT take SYMBOL's arguments; when TEST is nil, SYMBOL's
own definition is called."
  (let ((original (symbol-function symbol)))
    (cl-letf (((symbol-function symbol)
               (lambda (&rest args)
                 (apply (if (apply test args) divert original) args))))
      (funcall fn))))

(defun org-iw-cmd-test--named-p (name)
  "Return a predicate true of a file ending in /NAME.
The file is the predicate's first argument if that is a string, else
the current buffer's."
  (lambda (&optional file &rest _)
    (string-suffix-p (concat "/" name)
                     (if (stringp file) file (buffer-file-name)))))

(defun org-iw-cmd-test--should-fail (failing substring names)
  "Batch NAMES to ESSAYS; assert FAILING fail with SUBSTRING, alone.
FAILING are corpus names, each in the outcomes as failed with a
reason holding SUBSTRING, and unchanged on disk.  Every other file
must be added and saved, appended 1024 apart after ESSAYS's members,
as if FAILING had not been selected.  Return the outcomes."
  (let* ((disks (mapcar #'org-iw-test-file-string failing))
         (members (org-iw-cmd-test--ranks "ESSAYS"))
         (outcomes (org-iw-cmd-test--batch "ESSAYS" names))
         (added (seq-remove (lambda (name) (member name failing))
                            (mapcar #'car outcomes))))
    (dolist (name failing)
      (pcase-let ((`(,kind ,reason) (cdr (assoc name outcomes))))
        (should (eq kind 'failed))
        (should (string-search substring reason))))
    (dolist (name added)
      (should (equal (cdr (assoc name outcomes)) '(added saved))))
    (should (equal (mapcar #'org-iw-test-file-string failing) disks))
    (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                   (append members
                           (cl-loop for name in added
                                    for rank from (+ (cdar (last members)) 1024)
                                    by 1024
                                    collect (cons name rank)))))
    outcomes))

(ert-deftest org-iw-cmd-test-should-fail-self-test ()
  "The batch-failure oracle fails on each wrong outcome it claims to catch.
That is a wrong reason, a failing file that was added, another file
that failed, and a failing file changed on disk."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let ((org-iw-exclude-regexp "/b\\.org\\'"))
      (org-iw-cmd-test--should-fail '("b.org") "not a source" '("a.org" "b.org"))
      (should-error (org-iw-cmd-test--should-fail
                     '("sub/c.org") "not a source" '("sub"))
                    :type 'ert-test-failed)))
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let ((org-iw-exclude-regexp "/b\\.org\\'"))
      (should-error (org-iw-cmd-test--should-fail
                     '("b.org") "no such reason" '("a.org" "b.org"))
                    :type 'ert-test-failed)))
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let ((org-iw-exclude-regexp "/[ab]\\.org\\'"))
      (should-error (org-iw-cmd-test--should-fail
                     '("b.org") "not a source" '("a.org" "b.org" "sub"))
                    :type 'ert-test-failed)))
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (org-iw-cmd-test--diverting
     'org-iw--add-entry (org-iw-cmd-test--named-p "b.org")
     (lambda (&rest _)
       (write-region "#+title: Changed\n" nil (org-iw-test-path "b.org"))
       (org-iw-core-refuse "boom"))
     (lambda ()
       (should-error (org-iw-cmd-test--should-fail
                      '("b.org") "boom" '("a.org" "b.org"))
                     :type 'ert-test-failed)))))

;;;; Batch add: summary and report (EX-5, VT-2)

(ert-deftest org-iw-cmd-test-batch-summary-counts ()
  "`org-iw--batch-summary' counts each outcome kind and says not atomic.
Unsaved counts the added files left unsaved, save failures included,
and the buffers left open modified, once each.  A batch that stopped
says after how many of its files.  Only a failed, unsaved or stopped
file sends the reader to the report."
  (let ((org-iw-queues '(("essays" :name "Essays"))))
    (should (equal (org-iw--batch-summary
                    "ESSAYS" '(("/a" added saved) ("/b" existing)
                               ("/c" added (save-failed error "x"))
                               ("/d" existing) ("/e" failed "no")
                               ("/f" added saved) ("/g" existing)
                               ("/h" added unsaved)))
                   (concat "Added 4 to Essays, 3 already present, 1 failed,"
                           " 2 unsaved (not atomic; see *org-iw batch*)")))
    (should (equal (org-iw--batch-summary
                    "ESSAYS" '(("/a" added saved) ("/b" existing)))
                   (concat "Added 1 to Essays, 1 already present, 0 failed,"
                           " 0 unsaved (not atomic)")))
    (should (equal (org-iw--batch-summary "ESSAYS" nil)
                   (concat "Added 0 to Essays, 0 already present, 0 failed,"
                           " 0 unsaved (not atomic)")))
    (should (equal (org-iw--batch-summary
                    "ESSAYS" '(("/a" added (save-failed error "x") left-open)
                               ("/b" existing left-open)
                               ("/c" failed "no" left-open)
                               ("/d" added saved)))
                   (concat "Added 2 to Essays, 1 already present, 1 failed,"
                           " 3 unsaved (not atomic; see *org-iw batch*)")))
    (should (equal (org-iw--batch-summary
                    "ESSAYS" '(("/a" added saved) ("/b" stopped)
                               ("/c" stopped)))
                   (concat "Added 1 to Essays, 0 already present, 0 failed,"
                           " 0 unsaved, stopped after 1 of 3 files"
                           " (not atomic; see *org-iw batch*)")))
    (dolist (trouble '(("/e" failed "no") ("/h" added unsaved)
                       ("/c" added (save-failed error "x"))
                       ("/b" existing left-open) ("/s" stopped)))
      (should (string-suffix-p "(not atomic; see *org-iw batch*)"
                               (org-iw--batch-summary "ESSAYS"
                                                      (list trouble)))))))

(ert-deftest org-iw-cmd-test-batch-report-lists-trouble-only ()
  "`org-iw--outcome-report' lists the groups with outcomes, else nothing.
Each outcome reads as in the batch summary, including a buffer left
open.  Empty groups are skipped.  The report is a read-only
`special-mode' buffer, shown, rewritten in full each time."
  (org-iw-test-with-corpus nil
    (let ((org-iw-queues '(("essays" :name "Essays"))))
      (should-not (org-iw--outcome-report
                   "*org-iw batch*" "Batch add to Essays"
                   (list (cons "files needing attention" nil))))
      (should-not (get-buffer "*org-iw batch*"))
      (org-iw--outcome-report
       "*org-iw batch*" "Batch add to Essays"
       '(("files needing attention" ("/n/old.org" failed "stale"))))
      (let ((report (org-iw--outcome-report
                     "*org-iw batch*" "Batch add to Essays"
                     '(("files needing attention"
                        ("/n/c.org" failed "no room")
                        ("/n/d.org" added unsaved)
                        ("/n/e.org" added
                         (save-failed error "Disk full"))
                        ("/n/f.org" existing left-open)
                        ("/n/g.org" failed "stale" left-open)
                        ("/n/h.org" stopped))
                       ("nothing here")
                       ("also" ("/n/i.org" existing))))))
        (should (eq report (get-buffer "*org-iw batch*")))
        (should (get-buffer-window report))
        (with-current-buffer report
          (should (derived-mode-p 'special-mode))
          (should buffer-read-only)
          (should (equal (buffer-string)
                         (org-iw-test-org
                          "Batch add to Essays"
                          ""
                          "files needing attention:"
                          "/n/c.org: no room"
                          (concat "/n/d.org: (buffer has unsaved changes"
                                  " — queue change not saved)")
                          (concat "/n/e.org: (queue change applied but"
                                  " not saved: Disk full)")
                          (concat "/n/f.org: already present; buffer left"
                                  " open, modified")
                          "/n/g.org: stale; buffer left open, modified"
                          "/n/h.org: not added: the batch stopped"
                          ""
                          "also:"
                          "/n/i.org: already present"))))))))

;;;; Batch add: order, rerun and outcomes (EX-2, EX-5, VT-1)

(ert-deftest org-iw-cmd-test-batch-canonical-order ()
  "`org-iw--batch-add' appends in canonical order, whatever the selection.
Selections with a duplicate and a directory, in two orders, give the
same files, in truename order, with the same ranks 1024 apart after
the member, which is unchanged (REQ-012 AC1, I4)."
  (dolist (selection '(("sub/c.org" "b.org" "sub" "a.org" "b.org")
                       ("a.org" "sub" "b.org")))
    (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
      (should (equal (org-iw-cmd-test--batch "ESSAYS" selection)
                     '(("a.org" added saved) ("b.org" added saved)
                       ("sub/c.org" added saved))))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     '(("m.org" . 1024) ("a.org" . 2048) ("b.org" . 3072)
                       ("sub/c.org" . 4096))))
      (should (equal (org-iw-test-file-string "m.org")
                     (cdr (assoc "m.org" org-iw-cmd-test--batch-corpus)))))))

(ert-deftest org-iw-cmd-test-batch-rerun-reports-existing ()
  "A second batch finds every file existing and writes nothing (AC2).
No buffer is left open after either run."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (org-iw-cmd-test--batch "ESSAYS" '("a.org" "sub"))
    (should (equal (org-iw-cmd-test--should-write-nothing
                    (lambda ()
                      (org-iw-cmd-test--batch "ESSAYS" '("sub" "a.org"))))
                   '(("a.org" existing) ("sub/c.org" existing))))
    (should-not (seq-some #'org-iw-cmd-test--visited '("a.org" "sub/c.org")))))

(ert-deftest org-iw-cmd-test-batch-on-outcome-once-per-file ()
  "ON-OUTCOME gets each file's (FILE . OUTCOME) once, after the file is done.
A failed file counts too.  The calls come in canonical order."
  (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                            '("x.org" . "#+title: X\n"))
    (let ((org-iw-exclude-regexp "/x\\.org\\'")
          (members nil))
      (should (equal (mapcar (lambda (outcome) (take 2 outcome))
                             (org-iw-cmd-test--batch
                              "ESSAYS" '("x.org" "b.org" "a.org")
                              (lambda (_)
                                (push (length (org-iw-cmd-test--ranks "ESSAYS"))
                                      members))))
                     '(("a.org" added) ("b.org" added) ("x.org" failed))))
      ;; Each call comes once its file is written.
      (should (equal (reverse members) '(2 3 3))))))

(ert-deftest org-iw-cmd-test-batch-unsaved-add-claims-rank-and-id ()
  "A file added but left unsaved still takes its rank and claims its ID.
The next file is appended after it, and a copy with its ID fails (I4,
RV-012 F-5): an unsaved outcome is an added one."
  (let ((copy (org-iw-test-org ":PROPERTIES:" ":ID: same" ":END:"
                               "#+title: Copy")))
    (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                              `("a.org" . ,copy) `("c.org" . ,copy))
      (with-current-buffer (org-iw-test-visit "a.org")
        (goto-char (point-max))
        (insert "Edit.\n"))
      (should (equal (org-iw-cmd-test--batch "ESSAYS"
                                             '("a.org" "b.org" "c.org"))
                     '(("a.org" added unsaved) ("b.org" added saved)
                       ("c.org" failed
                        "same ID as a file added in this batch"))))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     '(("m.org" . 1024) ("a.org" . 2048) ("b.org" . 3072)))))))

;;;; Batch add: failures (EX-3, I6, VT-1)

(ert-deftest org-iw-cmd-test-batch-fails-non-source ()
  "A file outside the sources and an excluded file fail, naming both causes.
The rest are added as if they had not been selected (RV-012 F-9)."
  (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                            '("out/x.org" . "#+title: X\n")
                            '("skip.org" . "#+title: S\n"))
    (let ((org-iw-sources (mapcar #'org-iw-test-path
                                  '("m.org" "a.org" "b.org" "skip.org")))
          (org-iw-exclude-regexp "/skip\\.org\\'"))
      (should (equal (cdr (assoc "skip.org"
                                 (org-iw-cmd-test--should-fail
                                  '("out/x.org" "skip.org")
                                  "not a source file"
                                  '("skip.org" "out" "b.org" "a.org"))))
                     '(failed "not a source file (outside org-iw-sources\
 or excluded)"))))))

(ert-deftest org-iw-cmd-test-batch-fails-not-org-mode ()
  "A file whose buffer is not in Org mode fails; its buffer is kept."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let ((buffer (org-iw-test-visit "b.org")))
      (with-current-buffer buffer
        (fundamental-mode))
      (org-iw-cmd-test--should-fail '("b.org") "buffer not in Org mode"
                                    '("a.org" "b.org" "sub"))
      (should (eq (org-iw-cmd-test--visited "b.org") buffer)))))

(ert-deftest org-iw-cmd-test-batch-fails-unrecognised-drawer ()
  "A drawer Org does not see fails the file; the buffer opened is killed."
  (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                            `("b.org" . ,org-iw-cmd-test--stray-drawer))
    (org-iw-cmd-test--should-fail '("b.org")
                                  "property drawer Org doesn't recognise"
                                  '("a.org" "b.org" "sub"))
    (should-not (org-iw-cmd-test--visited "b.org"))))

(ert-deftest org-iw-cmd-test-batch-fails-not-writable ()
  "A file that is not writable fails, the reason not naming it again.
The file's writability is stubbed, so the test holds as root too."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (org-iw-cmd-test--diverting
     'file-writable-p (org-iw-cmd-test--named-p "b.org") #'ignore
     (lambda ()
       (should (equal (cdr (assoc "b.org"
                                  (org-iw-cmd-test--should-fail
                                   '("b.org") "not writable"
                                   '("a.org" "b.org" "sub"))))
                      '(failed "not writable")))))))

(ert-deftest org-iw-cmd-test-batch-fails-file-error ()
  "A file error opening a file fails that file; the batch goes on."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (org-iw-cmd-test--diverting
     'org-iw-discovery-buffer (org-iw-cmd-test--named-p "b.org")
     (lambda (file)
       (signal 'file-error (list "Opening input file" "Permission denied"
                                 file)))
     (lambda ()
       (org-iw-cmd-test--should-fail '("b.org")
                                     "Opening input file: Permission denied"
                                     '("a.org" "b.org" "sub"))))))

(ert-deftest org-iw-cmd-test-batch-no-room-fails-rest ()
  "At the rank limit, the first file takes the last rank; the rest fail."
  (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                            `("m.org" . ,(org-iw-test-heading
                                          "M" "m1"
                                          ":IW_ESSAYS: 9007199254739967")))
    (org-iw-cmd-test--should-fail '("b.org" "sub/c.org")
                                  (org-iw-cmd-test--no-room "at the end")
                                  '("a.org" "b.org" "sub"))
    (should (equal (cdr (assoc "a.org" (org-iw-cmd-test--ranks "ESSAYS")))
                   9007199254740991))))

(ert-deftest org-iw-cmd-test-batch-second-copy-same-id-fails ()
  "Of two selected copies with one ID, the second fails (RV-012 F-5).
So the queue keeps one valid member and the scan sees no duplicate."
  (let ((copy (org-iw-test-org ":PROPERTIES:" ":ID: same" ":END:"
                               "#+title: Copy")))
    (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                              `("a.org" . ,copy) `("b.org" . ,copy))
      (org-iw-cmd-test--should-fail '("b.org")
                                    "same ID as a file added in this batch"
                                    '("a.org" "b.org" "sub"))
      (should-not (org-iw-scan-problems (org-iw--scan))))))

(ert-deftest org-iw-cmd-test-batch-second-denote-copy-fails ()
  "Of two selected Denote notes with one identifier, the second fails.
They start with a heading without an ID, so the identity is the
document's, not the heading's (RV-012 F-5)."
  (let ((text (org-iw-test-org "* H")))
    (org-iw-test-with-corpus
        (org-iw-cmd-test--batch-files
         (org-iw-test-denote-file org-iw-test-denote-id text "one")
         (org-iw-test-denote-file org-iw-test-denote-id text "two"))
      (org-iw-cmd-test--should-fail
       (list (org-iw-test-denote-name org-iw-test-denote-id "two"))
       "same ID as a file added in this batch"
       (list (org-iw-test-denote-name org-iw-test-denote-id "one")
             (org-iw-test-denote-name org-iw-test-denote-id "two")
             "a.org")))))

;;;; Batch add: buffers and session (EX-4, DEC-026, I5, VT-1)

(ert-deftest org-iw-cmd-test-batch-buffers-kill-and-keep ()
  "A buffer the batch opened is killed unless left modified; others are kept.
Opened and saved, opened and existing, opened and refused: killed.
Visited before and clean: kept, saved.  Visited before with unsaved
edits: kept, added but unsaved."
  (org-iw-test-with-corpus
      (org-iw-cmd-test--batch-files
       `("e.org" . ,(org-iw-test-org ":PROPERTIES:" ":ID: e1"
                                     ":IW_ESSAYS: 512" ":END:"
                                     "#+title: E"))
       `("r.org" . ,org-iw-cmd-test--stray-drawer)
       '("k.org" . "#+title: K\n")
       '("d.org" . "#+title: D\n"))
    (let ((kept (org-iw-test-visit "k.org"))
          (dirty (org-iw-test-visit "d.org")))
      (with-current-buffer dirty
        (goto-char (point-max))
        (insert "Edit.\n"))
      (let ((outcomes (org-iw-cmd-test--batch
                       "ESSAYS" '("r.org" "k.org" "e.org" "d.org" "a.org"))))
        (should (equal (butlast outcomes)
                       '(("a.org" added saved) ("d.org" added unsaved)
                         ("e.org" existing) ("k.org" added saved))))
        (should (eq (cadr (car (last outcomes))) 'failed)))
      (should-not (seq-some #'org-iw-cmd-test--visited
                            '("a.org" "e.org" "r.org")))
      (should (eq (org-iw-cmd-test--visited "k.org") kept))
      (should-not (buffer-modified-p kept))
      (should (eq (org-iw-cmd-test--visited "d.org") dirty))
      (should (buffer-modified-p dirty)))))

(ert-deftest org-iw-cmd-test-batch-keeps-buffer-visiting-via-symlink ()
  "A buffer visiting a selected file through a symlink is the user's: kept.
The batch finds it by file, not by name (I5)."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let* ((link (org-iw-test-make-symlink (org-iw-test-path "a.org")
                                           "link.org"))
           (buffer (let ((find-file-visit-truename nil))
                     (find-file-noselect link))))
      (should (equal (buffer-file-name buffer) link))
      (should (equal (org-iw-cmd-test--batch "ESSAYS" '("a.org"))
                     '(("a.org" added saved))))
      (should (buffer-live-p buffer)))))

(defun org-iw-cmd-test--dirtying-org-mode-hook ()
  "Edit the buffer, as an Org mode hook might when it sets one up."
  (save-excursion
    (goto-char (point-max))
    (insert " ")))

(ert-deftest org-iw-cmd-test-batch-reports-buffer-left-open ()
  "A buffer the batch opened and left modified is reported, whatever its outcome.
An Org mode hook that edits each buffer it sets up leaves every opened
buffer modified, so the batch keeps it.  The outcome says so, it
counts as unsaved, and the report lists it (DEC-026)."
  (org-iw-test-with-corpus
      (org-iw-cmd-test--batch-files
       `("e.org" . ,(org-iw-test-org ":PROPERTIES:" ":ID: e1"
                                     ":IW_ESSAYS: 512" ":END:"
                                     "#+title: E"))
       `("r.org" . ,org-iw-cmd-test--stray-drawer))
    (let ((org-mode-hook (list #'org-iw-cmd-test--dirtying-org-mode-hook)))
      (should (equal (org-iw-cmd-test--batch "ESSAYS"
                                             '("a.org" "e.org" "r.org"))
                     '(("a.org" added unsaved left-open)
                       ("e.org" existing left-open)
                       ("r.org" failed
                        "entry has a property drawer Org doesn't recognise"
                        left-open))))
      (dolist (name '("a.org" "e.org" "r.org"))
        (should (buffer-modified-p (org-iw-cmd-test--visited name)))
        (kill-buffer (org-iw-cmd-test--visited name)))
      (should (equal (org-iw-add-files "ESSAYS"
                                       (list (org-iw-test-path "e.org")))
                     (concat "Added 0 to ESSAYS, 1 already present,"
                             " 0 failed, 1 unsaved (not atomic; see"
                             " *org-iw batch*)")))
      (should (equal (org-iw-cmd-test--report-lines)
                     '("e.org: already present; buffer left open, modified"))))))

(ert-deftest org-iw-cmd-test-batch-keeps-save-failed-buffer ()
  "A buffer the batch opened whose save failed is kept and reported.
The edit stands in the buffer; the file is unchanged (REQ-021 AC4)."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let ((write-file-functions (list (lambda () (error "Disk full")))))
      (should (equal (org-iw-add-files "ESSAYS"
                                       (list (org-iw-test-path "a.org")))
                     (concat "Added 1 to ESSAYS, 0 already present,"
                             " 0 failed, 1 unsaved (not atomic; see"
                             " *org-iw batch*)")))
      (should (buffer-modified-p (org-iw-cmd-test--visited "a.org")))
      (should (equal (org-iw-test-file-string "a.org")
                     (cdr (assoc "a.org" org-iw-cmd-test--batch-corpus))))
      (should (string-search
               (concat (org-iw-test-path "a.org")
                       ": (queue change applied but not saved: Disk full)")
               (with-current-buffer "*org-iw batch*" (buffer-string)))))))

(ert-deftest org-iw-cmd-test-batch-narrowed-buffer-drawer-at-top ()
  "A narrowed buffer gets its drawer at the file's start; it stays narrowed.
The file starts with a heading, which is byte-identical (RV-012 F-6)."
  (let ((text (org-iw-test-org "* N" "Body.")))
    (org-iw-test-with-corpus (org-iw-cmd-test--batch-files `("n.org" . ,text))
      (with-current-buffer (org-iw-test-visit "n.org")
        (org-iw-cmd-test--narrow-to-line "Body."))
      (should (equal (org-iw-cmd-test--batch "ESSAYS" '("n.org"))
                     '(("n.org" added saved))))
      (with-current-buffer (org-iw-cmd-test--visited "n.org")
        (should (equal (buffer-string) "Body.")))
      (org-iw-test-should-add-drawer text (org-iw-test-marker "n.org" nil)
                                     nil 2048))))

(ert-deftest org-iw-cmd-test-batch-leaves-session ()
  "`org-iw-add-files' leaves the session as it was (EX-4)."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let* ((session (org-iw-cmd-test--session "ESSAYS" "M"))
           (org-iw--session session))
      (org-iw-add-files "ESSAYS" (list (org-iw-test-path "sub")))
      (should (eq org-iw--session session)))))

;;;; Batch add: the command (EX-1, EX-5, EX-6, VT-1, VT-2)

(ert-deftest org-iw-cmd-test-batch-add-files-from-dired ()
  "In Dired, `org-iw-add-files' adds the marked files.
They come from `dired-get-marked-files', and are added in canonical
order; no file name is read."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let ((dired (dired-noselect org-iw-test-dir)))
      (unwind-protect
          (with-current-buffer dired
            (dolist (name '("b.org" "a.org"))
              (dired-goto-file (org-iw-test-path name))
              (dired-mark 1))
            (should (equal (dired-get-marked-files)
                           (mapcar #'org-iw-test-path '("a.org" "b.org"))))
            (cl-letf (((symbol-function 'read-file-name)
                       (lambda (&rest _) (ert-fail "read-file-name"))))
              (org-iw-cmd-test--with-prompt "ESSAYS"
                (call-interactively #'org-iw-add-files))))
        (kill-buffer dired))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     '(("m.org" . 1024) ("a.org" . 2048) ("b.org" . 3072)))))))

(ert-deftest org-iw-cmd-test-batch-add-files-from-prompt ()
  "Outside Dired, `org-iw-add-files' reads one file or directory.
Every Org file under a directory read is added."
  (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                            '("sub/d.org" . "#+title: D\n"))
    (let ((read nil))
      (with-temp-buffer
        (cl-letf (((symbol-function 'read-file-name)
                   (lambda (&rest args)
                     (push args read)
                     (org-iw-test-path "sub"))))
          (org-iw-cmd-test--with-prompt "ESSAYS"
            (call-interactively #'org-iw-add-files))))
      (should (equal (length read) 1))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     '(("m.org" . 1024) ("sub/c.org" . 2048)
                       ("sub/d.org" . 3072)))))))

(defun org-iw-cmd-test--should-refuse-unscanned (substring queue names)
  "Assert adding NAMES to QUEUE refuses with SUBSTRING before any scan.
NAMES are corpus names.  Nothing changes, the sources are not walked,
nothing is scanned and no report is made."
  (should (equal (org-iw-cmd-test--counting
                  '(org-iw-discovery-scan org-iw--files)
                  (lambda ()
                    (org-iw-cmd-test--should-refuse-cleanly
                     substring
                     (lambda ()
                       (org-iw-add-files queue (mapcar #'org-iw-test-path
                                                       names))))))
                 '((org-iw-discovery-scan . 0) (org-iw--files . 0))))
  (should-not (get-buffer "*org-iw batch*")))

(ert-deftest org-iw-cmd-test-batch-empty-selection-refuses ()
  "A selection without an Org file refuses; nothing else happens.
That is no selection, a directory with no Org file, and a missing file."
  (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                            '("notes/x.txt" . "Text.\n"))
    (dolist (names '(() ("notes") ("gone.org")))
      (org-iw-cmd-test--should-refuse-unscanned "no existing file selected"
                                                "ESSAYS" names))))

(ert-deftest org-iw-cmd-test-batch-invalid-queue-refuses ()
  "An invalid queue ID refuses before the selection is used."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (org-iw-cmd-test--should-refuse-unscanned "invalid queue ID"
                                              "not a queue" '("a.org"))))

(ert-deftest org-iw-cmd-test-batch-summary-after-error ()
  "An error other than a refusal or file error stops the batch, as quit does.
The summary says the batch stopped after the files done, the report
lists the files not added, then the error or quit propagates.  The
file being added and the rest are unchanged, and none of their
buffers is left open (RV-012 F-7)."
  (dolist (condition '((error "Boom") (quit)))
    (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
      (should (equal (org-iw-cmd-test--diverting
                      'org-iw--add-entry (org-iw-cmd-test--named-p "b.org")
                      (lambda (&rest _)
                        (signal (car condition) (cdr condition)))
                      (lambda ()
                        (condition-case caught
                            (org-iw-add-files
                             "ESSAYS" (mapcar #'org-iw-test-path
                                              '("a.org" "b.org" "sub")))
                          ((error quit) caught))))
                     condition))
      (should (equal (org-iw-cmd-test--last-message)
                     (concat "Added 1 to ESSAYS, 0 already present, 0 failed,"
                             " 0 unsaved, stopped after 1 of 3 files"
                             " (not atomic; see *org-iw batch*)")))
      (should (equal (org-iw-cmd-test--report-lines)
                     '("b.org: not added: the batch stopped"
                       "sub/c.org: not added: the batch stopped")))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     '(("m.org" . 1024) ("a.org" . 2048))))
      (dolist (name '("b.org" "sub/c.org"))
        (should (equal (org-iw-test-file-string name)
                       (cdr (assoc name org-iw-cmd-test--batch-corpus))))
        (should-not (org-iw-cmd-test--visited name))))))

(ert-deftest org-iw-cmd-test-batch-add-files-reports-trouble ()
  "The summary is the last message and the return value.
With failures it points at the report, which is shown and lists them
in canonical order; a clean run makes no report."
  (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                            `("b.org" . ,org-iw-cmd-test--stray-drawer)
                            `("sub/c.org" . ,org-iw-cmd-test--stray-drawer))
    (let ((clean (org-iw-add-files "ESSAYS"
                                   (list (org-iw-test-path "a.org")))))
      (should (equal clean (concat "Added 1 to ESSAYS, 0 already"
                                   " present, 0 failed, 0 unsaved"
                                   " (not atomic)")))
      (should (equal (org-iw-cmd-test--last-message) clean)))
    (should-not (get-buffer "*org-iw batch*"))
    (should (equal (org-iw-add-files "ESSAYS"
                                     (mapcar #'org-iw-test-path
                                             '("sub" "a.org" "b.org")))
                   (concat "Added 0 to ESSAYS, 1 already present,"
                           " 2 failed, 0 unsaved (not atomic; see"
                           " *org-iw batch*)")))
    (let ((report (get-buffer "*org-iw batch*")))
      (should (get-buffer-window report))
      (should (equal (mapcar (lambda (line)
                               (car (split-string line ": ")))
                             (nthcdr 2 (split-string
                                        (with-current-buffer report
                                          (buffer-string))
                                        "\n" t)))
                     (mapcar #'org-iw-test-path
                             '("b.org" "sub/c.org")))))))

(ert-deftest org-iw-cmd-test-batch-add-files-excluded-fails ()
  "An excluded file in the selection is kept, to fail, not dropped (F-9)."
  (org-iw-test-with-corpus org-iw-cmd-test--batch-corpus
    (let ((org-iw-exclude-regexp "/b\\.org\\'"))
      (should (equal (org-iw-add-files "ESSAYS"
                                       (mapcar #'org-iw-test-path
                                               '("a.org" "b.org")))
                     (concat "Added 1 to ESSAYS, 0 already present,"
                             " 1 failed, 0 unsaved (not atomic; see"
                             " *org-iw batch*)"))))))

(ert-deftest org-iw-cmd-test-batch-summary-counts-source-problems ()
  "The summary notes the scan's problems, as every command's message does."
  (org-iw-test-with-corpus (org-iw-cmd-test--batch-files
                            `("bad.org" . ,(org-iw-test-heading
                                            "No ID" nil ":IW_ESSAYS: 1")))
    (should (equal (org-iw-add-files "ESSAYS" (list (org-iw-test-path "a.org")))
                   (concat "Added 1 to ESSAYS, 0 already present, 0 failed,"
                           " 0 unsaved (not atomic) [1 source problems"
                           " ignored]")))))

;;;; Batch add: cost and identity (EX-7, VT-3)

(ert-deftest org-iw-cmd-test-batch-scans-once ()
  "`org-iw-add-files' scans once and walks the sources once, for any count.
Counted by `advice-add' around `org-iw-discovery-scan' and
`org-iw--files'; no file is checked by `org-iw--source-file-p', which
walks the sources (RV-012 F-8, F-14)."
  (dolist (count '(3 6))
    (org-iw-test-with-corpus
        (cons (assoc "m.org" org-iw-cmd-test--batch-corpus)
              (cl-loop for n from 1 to count
                       collect (cons (format "f/%d.org" n) "#+title: F\n")))
      (should (equal (org-iw-cmd-test--counting
                      '(org-iw-discovery-scan org-iw--files
                                              org-iw--source-file-p)
                      (lambda ()
                        (should (string-prefix-p
                                 (format "Added %d to ESSAYS" count)
                                 (org-iw-add-files
                                  "ESSAYS" (list (org-iw-test-path "f")))))))
                     '((org-iw-discovery-scan . 1) (org-iw--files . 1)
                       (org-iw--source-file-p . 0)))))))

(ert-deftest org-iw-cmd-test-batch-denote-notes-gain-no-id ()
  "Denote notes added by a batch gain a drawer and a rank, never an ID (I2).
A note with a title and one starting with a heading that has an :ID:;
the heading is byte-identical.  Their IDs are their Denote identifiers."
  (let* ((titled (org-iw-test-org "#+title: T" "Text."))
         (headed (org-iw-test-heading "H" "h1"))
         (one (org-iw-test-denote-file org-iw-test-denote-id titled "one"))
         (two (org-iw-test-denote-file "20260513T000000" headed "two")))
    (org-iw-test-with-corpus (list one two)
      (should (equal (mapcar #'cdr (org-iw-cmd-test--batch
                                    "ESSAYS" (list (car two) (car one))))
                     '((added saved) (added saved))))
      (pcase-dolist (`(,file ,text ,rank) `((,(car one) ,titled "1024")
                                            (,(car two) ,headed "2048")))
        (should (equal (org-iw-test-changed-lines
                        text (org-iw-test-file-string file))
                       `(nil ":PROPERTIES:" ,(concat ":IW_ESSAYS: " rank)
                             ":END:"))))
      (should (equal (org-iw-cmd-test--order "ESSAYS")
                     (list org-iw-test-denote-id "20260513T000000"))))))

;;;; Target at point

(defun org-iw-cmd-test--narrow-to-line (text)
  "Narrow the current buffer to the line holding TEXT, point on it."
  (goto-char (point-min))
  (search-forward text)
  (narrow-to-region (line-beginning-position) (line-end-position)))

(ert-deftest org-iw-cmd-test-require-source-refuses ()
  "The source precondition: a source file's buffer, in Org mode.
Tested apart because Add and Add-document share it and the batch
bypasses it.  A plain or indirect source buffer passes."
  (org-iw-test-with-corpus `(("a.org" . "* A\n") ("b.org" . "* B\n"))
    (let ((org-iw-sources (list (org-iw-test-path "a.org"))))
      (with-current-buffer (org-iw-test-visit "b.org")
        (org-iw-cmd-test--should-refuse-cleanly
         "not a source file" #'org-iw--require-source))
      (with-temp-buffer
        (org-mode)
        (org-iw-cmd-test--should-refuse-cleanly
         "not a source file" #'org-iw--require-source))
      (with-current-buffer (org-iw-test-visit "a.org")
        (org-iw--require-source)
        (fundamental-mode)
        (org-iw-cmd-test--should-refuse-cleanly
         "buffer not in Org mode" #'org-iw--require-source)
        (org-mode))
      (org-iw-test-call-with-indirect
       (org-iw-test-marker "a.org" "A")
       (lambda (_) (org-iw--require-source))))))

(ert-deftest org-iw-cmd-test-target-at-point-document ()
  "Before the first heading the target is the document, at the wide start.
Narrowing to the second line of the preamble does not move it."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-org "#+title: T" "Intro." "* H")))
    (with-current-buffer (org-iw-test-visit "a.org")
      (org-iw-cmd-test--narrow-to-line "Intro.")
      (pcase-let ((`(,target . ,document) (org-iw--target-at-point)))
        (should document)
        (should (eq (marker-buffer target) (current-buffer)))
        (should (= target 1))))))

(ert-deftest org-iw-cmd-test-target-at-point-heading ()
  "In a heading's body the target is the heading, not the document.
It is at the heading's start, even narrowed.  The write layer reads the entry's drawer from there."
  (org-iw-test-with-corpus
      `(("a.org" . ,(org-iw-test-org "Intro." "* A" "** B" "Body of B.")))
    (with-current-buffer (org-iw-test-visit "a.org")
      (org-iw-cmd-test--narrow-to-line "Body of B.")
      (pcase-let ((`(,target . ,document) (org-iw--target-at-point)))
        (should-not document)
        (should (eq (marker-buffer target) (current-buffer)))
        (should (equal (org-with-point-at target
                         (buffer-substring-no-properties
                          (point) (line-end-position)))
                       "** B"))))))

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

(ert-deftest org-iw-cmd-test-add-heading-below-preamble ()
  "Add at a heading of a file with text before its first heading.
The heading is enrolled, not the document: the file has a document
slot, but the target is not in it."
  (let ((text (org-iw-test-org "#+title: Note" "Intro." "* New" "Body.")))
    (org-iw-test-with-corpus `(("a.org" . ,text))
      (let ((marker (org-iw-test-marker "a.org" "New")))
        (should (equal (org-iw-cmd-test--call-at marker #'org-iw-add "ESSAYS")
                       "Added to ESSAYS at 1/1 (saved)"))
        (org-iw-test-should-add-drawer text marker "* New")))))

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
                                      "ID shared with another entry")
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
                                    "ID shared with another entry")))

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
  (org-iw--find-entry (org-iw-scan-entries scan) id))

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
                (org-iw-test-relative buffer-file-name)
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

(defun org-iw-cmd-test--call-prefixed (marker command)
  "Call COMMAND interactively with a prefix argument at MARKER.
A nil MARKER calls it where point is."
  (let ((current-prefix-arg '(4)))
    (if marker
        (org-iw-cmd-test--call-at marker #'call-interactively command)
      (call-interactively command))))

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
        (should (equal (org-iw-cmd-test--call-prefixed
                        (org-iw-test-marker "a.org" "Target") #'org-iw-add)
                       "Added to ESSAYS at Later, 5/9 (saved)"))
        (pcase-let ((`(,queue ,placement) org-iw-cmd-test--prompts))
          (should (equal (plist-get queue :prompt) "Queue: "))
          (should (equal (plist-get placement :prompt) "Placement in ESSAYS: "))
          (should (equal (plist-get placement :order) '("Soon" "Later" "End")))
          (should (equal (plist-get placement :default) "Soon")))))))

(ert-deftest org-iw-cmd-test-add-document-at-placement ()
  "With a prefix argument Add-document reads a placement as Add does.
From a heading, the document joins at the placement read after the
queue, which defaults to the queue's default."
  (org-iw-test-with-corpus org-iw-cmd-test--target-and-eight
    (let ((org-iw-queues '(("essays" :default "Soon"))))
      (org-iw-cmd-test--with-prompt '("essays" "Later")
        (should (equal (org-iw-cmd-test--call-prefixed
                        (org-iw-test-marker "a.org" "Target")
                        #'org-iw-add-document)
                       "Added to ESSAYS at Later, 5/9 (saved)"))
        (should (equal (plist-get (cadr org-iw-cmd-test--prompts) :default)
                       "Soon")))
      (should (equal (org-iw-entry-title
                      (nth 4 (org-iw--order (org-iw--scan) "ESSAYS")))
                     "a")))))

(ert-deftest org-iw-cmd-test-add-chooser-refuses-before-prompting ()
  "Bad config refuses after the queue prompt, before the placement prompt."
  (org-iw-test-with-corpus org-iw-cmd-test--target-and-eight
    (org-iw-cmd-test--open-all)
    (let ((org-iw-queues '(("essays" :placements nil))))
      (org-iw-cmd-test--with-prompt '("essays")
        (should (equal (cadr (org-iw-cmd-test--should-write-nothing
                              (lambda ()
                                (should-error
                                 (org-iw-cmd-test--call-prefixed
                                  (org-iw-test-marker "a.org" "Target")
                                  #'org-iw-add)
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
                               (org-iw-cmd-test--call-prefixed
                                (org-iw-test-marker "a.org" "Target")
                                #'org-iw-add)
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
            (cons (org-iw-test-relative file)
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

(defun org-iw-cmd-test--line-deleter (name line)
  "Return a function deleting LINE from corpus file NAME and saving it."
  (lambda ()
    (with-current-buffer (org-iw-test-visit name)
      (goto-char (point-min))
      (search-forward (concat line "\n"))
      (replace-match "")
      (save-buffer))))

(ert-deftest org-iw-cmd-test-should-delete-self-test ()
  "The delete oracle fails unless LINE alone, of FILE alone, goes.
No change, another line, another file, and LINE with another file's
line too, each fail."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (dolist (fn (list #'ignore
                      (org-iw-cmd-test--line-deleter "b.org" ":IW_ESSAYS: 2048")
                      (org-iw-cmd-test--line-deleter "a.org" ":ID: a1")))
      (should-error (org-iw-cmd-test--should-delete
                     fn "a.org" ":IW_ESSAYS: 1024")
                    :type 'ert-test-failed))
    (org-iw-cmd-test--should-delete
     (org-iw-cmd-test--line-deleter "a.org" ":IW_ESSAYS: 1024")
     "a.org" ":IW_ESSAYS: 1024"))
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (should-error (org-iw-cmd-test--should-delete
                   (lambda ()
                     (funcall (org-iw-cmd-test--line-deleter
                               "a.org" ":IW_ESSAYS: 1024"))
                     (funcall (org-iw-cmd-test--line-deleter
                               "d.org" ":IW_DRAFTS: 1")))
                   "a.org" ":IW_ESSAYS: 1024")
                  :type 'ert-test-failed)))

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
                     (concat "no room at Second in Essays; normalise it"
                             " with org-iw-normalise")))
      (should (equal (org-iw-cmd-test--should-refuse-cleanly
                      "no room"
                      (lambda ()
                        (org-iw-cmd-test--move scan "a1" '(after 1))))
                     (concat "no room at position 2/3 in Essays;"
                             " normalise it with org-iw-normalise"))))))

(ert-deftest org-iw-cmd-test-moved-text ()
  "The move text gives the placement when WHERE is given, else only D/N."
  (pcase-dolist (`(,result ,where ,text)
                 '(((moved 1 saved) "Soon" "Moved T to Soon, 2/3 (saved)")
                   ((unchanged 2) "Soon" "T already at Soon, 3/3")
                   ((moved 1 saved) nil "Moved T to 2/3 (saved)")
                   ((unchanged 2) nil "T already at 3/3")))
    (should (equal (org-iw--moved-text result "T" where 3) text))))

;;;; Continue: placements

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
        (should (equal (org-iw-cmd-test--call-prefixed nil #'org-iw-continue)
                       "Moved E1 to Later, 4/8 (saved). Now 1/8: E2"))
        (pcase-let ((`(,call) org-iw-cmd-test--prompts))
          (should (equal (plist-get call :prompt) "Placement in ESSAYS: "))
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
       "no session"
       (lambda () (org-iw-cmd-test--call-prefixed nil #'org-iw-continue)))
      (org-iw-visit-next "ESSAYS")
      (let ((org-iw-queues '(("essays" :placements nil))))
        (org-iw-cmd-test--should-refuse-cleanly
         "queue ESSAYS :placements: no placements"
         (lambda () (org-iw-cmd-test--call-prefixed nil #'org-iw-continue)))))))

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
                      (org-iw-test-marker "a.org" title))
                     "entry at point is not in any queue")))))

(ert-deftest org-iw-cmd-test-scanned-entry-at-document ()
  "A document with an ID and an IW line is found; without an ID it is in no queue."
  (org-iw-test-with-corpus `(("a.org" . ,org-iw-cmd-test--document)
                             ("b.org" . ,org-iw-cmd-test--intro))
    (should (equal (org-iw-entry-id
                    (org-iw-cmd-test--scanned-at
                     (org-iw-test-marker "a.org" nil)))
                   "doc1"))
    (should (equal (org-iw-cmd-test--scanned-refusal
                    (org-iw-test-marker "b.org" nil))
                   "entry at point is not in any queue"))))

(ert-deftest org-iw-cmd-test-scanned-entry-at-denote-document ()
  "A member document identified by its Denote name is found at its start."
  (let ((note (org-iw-test-denote-file
               org-iw-test-denote-id
               (org-iw-test-org ":PROPERTIES:" ":IW_ESSAYS: 1024" ":END:"
                                "Intro."))))
    (org-iw-test-with-corpus (list note)
      (should (equal (org-iw-entry-id
                      (org-iw-cmd-test--scanned-at
                       (org-iw-test-marker (car note) nil)))
                     org-iw-test-denote-id)))))

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
      (let ((marker (org-iw-test-marker "a.org" title)))
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
       "not a source file"
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
          (should (equal (plist-get call :prompt) "Placement in ESSAYS: "))
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
                     '("Queue: " "Placement in DRAFTS: ")))
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
                       '("Placement in ESSAYS: ")))))))

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
         (org-iw-cmd-test--call-at (org-iw-test-marker "a.org" nil)
                                   #'call-interactively #'org-iw-move))))))

;; DEC-020: a prefix argument reads the queue.

(defun org-iw-cmd-test--should-read-queue-prefixed (command &optional label)
  "Call COMMAND with a prefix argument; assert it reads the queue first.
The session is in ESSAYS.  For A, in ESSAYS alone, and M, in ESSAYS
and DRAFTS, a must-match \"Queue: \" prompt offers exactly the entry's
queues; it is answered ESSAYS for A and DRAFTS, not the session's, for
M.  A non-nil LABEL answers a placement prompt that must follow,
naming the queue.  Return the results, for A then M."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (let ((org-iw--session (org-iw-cmd-test--session "ESSAYS" "S")))
      (mapcar
       (pcase-lambda (`(,name ,title ,queues ,queue))
         (org-iw-cmd-test--with-prompt (cons queue (ensure-list label))
           (prog1 (org-iw-cmd-test--call-prefixed
                   (org-iw-test-marker name title) command)
             (should (equal (org-iw-cmd-test--prompted :prompt)
                            (cons "Queue: "
                                  (and label (list (format "Placement in %s: "
                                                           queue))))))
             (let ((call (car org-iw-cmd-test--prompts)))
               (should (equal (plist-get call :order) queues))
               (should (eq (plist-get call :require-match) t))))))
       '(("a.org" "A" ("ESSAYS") "ESSAYS")
         ("m.org" "M" ("DRAFTS" "ESSAYS") "DRAFTS"))))))

(ert-deftest org-iw-cmd-test-move-chosen-prefix-reads-queue ()
  "With a prefix argument Move reads the queue, then a placement.
It does so for one membership and with the session in one of them."
  (should (equal (mapcar (lambda (result)
                           (and (string-match " in \\([A-Z]+\\)" result)
                                (match-string 1 result)))
                         (org-iw-cmd-test--should-read-queue-prefixed
                          #'org-iw-move "Soon"))
                 '("ESSAYS" "DRAFTS"))))

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
      (should (equal (org-iw-cmd-test--call-prefixed nil #'org-iw-continue)
                     "Removed A from ESSAYS (saved). Now 1/2: B"))
      (pcase-let ((`(,call) org-iw-cmd-test--prompts))
        (should (equal (plist-get call :prompt) "Placement in ESSAYS: "))
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

(ert-deftest org-iw-cmd-test-remove-denote-document ()
  "A Denote document leaving its last queue is as it was before joining.
Its drawer, holding only the rank, goes with it, whether by Remove or
by Continue with Remove; the heading stays."
  (let* ((before (org-iw-test-org "#+title: Tuesday" "Intro." "* H"))
         (drawer '(":PROPERTIES:" ":IW_ESSAYS: 1024" ":END:"))
         (note (org-iw-test-denote-file
                org-iw-test-denote-id (concat (apply #'org-iw-test-org drawer)
                                              before)
                "tuesday"))
         (name (car note)))
    (pcase-dolist (`(,fn ,message)
                   `((,(lambda ()
                         (org-iw-cmd-test--call-at
                          (org-iw-test-marker name nil)
                          #'org-iw-remove "ESSAYS"))
                      "Removed Tuesday from ESSAYS (saved)")
                     (,(lambda ()
                         (org-iw-visit-next "ESSAYS")
                         (org-iw-continue 'remove))
                      ,(concat "Removed Tuesday from ESSAYS (saved). Queue"
                               " ESSAYS is empty. " org-iw-cmd-test--hint))))
      (org-iw-test-with-corpus (list note)
        (should (equal (org-iw-cmd-test--should-change-lines
                        fn name drawer nil)
                       message))
        (should (equal (org-iw-test-file-string name) before))))))

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

(ert-deftest org-iw-cmd-test-remove-chosen-prefix-reads-queue ()
  "With a prefix argument Remove reads the queue among the entry's.
It does so for one membership and with the session in one of them."
  (should (equal (org-iw-cmd-test--should-read-queue-prefixed #'org-iw-remove)
                 '("Removed A from ESSAYS (saved)"
                   "Removed M from DRAFTS (saved)"))))

(ert-deftest org-iw-cmd-test-remove-chosen-refuses-before-prompting ()
  "Interactively, an entry in no queue refuses unprompted."
  (org-iw-test-with-corpus org-iw-cmd-test--multi
    (org-iw-cmd-test--open-all)
    (org-iw-cmd-test--with-prompt nil
      (org-iw-cmd-test--should-refuse-cleanly
       "entry at point is not in any queue"
       (lambda ()
         (org-iw-cmd-test--call-at (org-iw-test-marker "a.org" nil)
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
      (should (equal (buffer-local-value 'tabulated-list-padding view) 2))
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

(ert-deftest org-iw-cmd-test-view-remove-last-goes-to-previous-row ()
  "D on the last row shown puts point on the previous row shown.
The rows show A B C; in truth A has moved last.  Removing C, point
goes to B, not to the last row of the new order."
  (org-iw-test-with-corpus org-iw-cmd-test--queue
    (let ((view (org-iw-cmd-test--view "ESSAYS")))
      (org-iw-cmd-test--set-rank "a.org" 1024 4096)
      (org-iw-cmd-test--goto-row "c1")
      (org-iw-cmd-test--with-prompt :yes
        (org-iw-view-remove))
      (should (equal (org-iw-cmd-test--view-ids view) '("b1" "a1")))
      (should (equal (tabulated-list-get-id) "b1")))))

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

;;;; Redistribution: helpers

(defconst org-iw-cmd-test--uneven
  `(("a.org" . ,(concat (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 1536")
                        (org-iw-test-heading "C" "c1" ":IW_ESSAYS: 1537")))
    ("b.org" . ,(org-iw-test-heading "D" "d1" ":IW_ESSAYS: 4096"))
    ("c.org" . ,(org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1024"))
    ("x.org" . ,(org-iw-test-heading "X" "x1" ":IW_ESSAYS: soon")))
  "ESSAYS as A 1024, B 1536, C 1537, D 4096, and X excluded.
B and C are in a.org, D in b.org, A in c.org.  X's rank is invalid,
so the scan leaves it out and counts one problem.")

(defun org-iw-cmd-test--keep-order (scan)
  "Return ESSAYS's members in SCAN, in order: normalise's intent."
  (org-iw--order scan "ESSAYS"))

(defun org-iw-cmd-test--move-to (id depth)
  "Return an intent moving the member ID of ESSAYS to DEPTH."
  (lambda (scan)
    (let ((order (org-iw--order scan "ESSAYS")))
      (org-iw-core-reorder order (org-iw--find-entry order id) depth))))

(defun org-iw-cmd-test--with-ranks-replaced (text &rest replacements)
  "Return TEXT with each IW_ESSAYS rank FROM made TO.
REPLACEMENTS are FROM TO pairs, integers."
  (cl-loop for (from to) on replacements by #'cddr
           do (setq text (string-replace (format ":IW_ESSAYS: %d" from)
                                         (format ":IW_ESSAYS: %d" to)
                                         text)))
  text)

;;;; Redistribution: the record

(ert-deftest org-iw-cmd-test-redistribution-build ()
  "The record holds the plan, the affected files and the recheck key.
Files come once each, in `string<' order, with their change count and
problems; an excluded membership is absent and counted as a problem.
Nothing is visited."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (let* ((a (org-iw-test-path "a.org"))
           (b (org-iw-test-path "b.org"))
           (c (org-iw-test-path "c.org"))
           (before (org-iw-test-state))
           (record (org-iw--redistribution-build
                    (org-iw--scan) "ESSAYS" (org-iw-cmd-test--move-to "d1" 2)
                    "move D at Soon")))
      (should (equal (org-iw-test-state) before))
      (should (equal (org-iw--redistribution-queue record) "ESSAYS"))
      (should (equal (org-iw--redistribution-pending record) "move D at Soon"))
      (should (equal (mapcar (pcase-lambda (`(,entry . ,rank))
                               (cons (org-iw-entry-id entry) rank))
                             (org-iw--redistribution-changes record))
                     '(("b1" . 2048) ("d1" . 3072) ("c1" . 4096))))
      (should (equal (org-iw--redistribution-files record)
                     `((,a 2) (,b 1))))
      (should (equal (org-iw--redistribution-problems record) 1))
      (should (equal (org-iw--redistribution-key record)
                     `((("a1" ,c 1024) ("b1" ,a 1536) ("c1" ,a 1537)
                        ("d1" ,b 4096))
                       . ((,a 2) (,b 1)))))
      (org-iw-test-edit-elsewhere (org-iw-test-marker "a.org" nil))
      (let ((record (org-iw--redistribution-build
                     (org-iw--scan) "ESSAYS" #'org-iw-cmd-test--keep-order
                     nil)))
        (should-not (org-iw--redistribution-pending record))
        (should (equal (org-iw--redistribution-files record)
                       `((,a 2 modified))))))))

;;;; Redistribution: the preview

(defun org-iw-cmd-test--preview-buttons ()
  "Return the labels of the buttons in the preview buffer, in order."
  (with-current-buffer org-iw--redistribution-buffer-name
    (let ((button (next-button (point-min) t))
          (labels nil))
      (while button
        (push (button-label button) labels)
        (setq button (next-button (button-end button))))
      (nreverse labels))))

(ert-deftest org-iw-cmd-test-preview-content ()
  "The preview shows the plan, the blockers and the buffers approval saves.
It names the queue and the pending operation, counts the entries and
files, warns that the run is not atomic, counts the source problems
and lists each file as a button that visits it.  Showing it visits
nothing."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (org-iw-test-edit-elsewhere (org-iw-test-marker "a.org" nil))
    (with-current-buffer (org-iw-test-visit "b.org")
      (setq buffer-read-only t))
    (let* ((a (org-iw-test-path "a.org"))
           (b (org-iw-test-path "b.org"))
           (before (org-iw-test-state))
           (buffer (org-iw--redistribution-show
                    (org-iw--redistribution-build
                     (org-iw--scan) "ESSAYS" (org-iw-cmd-test--move-to "d1" 2)
                     "move D at Soon"))))
      (should (equal (org-iw-test-state) before))
      (should (eq buffer (get-buffer org-iw--redistribution-buffer-name)))
      (should (get-buffer-window buffer))
      (with-current-buffer buffer
        (should (derived-mode-p 'special-mode))
        (should (equal (buffer-string)
                       (org-iw-test-org
                        "Redistribution of ESSAYS"
                        "Pending: move D at Soon"
                        "3 entries in 2 files"
                        (concat "Not atomic: files are written one by one."
                                " Commit to Git first.")
                        "1 source problems ignored (never rewritten)"
                        ""
                        "Blocking:"
                        (concat b ": buffer is read-only")
                        ""
                        "Saved on approval:"
                        "a.org"
                        ""
                        "Files:"
                        (concat a ": 2 entries")
                        (concat b ": 1 entries")))))
      (should (equal (org-iw-cmd-test--preview-buttons) (list a b))))))

(ert-deftest org-iw-cmd-test-preview-content-plain ()
  "The preview leaves out what is absent; a file's button visits it.
Absent are the pending operation, blockers, buffers to save and
problems."
  (org-iw-test-with-corpus (butlast org-iw-cmd-test--uneven)
    (let ((a (org-iw-test-path "a.org")))
      (with-current-buffer (org-iw--redistribution-show
                            (org-iw--redistribution-build
                             (org-iw--scan) "ESSAYS"
                             #'org-iw-cmd-test--keep-order nil))
        (should (equal (buffer-string)
                       (org-iw-test-org
                        "Redistribution of ESSAYS"
                        "2 entries in 1 files"
                        (concat "Not atomic: files are written one by one."
                                " Commit to Git first.")
                        ""
                        "Files:"
                        (concat a ": 2 entries"))))
        (should-not (org-iw-cmd-test--visited "a.org"))
        (push-button (next-button (point-min) t))
        (should (org-iw-cmd-test--visited "a.org"))))))

;;;; Redistribution: cancel, blockers and the recheck

(defun org-iw-cmd-test--normalise-essays ()
  "Redistribute ESSAYS in its own order, with no pending operation."
  (org-iw--redistribute "ESSAYS" #'org-iw-cmd-test--keep-order nil))

(defun org-iw-cmd-test--preview-text ()
  "Return the text of the preview buffer."
  (with-current-buffer org-iw--redistribution-buffer-name
    (buffer-string)))

(defconst org-iw-cmd-test--block-text
  (concat "1 files block redistributing ESSAYS (see *org-iw redistribution*);"
          " resolve them and repeat")
  "The refusal when one file blocks redistributing ESSAYS.")

(ert-deftest org-iw-cmd-test-redistribute-cancel-changes-nothing ()
  "Answering no refuses as cancelled, changing nothing; the preview stays."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (let ((before (org-iw-test-state)))
      (org-iw-cmd-test--with-prompt :no
        (should (equal (org-iw-cmd-test--refusal
                        (lambda ()
                          (org-iw--redistribute
                           "ESSAYS" (org-iw-cmd-test--move-to "d1" 2)
                           "move D at Soon")))
                       "Redistribution of ESSAYS cancelled; nothing changed"))
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       '("Redistribute 3 entries in 2 files of ESSAYS? "))))
      (should (equal (org-iw-test-state) before))
      (should (string-search "Pending: move D at Soon"
                             (org-iw-cmd-test--preview-text))))))

(defun org-iw-cmd-test--should-block (setup text)
  "Assert a.org blocks redistributing ESSAYS for TEXT once SETUP has run.
SETUP is called with no arguments in the corpus.  The preview lists
the file with TEXT, nothing prompts, and nothing changes."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (funcall setup)
    (let ((before (org-iw-test-state)))
      (org-iw-cmd-test--with-prompt nil
        (should (equal (org-iw-cmd-test--refusal
                        #'org-iw-cmd-test--normalise-essays)
                       org-iw-cmd-test--block-text)))
      (should (equal (org-iw-test-state) before))
      (should (string-search (format "Blocking:\n%s: %s\n"
                                     (org-iw-test-path "a.org") text)
                             (org-iw-cmd-test--preview-text))))))

(ert-deftest org-iw-cmd-test-redistribute-blocked-read-only ()
  "A read-only affected buffer blocks the run before the prompt."
  (org-iw-cmd-test--should-block
   (lambda ()
     (with-current-buffer (org-iw-test-visit "a.org")
       (setq buffer-read-only t)))
   "buffer is read-only"))

(ert-deftest org-iw-cmd-test-redistribute-blocked-not-writable ()
  "An unwritable affected file blocks the run before the prompt."
  (org-iw-test-unless-root
    (org-iw-cmd-test--should-block
     (lambda () (org-iw-test-set-modes "a.org" #o444))
     "not writable")))

(ert-deftest org-iw-cmd-test-redistribute-blocked-changed-on-disk ()
  "An affected buffer whose file changed on disk blocks the run."
  (org-iw-cmd-test--should-block
   (lambda ()
     (org-iw-test-visit "a.org")
     (org-iw-test-rewrite-behind "a.org" (org-iw-test-file-string "a.org")))
   "changed on disk; revert first"))

(ert-deftest org-iw-cmd-test-redistribute-blocked-not-org ()
  "An affected buffer not in Org mode blocks the run before the prompt."
  (org-iw-cmd-test--should-block
   (lambda () (find-file-literally (org-iw-test-path "a.org")))
   "buffer not in Org mode"))

(defun org-iw-cmd-test--edit-d-rank (rank)
  "Return a prompt answer that gives D, in b.org, RANK, then answers yes.
The rank is edited in b.org's buffer if one visits it, else on disk."
  (lambda ()
    (let ((text (org-iw-test-heading "D" "d1" (format ":IW_ESSAYS: %d" rank))))
      (if-let* ((buffer (org-iw-cmd-test--visited "b.org")))
          (with-current-buffer buffer
            (erase-buffer)
            (insert text))
        (org-iw-test-rewrite-behind "b.org" text)))
    :yes))

(defconst org-iw-cmd-test--d-first
  '(("b.org" . 1024) ("c.org" . 2048) ("a.org" . 3072) ("a.org" . 4096))
  "ESSAYS's ranks once D, moved to the front, is normalised.")

(ert-deftest org-iw-cmd-test-redistribute-stale-reshows ()
  "A member changed while asking re-shows the plan and asks again.
The second yes applies the fresh plan: D, moved to the front while the
prompt was up, stays there.  On disk or in a live buffer alike; a
buffer so edited is named for saving in the second prompt."
  (dolist (visit '(nil t))
    (org-iw-test-with-corpus org-iw-cmd-test--uneven
      (when visit
        (org-iw-test-visit "b.org"))
      (org-iw-cmd-test--with-prompt
          (list (org-iw-cmd-test--edit-d-rank 1000) :yes)
        (should (org-iw-cmd-test--normalise-essays))
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       (list "Redistribute 2 entries in 1 files of ESSAYS? "
                             (concat "Redistribute 4 entries in 3 files of"
                                     " ESSAYS"
                                     (and visit ", saving b.org first")
                                     "? ")))))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     org-iw-cmd-test--d-first))
      (should-not (buffer-modified-p (org-iw-cmd-test--visited "b.org"))))))

(ert-deftest org-iw-cmd-test-redistribute-blocked-changed-while-asking ()
  "A visited affected file changed on disk while asking blocks the rerun.
The preview is shown again with the blocker, with no second prompt.
Only that file changed: the buffer the first prompt named for saving
is not saved, since the recheck comes first."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (org-iw-test-visit "a.org")
    (org-iw-test-edit-elsewhere (org-iw-test-marker "b.org" nil))
    (let ((before (org-iw-test-state)))
      (org-iw-cmd-test--with-prompt
          (lambda ()
            (org-iw-test-rewrite-behind
             "a.org" (concat (org-iw-test-file-string "a.org") "Edited.\n"))
            :yes)
        (should (equal (org-iw-cmd-test--refusal
                        (lambda ()
                          (org-iw--redistribute
                           "ESSAYS" (org-iw-cmd-test--move-to "d1" 2) nil)))
                       org-iw-cmd-test--block-text))
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       (list (concat "Redistribute 3 entries in 2 files of"
                                     " ESSAYS, saving b.org first? ")))))
      (should (equal (org-iw-test-changed-files before (org-iw-test-state))
                     (list (org-iw-test-path "a.org"))))
      (should (string-search "changed on disk; revert first"
                             (org-iw-cmd-test--preview-text))))))

;;;; Redistribution: saving on consent

(ert-deftest org-iw-cmd-test-redistribute-modified-consent ()
  "A modified affected buffer, named in the prompt, is saved before ranks.
The yes saves it with the user's text intact, then writes the ranks
in a second save.  A modified buffer the plan does not affect stays
modified."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (org-iw-test-edit-elsewhere (org-iw-test-marker "a.org" nil))
    (org-iw-test-edit-elsewhere (org-iw-test-marker "c.org" nil))
    (let ((c-disk (org-iw-test-file-string "c.org"))
          (saves nil))
      (with-current-buffer (org-iw-cmd-test--visited "a.org")
        (add-hook 'after-save-hook
                  (lambda () (push (org-iw-test-file-string "a.org") saves))
                  nil t))
      (org-iw-cmd-test--with-prompt :yes
        (should (org-iw-cmd-test--normalise-essays))
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       (list (concat "Redistribute 2 entries in 1 files of"
                                     " ESSAYS, saving a.org first? ")))))
      (pcase-let ((`(,ranked ,consented) saves))
        (should (equal (length saves) 2))
        (should (string-search "User edit." consented))
        (should (string-search ":IW_ESSAYS: 1536" consented))
        (should (equal ranked (org-iw-cmd-test--with-ranks-replaced
                               consented 1536 2048 1537 3072))))
      (should-not (buffer-modified-p (org-iw-cmd-test--visited "a.org")))
      (should (buffer-modified-p (org-iw-cmd-test--visited "c.org")))
      (should (equal (org-iw-test-file-string "c.org") c-disk)))))

(ert-deftest org-iw-cmd-test-redistribute-modified-cancel ()
  "A no leaves a modified affected buffer, named in the prompt, unsaved."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (org-iw-test-edit-elsewhere (org-iw-test-marker "a.org" nil))
    (let ((before (org-iw-test-state)))
      (org-iw-cmd-test--with-prompt :no
        (should (equal (org-iw-cmd-test--refusal
                        #'org-iw-cmd-test--normalise-essays)
                       "Redistribution of ESSAYS cancelled; nothing changed"))
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       (list (concat "Redistribute 2 entries in 1 files of"
                                     " ESSAYS, saving a.org first? ")))))
      (should (equal (org-iw-test-state) before))
      (should (buffer-modified-p (org-iw-cmd-test--visited "a.org"))))))

(ert-deftest org-iw-cmd-test-redistribute-prompt-names ()
  "The prompt names up to three modified buffers by buffer name, else counts.
Files of one name in two directories have distinct buffer names.  The
preview lists every buffer approval saves."
  (pcase-dolist (`(,edited ,saving)
                 '((("x/notes.org" "y/notes.org")
                    "notes.org<x>, notes.org<y>")
                   (("x/notes.org" "y/notes.org" "a.org")
                    "a.org, notes.org<x>, notes.org<y>")
                   (("x/notes.org" "y/notes.org" "a.org" "b.org")
                    "4 modified buffers (listed)")))
    (org-iw-test-with-corpus
        `(("x/notes.org" . ,(org-iw-test-heading "P" "p1" ":IW_ESSAYS: 1"))
          ("y/notes.org" . ,(org-iw-test-heading "Q" "q1" ":IW_ESSAYS: 2"))
          ("a.org" . ,(org-iw-test-heading "R" "r1" ":IW_ESSAYS: 3"))
          ("b.org" . ,(org-iw-test-heading "S" "s1" ":IW_ESSAYS: 4")))
      (dolist (name edited)
        (org-iw-test-visit name))
      (dolist (name edited)
        (org-iw-test-edit-elsewhere (org-iw-test-marker name nil)))
      (org-iw-cmd-test--with-prompt :no
        (should-error (org-iw-cmd-test--normalise-essays) :type 'org-iw-refusal)
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       (list (format (concat "Redistribute 4 entries in 4"
                                             " files of ESSAYS, saving %s"
                                             " first? ")
                                     saving)))))
      (should (string-search
               (concat "Saved on approval:\n"
                       (mapconcat (lambda (name)
                                    (concat (buffer-name
                                             (org-iw-cmd-test--visited name))
                                            "\n"))
                                  (sort (copy-sequence edited) #'string<) ""))
               (org-iw-cmd-test--preview-text))))))

;;;; Redistribution: the apply

(ert-deftest org-iw-cmd-test-redistribute-applies-minimal ()
  "A clean apply writes only the planned IW_ lines, one put per file.
The order becomes the intended one, at multiples of 1024; the
outcomes are returned and the preview is killed."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (let* ((a (org-iw-test-path "a.org"))
           (b (org-iw-test-path "b.org"))
           (a-text (org-iw-test-file-string "a.org"))
           (b-text (org-iw-test-file-string "b.org"))
           (before (org-iw-test-state))
           (put (symbol-function 'org-iw-write-put-ranks))
           (puts nil))
      (cl-letf (((symbol-function 'org-iw-write-put-ranks)
                 (lambda (changes)
                   (push (length changes) puts)
                   (funcall put changes))))
        (org-iw-cmd-test--with-prompt :yes
          (let ((outcomes (org-iw--redistribute
                           "ESSAYS" (org-iw-cmd-test--move-to "d1" 2)
                           "move D at Soon")))
            (should (equal outcomes
                           `((,a written saved 2) (,b written saved 1))))
            (should (equal (org-iw--redistributed-text outcomes)
                           "redistributed 3 entries in 2 files, saved")))))
      (should (equal (reverse puts) '(2 1)))
      (should (equal (org-iw-test-changed-files before (org-iw-test-state))
                     (list a b)))
      (should (equal (org-iw-test-file-string "a.org")
                     (org-iw-cmd-test--with-ranks-replaced
                      a-text 1536 2048 1537 4096)))
      (should (equal (org-iw-test-changed-lines
                      b-text (org-iw-test-file-string "b.org"))
                     '((":IW_ESSAYS: 4096") . (":IW_ESSAYS: 3072"))))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     '(("c.org" . 1024) ("a.org" . 2048) ("b.org" . 3072)
                       ("a.org" . 4096))))
      (should-not (get-buffer org-iw--redistribution-buffer-name)))))

(ert-deftest org-iw-cmd-test-apply-kills-opened-clean ()
  "The apply kills the buffers it opened once clean; others are kept."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (let ((kept (org-iw-test-visit "a.org")))
      (org-iw-cmd-test--with-prompt :yes
        (should (org-iw--redistribute
                 "ESSAYS" (org-iw-cmd-test--move-to "d1" 2) nil)))
      (should (eq (org-iw-cmd-test--visited "a.org") kept))
      (should-not (buffer-modified-p kept))
      (should-not (org-iw-cmd-test--visited "b.org"))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     '(("c.org" . 1024) ("a.org" . 2048) ("b.org" . 3072)
                       ("a.org" . 4096)))))))

;;;; Normalise

(ert-deftest org-iw-cmd-test-normalise-relays ()
  "Normalise re-lays the queue at multiples of 1024, keeping its order.
Interactively the queue is the session's, which stays as it was.  The
prompt and report name the queue by its configured name."
  (org-iw-test-with-corpus org-iw-cmd-test--uneven
    (let* ((org-iw-queues '(("essays" :name "Essays")))
           (session (org-iw--session-create :queue "ESSAYS" :id "a1"
                                            :title "A"))
           (org-iw--session session))
      (org-iw-cmd-test--with-prompt :yes
        (should (equal (call-interactively #'org-iw-normalise)
                       (concat "Normalised Essays: redistributed 2 entries"
                               " in 1 files, saved")))
        (should (equal (org-iw-cmd-test--prompted :prompt)
                       '("Redistribute 2 entries in 1 files of Essays? "))))
      (should (eq org-iw--session session))
      (should (equal (org-iw-cmd-test--ranks "ESSAYS")
                     '(("c.org" . 1024) ("a.org" . 2048) ("a.org" . 3072)
                       ("b.org" . 4096)))))))

(ert-deftest org-iw-cmd-test-normalise-already-normal ()
  "An empty or already normal queue is reported, with no preview or prompt.
An invalid queue ID is refused."
  (dolist (files `(nil
                   (("a.org"
                     . ,(concat
                         (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1024")
                         (org-iw-test-heading "B" "b1" ":IW_ESSAYS: 2048"))))))
    (org-iw-test-with-corpus files
      (let ((before (org-iw-test-state)))
        (org-iw-cmd-test--with-prompt nil
          (should-not (org-iw-cmd-test--normalise-essays))
          (should (equal (org-iw-normalise "essays")
                         "Queue ESSAYS is already normal"))
          (should (equal (org-iw-cmd-test--refusal
                          (lambda () (org-iw-normalise "no such")))
                         "invalid queue ID \"no such\"")))
        (should-not (get-buffer org-iw--redistribution-buffer-name))
        (should (equal (org-iw-test-state) before))))))

(provide 'org-iw-test)
;;; org-iw-test.el ends here
