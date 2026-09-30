# org-incremental-writing

Incremental writing queues for Org. A queue is a named, ordered list of
existing Org headings. You open the first one, work on it, then send it to
the back of the queue and move on to the next.

Queue state lives on each heading as an `IW_<QUEUE>` property holding an
integer rank. There is no index file, and content never moves.

Status: 0.1.0, pre-release. The feature set covers adding, visiting and
Continue to End.

## Requirements

- Emacs 30.1 or later; tested on 30.2 (Org 9.7.11) and 31.1 (Org 9.8.10).
- The Org that ships with Emacs. No other dependencies.

## Install

Clone the repository and put it on your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/org-incremental-writing")
(require 'org-iw)
```

Or with `use-package`:

```elisp
(use-package org-iw
  :load-path "/path/to/org-incremental-writing"
  :commands (org-iw-add org-iw-visit-next org-iw-continue org-iw-end-session))
```

## Configure

```elisp
(setq org-iw-sources '("~/notes/"                 ; searched recursively for *.org
                       "~/org/inbox.org")         ; or a single file
      org-iw-exclude-regexp "/archive/"           ; optional; matched against true names
      org-iw-queues '(("ESSAYS" :name "Essays")   ; optional display names
                      ("ZIG"    :name "Practise Zig")))
```

- **`org-iw-sources`**: files and directories that may hold queue entries.
  - A directory is searched recursively for `*.org`.
  - Hidden directories below it (`.git`, …) are skipped.
  - Symlinked directories are not followed; list the target instead.
  - Emacs lock files (`.#…`) are skipped.
- **`org-iw-exclude-regexp`**: true names matching this regexp are ignored.
  Matching is case-sensitive.
- **`org-iw-queues`**: an alist of `(QUEUE-ID . PLIST)`.
  - A queue ID is letters, digits and hyphens, compared case-insensitively.
  - `:name` is the name shown in prompts and the mode line.
  - Queues found in your files but not listed here can still be chosen;
    they show by ID.

No keys are bound. Suggested bindings:

```elisp
(keymap-global-set "C-c i a" #'org-iw-add)
(keymap-global-set "C-c i v" #'org-iw-visit-next)
(keymap-global-set "C-c i c" #'org-iw-continue)
(keymap-global-set "C-c i q" #'org-iw-end-session)
```

## Use

| Command | Does |
|---|---|
| `org-iw-add` | Add the heading at point to the end of a queue. |
| `org-iw-visit-next` | Show the first entry of a queue and start a session on it. |
| `org-iw-continue` | Move the session's entry to the end of its queue and visit the next one. |
| `org-iw-end-session` | End the session and remove it from the mode line. |

A typical round:

1. On a heading you want to come back to, run `org-iw-add` and pick or type
   a queue. The heading gets an `:ID:` (if it had none) and an
   `:IW_ESSAYS: 1024`-style property, and the file is saved.
2. When you feel like working, run `org-iw-visit-next`. It shows the first
   entry, and the mode line shows `IW[Essays: Title]`. Visiting changes
   nothing; visiting again shows the same entry.
3. Work on the entry and save as usual.
4. Run `org-iw-continue`. The entry is ranked after the others, which
   changes exactly one `IW_` line, and the next entry is shown.
5. Repeat step 4, or run `org-iw-end-session` when done.

With a session running, `org-iw-visit-next` reuses its queue; give it a
prefix argument (`C-u`) to choose another.

### What gets written, and when

- Only `org-iw-add` and `org-iw-continue` write, and each changes one
  `IW_` line. Add may also give the heading a property drawer and an ID.
- Writes go through the file's buffer, so undo works.
- If that buffer was unmodified, it is saved; the message ends `(saved)`.
- If it already had unsaved changes, it is left unsaved. The message
  says the queue change is not saved, and the file on disk is untouched
  until you save.
- Saving runs your usual save hooks, so something like whitespace
  cleanup can change other lines too.

### Refusals

When something is off, a command refuses with an `org-iw refused: "…"`
message and changes nothing. Examples: the file changed on disk, the
heading's ID is shared with another heading, the entry has left the queue,
or there is no session for Continue.

Malformed or duplicated `IW_` properties and IDs are skipped, not fatal.
Messages then end with `[N source problems ignored]`.

## Trying it on your own notes

Queue state is ordinary text in your files, so review it through version
control:

1. Commit (or copy and commit) your notes, so `git diff` shows exactly
   what org-iw changed.
2. Point `org-iw-sources` at them and follow *A typical round* above,
   checking `git diff` after each Add and Continue.
3. To undo everything, `git checkout` the files. To remove a heading from
   a queue by hand, delete its `IW_<QUEUE>` line.

## Development

The recipes use [`just`](https://github.com/casey/just) and assume
`emacs` (31) and `emacs-30` on `PATH`. `nix develop` provides both.

```sh
just lint        # byte-compile, checkdoc, package-lint, relint (Emacs 31)
just test-all    # ERT on Emacs 31 and 30
just gate        # lint + test-all
just coverage    # coverage report, not gating
```

Redirect stdin (`just test-all </dev/null`) when running non-interactively,
so a test that prompts fails instead of hanging.

## License

GPL-3.0-or-later. See `LICENSE.md`.
