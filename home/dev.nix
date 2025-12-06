{ primaryUser, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nixd
  ];

  environment.shellInit = ''
    switchyubi() {
      rm -r ~/.gnupg/private-keys-v1.d
      gpgconf --kill gpg-agent
      gpg --card-status
      gpgconf --launch gpg-agent
    }
  '';

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

      "screenflow"

      "vibetunnel"
    ];

    masApps = {
      "Patterns - The Regex App" = 429449079;
    };
  };
  home-manager.users.${primaryUser} = {
    home = {
      shellAliases = {
        ls = "eza -Ahl --git";
        cat = "bat";
        grep = "rg";
        find = "fd";
        du = "dust";
        ps = "procs";
        top = "btm";
        htop = "btm";
        ping = "gping";

        cd = "z";

        # git
        gpull = "git pull";
        gpush = "git push";
        gfpush = "git push --force-with-lease";
        gpr = "git pull --rebase";
        gdiff = "git diff";
        gcom = "git commit";
        gca = "git commit -a";
        gcam = "git commit -am";
        gco = "git checkout";
        gbr = "git branch";
        gst = "git status";
        grm = "git status | grep deleted | awk '{print \$3}' | xargs git rm";
        gphm = "git push heroku master";
        gpsm = "git push staging master";
        gadd = "git add";

        # terraform
        tf = "terraform";

        # heroku
        hk = "heroku";

        # commands starting with % for pasting from web
        "%" = " ";
      };
    };

    programs = {
      zsh = {
        initContent = "eval $(zoxide init zsh); source ~/.config/fzf-get.sh";
        shellAliases = {
          reload = ". ~/.zshenv && . ~/.zprofile && . ~/.zshrc";
        };
      };
    };
  };
  programs = {
    gnupg.agent = {
      enable = true;
    };
    zsh = {
      enableBashCompletion = true;
      enableCompletion = true;
      enableFzfCompletion = true;
      enableFzfGit = true;
      enableFzfHistory = true;
    };
  };
}
