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
      # ~/Development is a symlink to /Volumes/Development; git real_path()s
      # both the entry and the repo, so this form also covers /Volumes paths.
      safe.directory = map (d: "${config.home.homeDirectory}/Development/${d}/*") [
        "infracost"
        "personal"
        "liquid"
      ];
    };
  };

}
