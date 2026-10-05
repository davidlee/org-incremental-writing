The agents flake's jail (jail.nix, bubblewrap) mounts each store path in
the closure of its runtime roots, one ro-bind per path. The roots are
listed in `/nix/store/*-jailed-claude-runtime-closure`, which is readable
inside the jail, and they are exactly the PATH entries. So an `extraPkgs`
member with no `bin/` is never a root. A `runCommand` that produces a
directory or symlink, such as SL-004's `denoteDir`, is silently not
mounted, even though a `set-env` names its store path (ISS-005; e14c071
was a no-op).

Checking from inside a jail, without nix:
- `awk '{print $5}' /proc/self/mountinfo | grep -c ^/nix/store/` counts
  the mounted store paths;
- `ls <path>` shows whether a path is present;
- the runtime-closure file lists the roots.

Don't dump `/proc/1/cmdline`: it carries API keys in `--setenv`.

Fix shape: give the path to the jail explicitly, with a closure-adding
combinator next to its `set-env`, rather than through `extraPkgs`.
