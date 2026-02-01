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

    caskArgs.no_quarantine = true;
    global.brewfile = true;

    taps = [
      "hashicorp/tap"
    ];

    casks = [
      "slack"
      "zoom"
      "microsoft-teams"
      "tailscale-app"
      "google-chrome"
      "ngrok"

      "notion"
      "notion-calendar"
      "linear-linear"
      "loom"
    ];
    brews = [
      "awscli"
      "kubectl"
      "docker"

      "colima"

      "infracost"
      "tilt"
      "hashicorp/tap/terraform"
    ];
  };

  home-manager.users.${primaryUser} =
    { pkgs, lib, ... }:
    {
      programs = {
        zsh = {
          initContent = ''
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
        # ...
        extraConfig = {

        };
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
      home.activation.ic = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              mise
              git
              openssh
              git-lfs
            ]
          )
        }:$PATH"
        # Get the go binary path from mise and add it to PATH
        GO_BIN_PATH=$(mise bin-paths | grep "/go/")
        export PATH="$GO_BIN_PATH:$PATH"

        # Set GOBIN to a stable location that won't change with Go versions
        export GOBIN="$HOME/go/bin"
        export PATH="$GOBIN:$PATH"

        export GIT_CONFIG_KEY_0="url.'git@github.com:'.insteadOf"
        export GIT_CONFIG_VALUE_0="https://github.com"
        export GIT_CONFIG_COUNT=1
        export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa"

        go env -w GOPROXY=direct
        go env -w GOPRIVATE=github.com/infracost/*
        go env -w GONOSUMDB=github.com/infracost/*
        go clean -modcache

        if ! command -v ic >/dev/null 2>&1
        then
          go install github.com/infracost/ic/cmd/ic@latest
        fi
      '';
    };
}
