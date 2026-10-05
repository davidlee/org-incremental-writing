# org-incremental-writing

Incremental writing queues for Org. A queue is a named, ordered list of
existing Org headings or whole documents (files). You open the first one, work on it, then put it
back — soon, later, or at the end — and move on to the next.

Queue state lives on each entry as an `IW_<QUEUE>` property holding an
integer rank: on a heading's property drawer, or, for a document, on the
drawer at the top of the file. There is no index file, and content never moves.

Status: 0.1.0, pre-release. The feature set covers adding, visiting,
Continue with a choice of placement, moving and removing entries, a view
of each queue in which to reorder it, documents as entries, and adding
many files at once.

![banner](./assets/octopus.jpg)

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
  :commands (org-iw-add org-iw-add-document org-iw-add-files org-iw-visit-next org-iw-continue org-iw-end-session
             org-iw-move org-iw-remove org-iw-list-queue))
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

Continue puts the entry back at a *placement*, Move moves an entry to one,
and Add can enrol a heading at one. A placement is one of:

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
at fault. The label "Remove", in any case, is reserved: Continue's
chooser uses it, so a placement named so is refused as configuration.

No keys are bound. Suggested bindings:

```elisp
(keymap-global-set "C-c i a" #'org-iw-add)
(keymap-global-set "C-c i d" #'org-iw-add-document)
(keymap-global-set "C-c i f" #'org-iw-add-files)
(keymap-global-set "C-c i v" #'org-iw-visit-next)
(keymap-global-set "C-c i c" #'org-iw-continue)
(keymap-global-set "C-c i q" #'org-iw-end-session)
(keymap-global-set "C-c i m" #'org-iw-move)
(keymap-global-set "C-c i r" #'org-iw-remove)
(keymap-global-set "C-c i l" #'org-iw-list-queue)
```

## Use

| Command | Does |
|---|---|
| `org-iw-add` | Add the heading at point to the end of a queue, whatever its default; before the first heading, add the file's document instead. With `C-u`, choose the placement, defaulting to the queue's default. |
| `org-iw-add-document` | Add the current file's document, from anywhere in it, as `org-iw-add` does; `C-u` likewise. |
| `org-iw-add-files` | Add many files (or the Org files under a directory) to the end of a queue: the marked files in Dired, else one file or directory you name. |
| `org-iw-visit-next` | Show the first entry of a queue and start a session on it. |
| `org-iw-continue` | Put the session's entry back at the queue's default placement and visit the first entry; with `C-u`, choose the placement, or Remove. |
| `org-iw-end-session` | End the session and remove it from the mode line. |
| `org-iw-move` | Move the entry at point to a placement in its queue; with `C-u`, choose which of its queues. |
| `org-iw-remove` | Remove the entry at point (or the document, before the first heading) from a queue; with `C-u`, choose which of its queues. |
| `org-iw-list-queue` | Show a queue's entries in order, to reorder or remove them. |

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
   Its last candidate, Remove, takes the entry out of the queue and
   visits the next one.
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

### Documents as entries

A whole file can be an entry. Its membership is the file-level property
drawer at the top of the file, before any heading:

```org
:PROPERTIES:
:IW_JOURNAL: 1024
:END:
#+title: 2026-05-12 Tuesday
```

- The document's headings are not entries because of it, and do not
  inherit it. They can be added on their own.
- Run `org-iw-add` before the first heading, or `org-iw-add-document`
  anywhere in the file (narrowing and indirect buffers make no
  difference). The prefix argument chooses the placement, as for a
  heading. A document already in the queue is left alone, and the file is
  saved under the same rule as for a heading.
- If the file starts with a heading, adding the document changes only the
  inserted drawer; the heading and its own drawer are untouched.
- The drawer must come first. A file with a property drawer after
  `#+title:` is refused with "entry has a property drawer Org doesn't
  recognise" and the file is left unchanged (in a batch, that file fails
  and the rest proceed); move the drawer to the top.

#### Document identity

A queue entry is identified by its ID, and a document's is, in order:

