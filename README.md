# org-incremental-writing

Incremental writing queues for Org. A queue is a named, ordered list of
existing Org headings. You open the first one, work on it, then put it
back — soon, later, or at the end — and move on to the next.

Queue state lives on each heading as an `IW_<QUEUE>` property holding an
integer rank. There is no index file, and content never moves.

Status: 0.1.0, pre-release. The feature set covers adding, visiting, and
Continue with a choice of placement.

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
  - `:placements` and `:default` give the queue its own placements (see
    below).

### Placements

Continue puts the entry back at a *placement*, and Add can enrol a heading
at one. A placement is one of:

| Form | Puts the entry |
|---|---|
| `(after N)` | after N of the other entries (at the end if there are fewer) |
| `(fraction NUM DEN)` | NUM/DEN of the way back, rounded towards the front |
| `(percent P)` | P percent of the way back, rounded likewise |
| `end` | after all of them |

`(after 0)`, `(fraction 0 1)` and `(percent 0)` put the entry first, so
Continue reopens it at once.

Placements are named by labels. Unless a queue says otherwise, the labels
are `org-iw-placements`, and the default is `org-iw-default-placement`:

```elisp
(setq org-iw-placements '(("Soon"  (after 2))        ; the standard set
                          ("Later" (fraction 1 2))
                          ("End"   end))
      org-iw-default-placement "End")                ; nil: the first label
```

A queue can have its own labels and default:

```elisp
(setq org-iw-queues
      '(("ARTICLES" :name "Articles"
         :placements (("Soon" (after 2)) ("Later" (fraction 1 2)) ("End" end))
         :default "Soon")
        ("TWEETS" :name "Tweets"
         :placements (("Another pass" (after 5)) ("Later" (percent 75))))))
                                       ; no :default: the first label
```

A queue with `:default` but no `:placements` uses the global labels.
Labels are not written to your files, so renaming one changes nothing on
disk. Bad configuration (an invalid placement, a duplicate label, a default
that is not a label) is refused when a command uses it, naming the option
at fault.

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
| `org-iw-add` | Add the heading at point to the end of a queue, whatever its default; with `C-u`, choose the placement, defaulting to the queue's default. |
| `org-iw-visit-next` | Show the first entry of a queue and start a session on it. |
| `org-iw-continue` | Put the session's entry back at the queue's default placement and visit the first entry; with `C-u`, choose the placement. |
| `org-iw-end-session` | End the session and remove it from the mode line. |

A typical round:

1. On a heading you want to come back to, run `org-iw-add` and pick or type
   a queue. The heading gets an `:ID:` (if it had none) and an
   `:IW_ESSAYS: 1024`-style property, and the file is saved. A heading
   already in the queue is left alone.
2. When you feel like working, run `org-iw-visit-next`. It shows the first
   entry, and the mode line shows `IW[Essays: Title]`. Visiting changes
   nothing; visiting again shows the same entry.
3. Work on the entry and save as usual.
4. Run `org-iw-continue`. The entry goes back at the default placement,
   which changes at most one `IW_` line, and the first entry is shown.
   Run `C-u M-x org-iw-continue` to pick Soon, Later or End instead.
5. Repeat step 4, or run `org-iw-end-session` when done.

With a session running, `org-iw-visit-next` reuses its queue; give it a
prefix argument (`C-u`) to choose another.

An entry already at its placement, or the only entry in its queue, is
not written. In a small queue that can mean Continue reopens the same
entry: with two entries, Later is the front.

The chooser lists the labels in configured order. Completion UIs that
float the default to the top (icomplete, fido, vertico) show it first;
`RET` always picks the default.

Bound to a key, a placement needs no prompt:

```elisp
(keymap-global-set "C-c i s" (lambda () (interactive) (org-iw-continue "Soon")))
```

### What gets written, and when

- Only `org-iw-add` and `org-iw-continue` write, and each changes at most
  one `IW_` line. Add may also give the heading a property drawer and an ID.
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
there is no session for Continue, or there is no room at the chosen
placement.

"No room" means the ranks around that placement are used up. Using one
placement over and over, such as Soon, uses up its gap after about ten
Continues. Choose another placement for now; the end always has room.
Automatic rebalancing is planned.

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
