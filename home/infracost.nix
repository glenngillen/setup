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
      "docker"
      "colima"
    ];
  };

  home-manager.users.${primaryUser} =
    { pkgs, lib, ... }:
    {
      programs.git = {
        enable = true;
        # ...
        extraConfig = {

        };
      };
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
