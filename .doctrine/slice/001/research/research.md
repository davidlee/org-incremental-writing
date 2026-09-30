# SL-001 research — walking skeleton

**Producers:** orchestrating agent (Claude Opus 5.5), both threads run
in-session. No project research agents are defined (`.doctrine/governance.md`
§ Research agents is empty). Thread 2 is greenfield, so the code map was
replaced by executable API probes against the dev-shell Emacs.
**Baseline:** `baseline.toml` (stamped by `doctrine slice research 1`,
2026-09-30).
**Raw:** `raw/probe.el` + `raw/api-probe.out` (Org API behaviour),
`raw/scan.el` + `raw/scan-timing.out` (discovery cost).

## Verification legend

✓ = verified by the consuming agent (probe output or read of the cited
source). Unmarked = claim, not checked.

## Thread 1 — governance applicability

Binding:

- ✓ **ADR-001 (entry-resident state):** membership is read only from
  `IW_<Q>` properties in sources. The only permitted store is a disposable
  in-memory cache. SL-001 needs none (see T2-6).
- ✓ **ADR-002 (buffer-mediated writes):** every write goes through a
  visiting buffer, with the clean-save / dirty-leave policy; live buffers
  beat disk; single writer.
- ✓ **ADR-003 (layering):** four layers, one file each, in dependency
  order. The core must not `(require 'org)`.
- ✓ **POL-001:** a Makefile provides `lint` (byte-compile with
  warnings as errors, checkdoc, package-lint) and `test` (ERT batch on
  Emacs 30 and 31).
- ✓ **POL-002:** one owner per concept. Test fixture helpers live in one
  helper file.
- ✓ **POL-003:** the plan must carry a VH trial. Build no infrastructure
  beyond the skeleton loop.
- ✓ **PRD-001 § 4 constraints:** `org-iw-` prefix, Emacs 30.1, no runtime
  dependencies, local reads, integer ranks.

Checked, not applicable:

- **Standards:** none exist. S1 is harvested at close by design (RFC-001).
- **Tech specs:** none exist. The brief's implementation guidance feeds
  the design directly.
- **A2 (sparse integer ranks):** no ADR yet, scheduled before SL-002.
  SL-001 needs only the append rank (last + spacing) and reading the front,
  which no alternative A2 could invalidate.

Revision candidates: none.

## Thread 2 — API facts (probes, Emacs 31.1 / Org 9.8.10)

- **T2-1 ✓** Keyword `sort` (`:key`, `:lessp`) and `value<` exist
  (`raw/api-probe.out` line "sort-kw"). Both are Emacs 30.1 features. This
  is unverified on 30 because no Emacs 30 is in the shell.
- **T2-2 ✓** Integers promote to bignums exactly (`fixnump` nil past
  `most-positive-fixnum`), so rank arithmetic never needs a float.
- **T2-3 ✓** At `point-min`, `org-entry-get nil "IW_ESSAYS" nil` reads the
  file-level drawer and `org-before-first-heading-p` is t. `org-entry-properties
  nil 'standard` returns reserved `IW_AFTER_ESSAYS` as well, so we must
  classify it ourselves.
- **T2-4 ✓** With inherit `nil`, `org-entry-get` does not see a parent's
  `IW_<Q>`; with inherit `t` it does. Always pass `nil`.
- **T2-5 ✓** `org-map-entries` with match `IW_ESSAYS={.}` finds headings
  but **not** the file-level entry. Document targets (SL-004) need a
  separate `point-min` read. SL-001 targets headings only.
- **T2-6 ✓** Discovery cost on `/workspace/notes` (112 `.org` files,
  1,840 headings): raw read + regex prefilter for `^[ \t]*:IW_` takes
  0.010 s. Org-mode plus full property map takes 0.589 s. Org-mode plus
  regex-targeted property reads take 0.037 s (`raw/scan-timing.out`).
  With a prefilter, rescanning on every operation is cheap, and only files
  that contain `:IW_` need Org parsing. *Caveat (RV-001 F-19):* that
  run had zero hits. Re-measured with every one of the 1,840 headings a
  member (`raw/scan2.el`, `raw/scan-timing-members.out`): 0.650 s, about
  0.33 ms per membership read, dominated by `org-entry-properties`. A
  3,000-document journal would take roughly 1 s. SL-004 must measure and
  may need a cheaper read path.
