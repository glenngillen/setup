{ primaryUser, ... }:
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
    };
  };

}
