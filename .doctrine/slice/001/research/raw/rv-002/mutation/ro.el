(require 'org-iw-test-helpers)
(org-iw-test-with-corpus `(("a.org" . ,(org-iw-test-heading "Target" "t1" ":IW_ESSAYS: 1024")))
  (let ((m (org-iw-test-marker "a.org" "Target")))
    (with-current-buffer (marker-buffer m) (setq buffer-read-only t))
    (condition-case err
        (message "RESULT %S" (org-iw-write-put-rank m "ESSAYS" 2048 :expected 1024))
      (error (message "SIGNAL %S refusal-p=%S modified=%S" err
                      (eq (car err) 'org-iw-refusal)
                      (buffer-modified-p (marker-buffer m)))))))
