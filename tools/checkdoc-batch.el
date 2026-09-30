;;; checkdoc-batch.el --- Run checkdoc in batch, failing on diagnostics  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 David Lee

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