- **T2-7 ✓** `org-id-get-create` marks the buffer modified and writes to
  `org-id-locations-file` (defaulting to `~/.emacs.d/.org-id-locations`).
  Tests must bind `org-id-locations-file` to a temp file.
- **T2-8 ✓** `org-entry-put` inserts `IW_<Q>` into the heading's drawer
  after `:ID:`, creating the drawer if absent. Property names are
  case-insensitive on read (`iw_essays` finds `IW_ESSAYS`).
- **T2-9 ✓** package-lint is on the wrapped Emacs `load-path` even with
  `-Q` (store path `package-lint-20260903`). checkdoc is built in.
- **T2-10 ✓** There is no `nix` in the agent jail. The flake change that
  adds Emacs 30 cannot be built or verified here; the user has to enter the
  rebuilt shell.

- **T2-11 ✓** Emacs 30 on Linux: nixpkgs `nixos-unstable` has only
  `emacs31*` (and `emacs30-macport`). emacs-overlay provides `emacs-unstable`
  (31.1), `emacs-git` and `emacs-igc`, with no versioned 30. `nixos-26.05`
  still ships `emacs30` / `emacs30-nox` at 30.2 (checked upstream
  `pkgs/applications/editors/emacs/{default,sources}.nix` via GitHub raw).
  Route: a pinned `nixos-26.05` input used only for `emacs30-nox`, exposed
  as an `emacs-30` wrapper. This tests 30.2, not 30.1. The 30.1 floor is
  held by byte-compile and package-lint against `(emacs "30.1")`.
- **T2-12** (user, 2026-09-30) The jail currently exposes the user's
  emacsclient socket and will likely switch to exposing only the `emacs`
  binary, with agents running their own server. SL-001 must not depend on
  the user's server. Tests run under `emacs -Q --batch`.

Naming precedents: none in the repo. The ecosystem uses `org-id`-style
`-find` / `-get` verbs.

## Cross-thread findings

- **X1** ADR-001 plus T2-6 settle **PRD-001 OQ-1 for now**: rescan every
  operation with a raw-text prefilter, and use no cache. The corpus measured
  is small. SL-004 (journals) re-measures at scale, as RFC-001 schedules.
- **X2** ADR-002 plus T2-6: files that aren't visited are read with
  `insert-file-contents` into temporary buffers. That is a read, not a
  write, so it doesn't contradict "live buffer authoritative". Files that
  are visited must be read from their buffer, never from disk (REQ-006).
- **X3** ADR-003 plus T2-3/T2-4: discovery owns *all* Org reads and
  returns plain records. The core never sees markers or buffers.
- **X4** POL-001 plus T2-10: the Makefile must take `EMACS=` so the user
  can run `make test EMACS=emacs-30` once the flake provides it. For the
  agent, 30.1 compatibility is a byte-compile/package-lint claim plus
  running on 31.
- **X5** POL-001 test isolation plus T2-7: the shared fixture helper binds
  `org-id-locations-file`, `org-iw` source configuration and temporary
  directories. There is one helper (POL-002).

## Design-input deltas

- Discovery uses regex prefilter → Org read only on hits. No index (X1).
- Tests isolate the org-id locations file (X5).
- The Makefile takes `EMACS=` as a parameter. The flake gains `emacs30`
  (from the nixpkgs input) as a separate binary, verified by the user (X4).
- Rank parse and queue-ID classification happen in the core over plain
  `(name . value)` pairs (T2-3).
- Emacs 30 behaviour (T2-1) must be confirmed by a user run before close.
