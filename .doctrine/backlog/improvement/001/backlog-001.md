# IMP-001: Public session string and display setting for org-iw

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Context

Found in the SL-001 VH-1 trial (2026-10-01). The user's lambda-line builds
its own mode-line string and never reads `global-mode-string`, so the
session item showed only in the tab bar (`tab-bar-format-global`). org-iw
follows the standard convention (as display-time and org-clock do); the
gap is that it offers no supported hook for a custom mode line.

## Proposal

Follow org-clock (`org-mode-line-string` + `org-clock-clocked-in-display`):
expose the state and let the user choose where it shows.

1. Public `org-iw-session-string`, replacing private `org-iw--mode-line`.
   Returns the bare `IW[NAME: TITLE]` text, `%`-escaped, or nil.
2. A `defcustom` (e.g. `org-iw-display`): `global-mode-string` (default)
   or nil. With nil, org-iw never touches `global-mode-string`; the user
   wires the string in.
3. Move the separator out of the text and into the `global-mode-string`
   item. The trailing space added in SL-001 PHASE-08 currently lives in
   the text, which a lambda-line splice would inherit.
4. Optional, deferred: `org-iw-session-change-hook`, so integrations can
   cache instead of `:eval`-ing every redisplay. Add only when needed.

## Notes

- A public API change beyond the locked SL-001 design: needs its own
  slice, or a later slice that owns session/display.
- The user's integration side (lambda-line splice, `dl-org-iw.el`) is
  outside this repo.
