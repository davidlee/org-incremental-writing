# org-incremental-writing

A way of doing "soon" in Org.

Some things don't belong on a calendar. A half-formed idea, a project
you don't want to forget, a topic you're learning, a chore for when you
have time: you want to come back to them, in some order, but not on a
date. org-iw (short for org-incremental-writing) keeps them in *queues*.
When you feel like working, open the first entry, do a little, put it
back — soon, later, or at the end — and move on to the next.

![banner](./assets/octopus.jpg)

## What people use it for

- **Daily notes.** New journal notes join a review queue automatically,
  so each one gets a second look for follow-ups.
- **Ideas.** An idea that isn't ready goes into a queue to marinate, and
  comes back round in a while.
- **Active projects.** Rotating through them means none is quietly
  forgotten.
- **Learning.** Each topic is a note. Do a little, then queue it for
  revision.
- **Someday tasks.** Things worth doing when there's time, without
  pretending to know when that will be.

The common thread: relative order matters more than calendar time.

## How it works

```
  queue "Ideas"           org-iw-visit-next        org-iw-continue
  ┌──────────────┐        ┌──────────────┐        ┌──────────────┐
  │ 1 Idea A     │ ─────▶ │ opens Idea A │ ─────▶ │ 1 Idea B     │
  │ 2 Idea B     │        │ you work on  │        │ 2 Idea C     │
  │ 3 Idea C     │        │ it, and save │        │ 3 Idea A ◀── put back
  └──────────────┘        └──────────────┘        └──────────────┘
                                                    and Idea B opens
```

- An entry is an Org heading, or a whole file.
- Your notes stay where they are. Being in a queue is one property on
  the entry, such as `:IW_IDEAS: 2048`; there is no database or index
  file. Remove the line and the entry leaves the queue.
- Opening an entry changes nothing. Only adding, putting back, moving
  and removing do. Each usually changes one line (Add also gives a
  heading an `:ID:` if it has none), and you can see it in `git diff`
  and undo it in the buffer.
- Position is not importance. TODO states, priorities and schedules are
  left alone.

## Getting started

### Install

You need Emacs 30.1 or later and the Org that comes with it. Nothing
else is required; [Denote](https://protesilaos.com/emacs/denote) works
well with it but is optional.

Install it straight from GitHub, and point it at your notes:

```elisp
(use-package org-iw
  :vc (:url "https://github.com/davidlee/org-incremental-writing"
       :rev :newest)
  :custom
  (org-iw-sources '("~/notes/")))   ; directories (searched recursively) or files
```

That's all the configuration you need. Queues are created by naming
them. To update later, run `M-x package-vc-upgrade`. (Prefer a plain
clone? See the [manual](doc/manual.md#install-from-a-clone).)

### Bind some keys

org-iw binds no keys itself. A starting set:

```elisp
(keymap-global-set "C-c i a" #'org-iw-add)          ; add the heading (or file) here
(keymap-global-set "C-c i v" #'org-iw-visit-next)   ; open a queue's first entry
(keymap-global-set "C-c i c" #'org-iw-continue)     ; put it back, open the next
(keymap-global-set "C-c i l" #'org-iw-list-queue)   ; see and reorder a queue
```

### A first round

1. Go to a heading you want to come back to and press `C-c i a`. Type a
   new queue name, say `IDEAS`. Add a couple more headings the same way.
2. Press `C-c i v` and choose `IDEAS`. The first entry opens, and the
   mode line shows which queue you're working through.
3. Work on it as much or as little as you like.
4. Press `C-c i c`. The entry goes to the back of the queue and the next
   one opens. With `C-u C-c i c` you choose where it goes instead:
   Soon, Later, End, or Remove when it's done.
5. Repeat, or stop whenever you like with `M-x org-iw-end-session`.
   Nothing is lost by stopping; the queue is in your files.

To see a whole queue, and reorder it, press `C-c i l`.

### Trying it safely

Everything org-iw does is a visible change to your Org files, so it's
easy to try with version control as a safety net: commit your notes
first, then check `git diff` after adding and continuing. To undo it
all, revert the files.

## Next steps

The [manual](doc/manual.md) covers the rest, including:

- [Naming queues and choosing placements](doc/manual.md#configure),
  such as what Soon and Later mean for each queue.
- [Whole files as entries](doc/manual.md#documents-as-entries), and
  [adding many files at once](doc/manual.md#adding-many-files) from
  Dired.
- [Adding new notes to a queue automatically](doc/manual.md#add-new-notes-to-a-queue-automatically),
  for example every new Denote journal note.
- [The queue view](doc/manual.md#queue-view) and its keys.
- [Exactly what gets written, and when](doc/manual.md#what-gets-written-and-when).

Status: 0.1.0, pre-release. Tested on Emacs 30.2 (Org 9.7.11) and 31.1
(Org 9.8.10).

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
