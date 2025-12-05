{ primaryUser, ... }:
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

    # homebrew is best for GUI apps
    # nixpkgs is best for CLI tools
    brews = [
      "aws-shell"
      "awscli"
      "bandwhich"
      "bat" # cat replacement
      "bottom" # top/htop replacement
      "colima"
      "difftastic"
      "docker"
      "docker-compose"
      "dust" # du replacement
      "eza" # ls replacement
      "fd" # find replacement
      "gh"
      "ghi"
      "git-lfs"
      "gping" # ping replacement
      "heroku"
      "pinentry"
      "pinentry-mac"
      "procs" # ps replacement
      "ripgrep" # grep replacement
      "sqlite"
      "starship"
      "xh" # curl alternative
      "zoxide" # cd alternative
    ];

    casks = [
      "cursor"
      "ghostty"
      "visual-studio-code"
      "zed"
    ];
  };
  home-manager.users.${primaryUser} = {
    home = {
      shellAliases = {
        ls = "eza";
        cat = "bat";
        grep = "rg";
        find = "fd";
        du = "dust";
        ps = "procs";
        top = "btm";
        htop = "btm";
        ping = "gping";

        cd = "z";
      };
    };
    programs = {
      zsh = {
        initContent = "$(zoxide init zsh)";
      };
    };
  };
}
