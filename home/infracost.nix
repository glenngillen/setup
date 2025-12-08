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
            ]
          )
        }:$PATH"
        GOPATH=$(mise bin-paths | grep "/go/")
        PATH="$GOPATH:$PATH"
        GOPRIVATE=github.com/infracost/ic
        go install github.com/infracost/ic/cmd/ic@latest && ic update
      '';
    };
}
