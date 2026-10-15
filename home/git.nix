{ config, primaryUser, ... }:
{
  programs.git = {
    enable = true;

    lfs.enable = true;

    ignores = [
      "**/.DS_STORE"
      ".worktrees"
      ".vscode"
      ".claude"
      ".codex"

    ];

    settings = {
      user.name = "Glenn Gillen";
      user.email = "github@gln.io";
      github = {
        user = primaryUser;
      };
      init = {
        defaultBranch = "main";
      };
      core = {
        editor = "zed --wait";
      };
      # Projects are owned by _synapseagent (group aicoders), so git's
      # ownership check rejects them. A trailing /* trusts everything below.
      # ~/Development is a symlink to /Volumes/Development; list both since
      # the check can see either form depending on how the path was reached.
      safe.directory = [
        "${config.home.homeDirectory}/Development/*"
        "/Volumes/Development/*"
      ];
    };
  };

}
