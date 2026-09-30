;;; org-iw.el --- Incremental writing queues for Org  -*- lexical-binding: t; -*-

;; Author: David Lee <david.lee@inlight.com.au>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1"))
;; URL: https://github.com/davidlee/org-incremental-writing
;; Keywords: outlines, wp

;;; Commentary:

;; Incremental writing for Org: named queues of headings, worked
;; through one entry at a time.  Queue state lives on each entry as an
;; IW_<QUEUE> property holding an integer rank; there is no index file.

;;; Code:

(defgroup org-iw nil
  "Incremental writing queues for Org."
  :group 'org
  :prefix "org-iw-")

(defcustom org-iw-sources nil
  "Files and directories whose Org entries may belong to queues.

A file is used as is.  A directory is searched recursively for
files named *.org, with these rules:

- Below a listed directory, hidden directories (names starting
  with a dot, such as .git) are skipped.  A listed directory that
  is itself hidden, such as ~/.notes, is still searched.
- Symbolic links to directories are not followed; list the
  target instead.
- Names starting with .# (Emacs lock files) are skipped, as is
  anything that is not a regular file once symlinks are resolved.

Files are compared by their true names, so a file reached through
two sources is used once.  See also `org-iw-exclude-regexp'."
  :type '(repeat (choice (file :tag "File")
                         (directory :tag "Directory")))
  :group 'org-iw)

(defcustom org-iw-exclude-regexp nil
  "Regexp matching the true names of source files to ignore.
When nil, no file found through `org-iw-sources' is excluded."
  :type '(choice (const :tag "None" nil) regexp)
  :group 'org-iw)

(defcustom org-iw-queues nil
  "Configured queues, as an alist of (QUEUE-ID . PLIST).

QUEUE-ID is a string of letters, digits and hyphens, compared
case-insensitively; entries join the queue through an IW_QUEUE-ID
property.  PLIST supports :name, the display name shown in prompts
and the mode line.

Queues found in source files but not listed here can still be
chosen; they are shown by their ID."
  :type '(alist :key-type (string :tag "Queue ID")
                :value-type (plist :tag "Options"
                                   :options ((:name string))))
  :group 'org-iw)

(provide 'org-iw)
;;; org-iw.el ends here
