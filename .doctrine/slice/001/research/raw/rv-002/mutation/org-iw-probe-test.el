;;; org-iw-probe-test.el --- reviewer probes  -*- lexical-binding: t; -*-
(require 'org-iw-test-helpers)
(require 'org-iw)

(ert-deftest probe-a1-add-refuses-nonmember-shared-id ()
  "Two non-member headings share an ID in one file; Add must refuse."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "One" "x1")
                            (org-iw-test-heading "Two" "x1"))))
    (let ((m (org-iw-test-marker "a.org" "One")))
      (with-current-buffer (marker-buffer m)
        (goto-char m)
        (should-error (org-iw-add "ESSAYS") :type 'org-iw-refusal)))))

(ert-deftest probe-b2-add-drawerless-before-drawer ()
  "Add a drawerless heading followed by a heading with a drawer."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-org "* New" "Body.")
                            (org-iw-test-heading "Later" "l1"))))
    (let ((m (org-iw-test-marker "a.org" "New")))
      (with-current-buffer (marker-buffer m)
        (goto-char m)
        (should (string-prefix-p "Added" (org-iw-add "ESSAYS")))))))

(ert-deftest probe-b3-visit-narrowed-to-later-subtree ()
  "Buffer narrowed to a subtree after the entry; visit must reach the entry."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-heading "A" "a1" ":IW_ESSAYS: 1")
                            (org-iw-test-org "* Later" "Text."))))
    (let ((m (org-iw-test-marker "a.org" "Later")))
      (with-current-buffer (marker-buffer m)
        (goto-char m)
        (narrow-to-region m (point-max)))
      (org-iw-visit-next "ESSAYS")
      (should (equal (org-get-heading t t t t) "A")))))

(ert-deftest probe-b4-d12-visit-nested-folded ()
  "Entry is a child of a folded parent; visit must land on it, revealed."
  (org-iw-test-with-corpus
      `(("a.org" . ,(concat (org-iw-test-org "* Parent" "Parent text.")
                            "*" (org-iw-test-heading "Child" "c1" ":IW_ESSAYS: 1")
                            (org-iw-test-org "Child body."))))
    (with-current-buffer (org-iw-test-visit "a.org") (org-overview))
    (org-iw-visit-next "ESSAYS")
    (should (equal (org-get-heading t t t t) "Child"))
    (should-not (invisible-p (point)))))

(ert-deftest probe-c4-rank-limit-is-2^53-1 ()
  (should-not (org-iw-core-parse-rank "9007199254740992")))
