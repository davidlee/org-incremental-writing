The agents flake (`flakes/agents/jailed-agents.nix`) passes
`commonPkgs ++ extraPkgs ++ [agent] ++ …` to jail.nix's `add-pkg-deps`.
That combinator appends `toString pkg` to `additionalRuntimeClosures`. It
does not need a `bin/`. `bind-nix-store-runtime-closure` writes those
roots to `<name>-runtime-closure` and ro-binds every path in their closure
(`exportReferencesGraph`). So any `extraPkgs` member is mounted in full,
including a `runCommand` directory or symlink. `extraOptions` such as
`set-env` add no closure.

The roots are fixed when the jail is built. A jail still running from
before a flake change shows the old roots, even if the shell around it
was reloaded. To check which flake a jail came from, read
`/nix/store/*-jailed-<agent>-runtime-closure` inside it (it is readable)
and compare it with `extraPkgs`. For mounted store paths, run
`awk '{print $5}' /proc/self/mountinfo`. Don't dump `/proc/1/cmdline`:
it carries API keys in `--setenv`.

ISS-005: the jail had f8d72bf's `set-env` but no `denoteDir` root, so it
was built before e14c071. The fix is to rebuild it, not to change the
flake. An earlier memory claiming "PATH roots only" was wrong and is
retracted.
