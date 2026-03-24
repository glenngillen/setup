{ primaryUser, ... }:
{
  programs.git = {
    enable = true;

    lfs.enable = true;

    ignores = [ "**/.DS_STORE" ];

    settings = {
      user.name = "Glenn Gillen";
      user.email = "github@gln.io";
      github = {
        user = primaryUser;
      };
      init = {
        defaultBranch = "main";
      };
    };
  };

}