1. the `:ID:` in its file-level drawer, if it has one;
2. else, if [Denote](https://protesilaos.com/emacs/denote) is available
   and the file name follows Denote's naming scheme, the identifier in
   the name;
3. else none, and Add inserts an `:ID:` in the drawer.

So a Denote note never gains an `:ID:` from org-iw. Denote is loaded if
present and is not required; the name alone decides, so a note outside
`denote-directory` still counts, and `#+identifier:` is never read. Headings
always carry an `:ID:`; Add gives one if missing.

Consequences:

- In a session without Denote, a Denote-identified member cannot be
  identified. It is skipped and reported as having no ID, and drops out
  of the queue until Denote is available.
- If a note later gains an `:ID:` (from org-roam, say), its identity
  switches to that ID. Its membership survives, but a session naming the
  old identity reports the entry gone.
- Copies of a note sharing one identifier are duplicate-ID problems and
  are skipped.

### Adding many files

`M-x org-iw-add-files` asks for a queue, then takes the files marked in
Dired (the file at point if none is marked); elsewhere it reads one file
or directory. A directory stands for the Org files under it, chosen as
for `org-iw-sources`. Lisp callers pass a list of files and directories.

- Files are added in the order of their true names, duplicates removed,
  each after the last entry of the queue. Existing entries keep their
  ranks.
- A file outside `org-iw-sources` or matching `org-iw-exclude-regexp`
  fails, as does one `org-iw-add-document` would refuse, and a second
  file with the ID of one already added in the batch. The others go on.
- It is not atomic. Quitting (`C-g`) or an unexpected error stops the
  batch; files already added stay added, and the summary is still shown.
- It reports in the echo area, for example `Added 70 to Journal, 3
  already present, 1 failed, 0 unsaved (not atomic; see *org-iw batch*)`.
  The `*org-iw batch*` buffer lists failed files, and files added but
  left unsaved, with the reason. It appears only when there are any.
- Buffers it opened are closed once done with, unless left modified (a
  failed save, say). A buffer you already had open is never closed. An
  open file with unsaved edits is added but reported unsaved.
- The session is untouched. At the rank limit, that file and the rest
  fail with "no room"; automatic redistribution is planned.

Run over 74 journal files, `git diff` shows one drawer added to each
(`:IW_JOURNAL: 1024`, `2048`, ...), and no `:ID:`.

### Moving and removing an entry

`org-iw-move` and `org-iw-remove` act on the heading at point, or on the
file's document entry before its first heading. The queue is the entry's
only queue; of several, the session's, if it is one of them; else you
pick one. With `C-u`, you always pick one of the entry's queues.
`org-iw-move` then asks for a placement label in that queue (the prompt
names it), defaulting to the queue's default. Neither visits anything,
and the session is left as it is.

`org-iw-remove` deletes the entry's `IW_<QUEUE>` line and asks no
confirmation: undo in the file's buffer brings the line back. The
heading, its ID and its other queues stay. Removing a document's last
queue also removes the drawer org-iw made, so the file is as it was
before Add; undo restores it. A heading keeps its drawer.

An entry can leave a queue in three places:

- `org-iw-remove` at the entry;
- `D` in the queue view (below), which confirms first;
- Remove, the last candidate of `C-u M-x org-iw-continue`, which then
  visits the next entry.

### Removing the session's entry

Removing the entry the session is on, with `org-iw-remove` or `D`,
leaves the session as it is:

- The mode line still names the removed entry, and the message says so.
- `org-iw-continue` refuses ("T is no longer in queue NAME"), because
  there is no entry to put back. If it was the queue's last entry,
  Continue reports "Queue NAME is empty" instead.
- Run `org-iw-visit-next` to go on with the queue's first entry, or
  `org-iw-end-session` to stop.

This is on purpose: it makes Remove undoable. Undo in the file's buffer
brings the entry back, and the session works again as if nothing
happened, Continue included. If Remove ended the session, undo would
restore the file but not the session.

Deleting the entry's `IW_` line by hand has the same effect.

## Queue view

`M-x org-iw-list-queue` shows a queue in the buffer `*org-iw: NAME*`. The
queue is the session's; with `C-u`, or without a session, you pick one.

| Column | Shows |
|---|---|
| # | the entry's position, 1 first |
| Title | the heading, links shown as their descriptions |
| Context | the headings above it, nearest last |
| File | the file's name |

The session's entry has a `*` after its position and a bold title. A
marked entry has a `>` before its row.

| Key | Does |
|---|---|
| `RET` | Show the entry in another window and start a session on it. |
| `M-<up>` / `M-<down>` | Move the entry one row up or down. |
| `m` / `u` | Mark the entry (replacing any mark) / clear the mark. |
| `b` / `a` | Place the marked entry before / after the entry at point; the mark clears. |
| `D` | Remove the entry from the queue, after a `y`/`n` confirmation. |
| `g` | Refresh. |
| `q` | Quit. |
| `n` / `p` | Next / previous row. |

`D` confirms because the view has no undo. The file's buffer has: undo
there, then press `g`.

Every action that opens, moves or removes an entry reads your files
afresh, so it acts on what they hold now, not on what the rows show. The
view itself never refreshes on its own: after an edit or an undo in a
file, press `g` to see the new order.

org-iw binds no other keys, so your own search and jump commands reach
the rows.

### What gets written, and when

- Add, Continue, Move, Remove and the view's actions write. Each changes
  at most one `IW_` line, and Remove deletes it. Add may also give the
  entry a property drawer and an ID (a Denote note gets no ID), and
  Remove may take a document's emptied drawer. `org-iw-add-files` writes
  as Add does, once per file. Nothing else writes.
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
the file is not an Org source file, there is no session for Continue, or there is no room at the chosen
placement.

"No room" means the ranks around that placement are used up, and the
message names where: at a label, at the end, before or after an entry,
or at a position. Using one placement over and over, such as Soon, uses
up its gap after about ten Continues; two entries with equal ranks
leave no room between them. Placing an entry first, or at the end,
always has room. Automatic redistribution of ranks is planned.

Malformed or duplicated `IW_` properties and IDs are skipped, not fatal.
Messages then end with `[N source problems ignored]`.

## Trying it on your own notes

Queue state is ordinary text in your files, so review it through version
control:

1. Commit (or copy and commit) your notes, so `git diff` shows exactly
   what org-iw changed.
2. Point `org-iw-sources` at them and follow *A typical round* above,
   checking `git diff` after each Add and Continue.
3. To try documents and batch add, mark a directory's files in Dired and
   run `org-iw-add-files`. `git diff` should show one drawer added per
   file. The batch closes the buffers it opened, so there is no undo for
   them: revert with `git checkout` or `org-iw-remove` per document. (Undo
   works only in a buffer that was already open.)
4. To undo everything, `git checkout` the files. To remove a heading from
   a queue, run `org-iw-remove` on it, or delete its `IW_<QUEUE>` line by
   hand.

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
