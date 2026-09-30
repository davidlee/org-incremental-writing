;;; checkdoc-batch.el --- Run checkdoc in batch, failing on diagnostics  -*- lexical-binding: t; -*-

;;; Commentary:

;; `checkdoc-file' prints its diagnostics as warnings and returns
;; normally, so a batch run exits 0 however many it finds.  This
;; runner counts them and exits non-zero when there are any.  Run it
;; from a batch Emacs with the arguments
;;
;;   -l tools/checkdoc-batch.el -f org-iw-checkdoc-batch FILE...

;;; Code:

(require 'checkdoc)

(defun org-iw-checkdoc-batch ()
  "Checkdoc each file in `command-line-args-left'; exit 1 on any diagnostic."
  (let* ((count 0)
         (report checkdoc-create-error-function)
         (checkdoc-create-error-function
          (lambda (&rest args)
            (setq count (1+ count))
            (apply report args))))
    (dolist (file command-line-args-left)
      (checkdoc-file file))
    (setq command-line-args-left nil)
    (message "checkdoc: %d diagnostic%s" count (if (= count 1) "" "s"))
    (kill-emacs (if (zerop count) 0 1))))

(provide 'checkdoc-batch)
;;; checkdoc-batch.el ends here
