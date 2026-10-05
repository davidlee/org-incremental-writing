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
