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

    casks = [
      "slack"
      "zoom"
      "microsoft-teams"
      "tailscale-app"
      "google-chrome"

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
        git clone https://github.com/infracost/infra.git $HOME/infra
        cd $HOME/infra/dev &&
          aws eks update-kubeconfig --name dev --profile=infracost-dev --kubeconfig kubeconfig_dev &&
          cd ../prod &&
          aws eks update-kubeconfig --name prod --profile=infracost-prod --kubeconfig kubeconfig_prod &&

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
        GOPATH=$(mise bin-paths | grep "/go/")
        PATH="$GOPATH:$PATH"
        GIT_CONFIG_KEY_0="url.'git@github.com:'.insteadOf"
        GIT_CONFIG_VALUE_0="https://github.com"
        GIT_CONFIG_COUNT=1
        go env -w GOPROXY=direct
        go env -w GOPRIVATE=github.com/infracost/*
        go env -w GONOSUMDB=github.com/infracost/*
        go clean -modcache
        GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa"
        if ! command -v ic >/dev/null 2>&1
        then
          go install github.com/infracost/ic/cmd/ic@latest
        fi
      '';
    };
}
