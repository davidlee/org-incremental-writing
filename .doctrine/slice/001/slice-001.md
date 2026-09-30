# Walking skeleton

## Context

First increment of RFC-001 (`doctrine rfc show RFC-001`), cutting through
all four layers of PRD-001 (`doctrine spec show PRD-001`). The goal is
the smallest loop the user can trial: enrol headings, visit the front,
edit in place, send the entry to the back, and repeat.

## Scope & Objectives

- **Tooling.** Makefile targets `compile`, `lint`, `test`, `test-all` and
  `clean`. ERT runs in batch. Lint is byte-compile with warnings as errors,
  checkdoc and package-lint. The flake gains an `emacs-30` binary from a
  pinned `nixos-26.05` input so the suite runs on 30.2 and 31.1 (REQ-024,
  DEC-006).
- **Package skeleton.** `org-iw` with `Package-Requires: ((emacs "30.1"))`
  and files split along the layers.
- **Queue configuration (minimal).** A `defcustom` listing queues by ID and
  display name. Queue IDs are validated and canonicalised (REQ-003).
  Queues found in files but not configured can still be chosen.
- **Ordering core (pure).** Parse `IW_<Q>` properties and ignore reserved
  `IW_AFTER_<Q>` (REQ-001). Order by rank ascending, then entry ID
  (REQ-008). Allocate the append rank. Exact integers only (REQ-023).
- **Discovery.** Configured files and directories, deduplicated
  (REQ-005). Live buffers take precedence over disk (REQ-006). Properties
  are read locally, never inherited. File-level drawers are read too, so
  SL-004 needs no second reader; they are not targeted by add until SL-004.
- **Mutation.** Set one membership property and add an Org ID when
  enrolling, leaving all other data intact (REQ-004). Save policy: save
  clean buffers, leave already-modified ones and report (REQ-021). Normal
  undo (REQ-022).
- **Commands.**
  - Add the heading at point to a chosen queue, appended at the end
    (REQ-011, partial). Adding an existing membership is a no-op.
  - Visit next: read-only, keeps the entry and queue as session context
    and shows them (REQ-014).
  - Continue to End: acts on the kept membership, then opens the new
    front entry (REQ-015, partial).
  - End session: clears the kept context and its mode-line display.
- **Minimal safety.** Refuse to write when the target's ID is duplicated
  or its rank is invalid, when a typed queue ID is invalid, or when the
  file isn't under the configured sources (a membership no queue would
  show). Only a plain message for now; actionable
  diagnostics come in SL-005.

## Non-Goals

- Other placement forms, labelled vocabulary, the Continue chooser
  (SL-002).
- Queue view, move, remove (SL-003).
- Document targets, batch add (SL-004).
- Refile resolution, diagnostics UX (SL-005).
- Redistribution (SL-006). Append and tail rotation never need it.

## Summary

Affected surface (coarse): `*.el`, `test/**`, `Makefile`, `flake.nix`.

Governed by the "before SL-001" documents in RFC-001's governance
schedule: A1 entry-resident state, A3 buffer-mediated writes, A4 layering,
P1 lint and test gate, P2 one implementation per concept, P3 human trial.

Settled in design (`design.md`, DEC-001 to DEC-006):
- PRD-001 OQ-1 provisionally: rescan with a text prefilter (DEC-003);
  SL-004 re-measures.
- PRD-001 OQ-2 provisionally: buffers opened only to write stay open
  (DEC-004).
- PRD-001 OQ-4: session held in memory, shown in the mode line (DEC-005).

Risks and assumptions:
- Assumes Org 9.7+ `org-entry-get` with inheritance off and
  `org-id-get-create` behave as needed.
- Adding Emacs 30 to the flake touches the user's dev-shell wiring, and the
  agent jail has no `nix` to build it; the user runs `make test-all`.
- Auto-saving a clean buffer runs the user's save hooks (design § 8).

**Closure:** P1 gate green on Emacs 30 and 31. Human trial (VH): configure
a queue, add three headings across two files, then Visit and Continue in a
full cycle. Each Continue changes one line in one file (check with
`git diff`). A dirty buffer is left unsaved with a message.

## Follow-Ups

- S1 standard and the Tooling section of `governance.md`, harvested at
  close (RFC-001 governance schedule).
