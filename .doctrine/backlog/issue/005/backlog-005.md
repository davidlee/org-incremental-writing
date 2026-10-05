# ISS-005: Jail's ORG_IW_DENOTE_DIR names an unmounted store path (e14c071 ineffective)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Found in the SL-004 audit (RV-013 F-5, 2026-10-06). The jail sets
`ORG_IW_DENOTE_DIR=/nix/store/h1l2f3v90hhxwxhr05kb6qzadij30gmz-org-iw-denote-dir`,
but that path is not mounted. e14c071 added `denoteDir` to `projectPkgs`
(flake.nix) so that the jail would mount it, but a jail started after the
commit still lacks it. The Denote package itself is mounted, through the
user's Emacs closure.

Effect: on emacs-30, the 14 Denote-route tests skip. The guard test
`org-iw-discovery-test-denote-dir-loads` (d65edcc) now fails the gate
instead. Workaround: set the variable by hand to
`/nix/store/xdf1df8f5jgnflk29cyxy8k61hl67gzy-emacs-denote-4.2.3/share/emacs/site-lisp/elpa/denote-4.2.3`.

Host-side check: `nix build .#jailed-claude`, then see whether the
launcher binds the denoteDir store path. jail.nix may mount only the
`bin/` of `extraPkgs`, or their closure through PATH. A fix may be to
export the Denote package's own directory (its closure is already
mounted), or to bind the path explicitly with a jail option.

## Diagnosis (2026-10-06, in-jail, no nix)

The jail mounts **full closures**, not just `bin/`: 689 per-path store
mounts. The roots are the launcher's runtime-closure list
(`…-jailed-claude-runtime-closure`, 39 entries), and that list holds exactly
the `PATH` entries: every `extraPkgs` member that has a `bin/` (`just`,
`emacs-30`, `doctrine`, the wrapped Emacs, …). `denoteDir` has no `bin/`, so
jail.nix never makes it a root and never mounts it. Adding it to
`projectPkgs` (e14c071) was therefore a no-op. The Denote package is mounted
only because it is in the wrapped Emacs closure, by coincidence.

Proposed fix: add `denoteDir`'s closure through a jail combinator next to
the `set-env` (e.g. `(add-pkg-deps [denoteDir])` in `orgIwJailOptions`;
check the combinator name in the agents flake's jail.nix), and drop it from
`projectPkgs`. That keeps the variable and its mount together, and SL-004
PHASE-01 EX-1 (located from the derivation) still holds. Verify on the host:
rebuild the jail, then `ls $ORG_IW_DENOTE_DIR/denote.el` inside it.
