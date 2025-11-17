{ primaryUser, ... }:
{
  programs.git = {
    enable = true;
    userName = "Glenn Gillen";
    userEmail = "github@gln.io";

    lfs.enable = true;

    ignores = [ "**/.DS_STORE" ];

    extraConfig = {
      github = {
        user = primaryUser;
      };
      init = {
        defaultBranch = "main";
      };
    };
  };
}
