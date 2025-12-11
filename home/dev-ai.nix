{ pkgs, primaryUser, ... }:
{
  environment.systemPackages = with pkgs; [
    nixd
  ];

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
      "dagger/tap"
      "steveyegge/beads"
    ];

    brews = [
      "bd"
    ];

    casks = [
      "container-use"
      "claude-code"
    ];

    masApps = {
    };
  };

  home-manager.users.${primaryUser} =
    { lib, ... }:
    {
      home.file.".claude/CLAUDE.md".source = ./configs/agent.md;
      home.file.".claude/settings.json".source = ./configs/claude.settings.json;

      home.activation.container-use = lib.hm.dag.entryAfter [ "writeBoundary" "homebrew" ] ''
        PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              claude-code
            ]
          )
        }:$PATH"
        claude mcp add --scope user container-use -- container-use stdio
      '';
    };

}
