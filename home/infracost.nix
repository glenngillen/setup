{
  pkgs,
  lib,
  primaryUser,
  ...
}:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };

    global.brewfile = true;

    # Homebrew 6 refuses to load formulae from third-party taps until they're
    # trusted. `brew bundle` applies a Brewfile's `trusted:` options before it
    # loads anything, so declaring trust here keeps activation self-contained
    # (no out-of-band `brew trust` needed on a fresh machine).
    #
    # These taps live in `extraConfig` rather than `taps` because nix-darwin's
    # tap submodule only renders `clone_target`/`force_auto_update` — it has no
    # `trusted` option yet. Move them back once it does.
    extraConfig = ''
      tap "hashicorp/tap", trusted: { formulae: "terraform" }
      tap "azure/bicep", trusted: { formulae: "bicep" }
    '';

    casks = [
      "slack"
      "zoom"
      "microsoft-teams"
      "tailscale-app"
      "google-chrome"
      # "ngrok"

      "notion"
      "notion-calendar"
      "linear"
      "loom"

      "visual-studio-code"
      "devin-desktop"
      "cursor"
      "antigravity"

      "claude-code@latest"

    ];
    brews = [
      "infracost"

      "kubectl"
      "docker"

      "colima"

      "buf"

      "tilt"
      "hashicorp/tap/terraform"
      "azure/bicep/bicep"
    ];
  };

  home-manager.users.${primaryUser} =
    { pkgs, lib, ... }:
    {
      programs = {
        zsh = {
          initContent = ''
            export GOPROXY=direct
            export GOPRIVATE=github.com/infracost/*
            export GONOSUMDB=github.com/infracost/*

            function aws() {
              if [[ $1 == "login" ]]; then
                shift # Remove the 'login' argument
                command aws sso login --sso-session infracost "$@"
              else
                command aws "$@"
              fi
            }
          '';
        };
      };
      programs.git = {
        enable = true;
        settings = { };
      };
      home.activation.infra = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              awscli
              git
              kubectl
            ]
          )
        }:$PATH"
        if [ ! -d "$HOME/infra" ]; then
          git clone https://github.com/infracost/infra.git $HOME/infra
          cd $HOME/infra
          git pull
          cd $HOME/infra/dev
            aws eks update-kubeconfig --name dev --profile=infracost-dev --kubeconfig kubeconfig_dev &&
            cd ../prod &&
            aws eks update-kubeconfig --name prod --profile=infracost-prod --kubeconfig kubeconfig_prod
        fi

      '';
      home.activation.claudeInfracost = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if command -v claude >/dev/null 2>&1; then
          claude plugin marketplace add infracost/agent-skills
          claude plugin install infracost@infracost
        fi
      '';
      home.activation.ic = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              git
              openssh
              git-lfs
              go
            ]
          )
        }:$PATH"
        # Set GOBIN to a stable location that won't change with Go versions
        export GOBIN="$HOME/go/bin"
        export PATH="$GOBIN:$PATH"

        export GIT_CONFIG_KEY_0="url.'git@github.com:'.insteadOf"
        export GIT_CONFIG_VALUE_0="https://github.com"
        export GIT_CONFIG_COUNT=1
        export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa"

        export GOPROXY=direct
        export GOPRIVATE=github.com/infracost/*
        export GONOSUMDB=github.com/infracost/*

        if ! command -v ic >/dev/null 2>&1
        then
          go install github.com/infracost/ic/cmd/ic@latest
        fi
      '';
    };
}
