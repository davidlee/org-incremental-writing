;;; -*- lexical-binding: t -*-
(require 'org)
(let* ((files (directory-files-recursively "/home/david/work/corpus" "\\.org\\'")) (n 0) (t0 (float-time)))
  (dolist (f files)
    (with-temp-buffer
      (insert-file-contents f)
      (goto-char (point-min))
      (when (let ((case-fold-search t)) (re-search-forward "^[ \t]*:IW_" nil t))
        (delay-mode-hooks (org-mode))
        (goto-char (point-min))
        (let ((seen nil) (case-fold-search t))
          (while (re-search-forward "^[ \t]*:IW_[^:\n]*:" nil t)
            (when (org-at-property-p)
              (save-excursion
                (org-back-to-heading-or-point-min t)
                (unless (memq (point) seen)
                  (push (point) seen) (cl-incf n)
                  (list (org-entry-properties nil 'standard) (org-get-heading t t t t))))))))))
  (message "files=%d entries=%d scan=%.3fs" (length files) n (- (float-time) t0)))
