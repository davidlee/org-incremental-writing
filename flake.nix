# Template: jailed LLM agents
#
# Copy into project, then:
#   1. Adjust projectPkgs for the language/toolchain
#   2. Set workspaceDeps to sibling repos the agents need to see
#   3. Tune jailEnvOptions: forward host env vars into the jail
#   4. Trim jailPkgs to the agents actually wanted
#
# Online profiles (specDev, research) auto-wrap with `op run` to inject
# API keys from 1Password. Override the ref map at mkJailedAgents time
# if your vault layout differs (see agents/README.md).
#
# If the caller already holds resolved plaintext (e.g. a long-lived
# broker with a session credential cache), set:
#   useOpEnv = false; passApiKeysFromEnv = true;
# to skip the outer `op run` wrapper while keeping the bwrap
# `--setenv VAR "$VAR"` forwarding. See agents/README.md > "Pre-resolved
# secrets" for the full rationale.
#
# Usage:
#   mv _envrc .envrc && direnv allow   # live agents: agent bumps need no lock update
#   nix develop
#   jailed-claude   # or jailed-pi, jailed-codex, jailed-gemini, ...
#   jcl             # shorthand: jailed-claude --dangerously-skip-permissions
{
  description = "Dev shell with jailed LLM agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
    agents.url = "github:davidlee/nix-config?dir=flakes/agents";
    emacs.url = "github:davidlee/nix-config?dir=flakes/emacs";
    doctrine.url = "github:davidlee/doctrine";
  };

  outputs = inputs @ {
    flake-parts,
    doctrine,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devshell.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem = {
        pkgs,
        system,
        ...
      }: let
        inherit (pkgs) lib stdenv;
        inherit (stdenv) isLinux;

        # jail.nix is Linux-only (bubblewrap). Darwin gets a plain devshell.
        jailLib =
          if isLinux
          then inputs.agents.lib.${system}.mkJailedAgents {}
          else {};

        # Unjailed agent CLIs (llm-agents builds) under short names. Linux
        # only; on Darwin fall back to nixpkgs. To get them on `pkgs`
        # directly instead, apply the overlay at the top of perSystem:
        #   _module.args.pkgs = import inputs.nixpkgs {
        #     inherit system; config.allowUnfree = true;
        #     overlays = [ (inputs.agents.lib.${system}.agentsOverlay {}) ];
        #   };
        agents = lib.optionalAttrs isLinux jailLib.agentsByName;

        # -- Customise these for the project --
        doctrine-pkg = doctrine.packages.${system}.default;
        wrappedEmacs = inputs.emacs.packages.${system}.default;

        projectPkgs = with pkgs; [
          # Toolchain + dev deps available inside every jail.
          # e.g. go, gopls, rust-bin.stable.latest.default, uv, python3, nodejs_latest
          uv
          python3
          (agents.codex or codex) # mcp server slave — llm-agents build on linux
          doctrine-pkg
          wrappedEmacs
        ];

        # Sibling repos to bind-mount (for editable deps / source inspection).
        # Each path appears at /workspace/<basename> inside the jail; a host
        # symlink like ./some-lib -> ../some-lib resolves correctly.
        workspaceDeps = [
          "/home/david/.emacs.d/"
          "/home/david/notes"
        ];

        apiKeyJailOptions = with jailLib.combinators; [
          (try-fwd-env "OPENROUTER_API_KEY")
          (try-fwd-env "DEEPSEEK_API_KEY")
        ];

        emacsclientJailOptions = with jailLib.combinators; [
          # (allow arbitrary elisp execution):
          (try-readwrite "/run/user/1000/emacs/server")
        ];

        doctrineJailOptions = with jailLib.combinators; [
          (set-env "DOCTRINE_RESERVATION_FALLBACK" "1")
        ];

        jailEnvOptions = apiKeyJailOptions ++ emacsclientJailOptions ++ doctrineJailOptions;

        # -- Agents --
        #
        # Profiles:
        #   specDev   — shared persistent home, network on, SSH push blocked, sandboxed identity
        #   research  — separate persistent home, network on, SSH push blocked, host identity
        #   offline   — separate persistent home, no network, no op env injection
        #
        # Extra per-agent knobs (all optional):
        #   exposePostgres       = true;   # bind /run/postgresql into the jail
        #   blockSshGitPush      = false;  # SSH only; HTTPS remains available
        #   apiKeys              = [ "OPENROUTER_API_KEY" ]; # narrow secrets
        #   allowSelfAsSubagent  = true;   # let agent recursively spawn itself
        #   maxSubagentDepth     = 2;      # cap recursion depth (default 1)
        #   useOpEnv             = false;  # opt out of 1Password injection
        #   passApiKeysFromEnv   = true;   # forward pre-resolved API keys from
        #                                  # the caller's env (use with
        #                                  # useOpEnv = false when a broker
        #                                  # already caches plaintext)
        jailPkgs = lib.optionalAttrs isLinux {
          jailed-pi = jailLib.makeJailedPi {
            profile = "specDev";
            allowSelfAsSubagent = true;
            maxSubagentDepth = 2;
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-pi-research = jailLib.makeJailedPi {
            name = "pi-research";
            profile = "research";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-opencode = jailLib.makeJailedOpencode {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-claude = jailLib.makeJailedClaude {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-codex = jailLib.makeJailedCodex {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-gemini = jailLib.makeJailedGemini {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          # jailed-zero = jailLib.makeJailedZerostack {
          #   profile = "specDev";
          #   extraPkgs = projectPkgs;
          #   extraOptions = jailEnvOptions;
          #   inherit workspaceDeps;
          # };
          # jailed-dirge = jailLib.makeJailedDirge {
          #   profile = "specDev";
          #   extraPkgs = projectPkgs;
          #   extraOptions = jailEnvOptions;
          #   inherit workspaceDeps;
          # };
          inherit (pkgs) bubblewrap;
        };
      in {
        packages = jailPkgs;

        devshells.default = {
          packages =
            projectPkgs
            ++ lib.optionals isLinux (lib.attrValues jailPkgs);

          commands = [
            {
              name = "jcl";
              help = "jailed-claude --dangerously-skip-permissions";
              command = "jailed-claude --dangerously-skip-permissions $@";
            }
          ];
        };
      };
    };
}
