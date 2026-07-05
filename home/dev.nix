{
  primaryUser,
  pkgs,
  inputs,
  ...
}:
{
  nixpkgs.overlays = [
    (
      final: prev:
      let
        pkgsGo = import inputs.nixpkgs-go {
          system = prev.stdenv.hostPlatform.system;
          config = prev.config;
        };
      in
      {
        go = pkgsGo.go;
      }
    )
  ];
  environment.systemPackages = with pkgs; [
    nixd
    awscli2
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

    global.brewfile = true;

    # homebrew is best for GUI apps
    # nixpkgs is best for CLI tools
    brews = [
      "aws-shell"
      "direnv"
      "bandwhich"
      "bat" # cat replacement
      "bottom" # top/htop replacement
      "colima"
      "coreutils"
      "difftastic"
      "docker"
      "docker-compose"
      "dust" # du replacement
      "eza" # ls replacement
      "fd" # find replacement
      "gh"
      "ghi"
      "git-lfs"
      "gpg"
      "gping" # ping replacement
      "heroku"
      "pinentry"
      "pinentry-mac"
      "procs" # ps replacement
      "sqlite"
      "starship"
      "xh" # curl alternative
    ];

    casks = [
      "ghostty"
      "zed"

      "screenflow"

      "vibetunnel"
    ];

    masApps = {
      "Patterns" = 429449079;
    };
  };
  home-manager.users.${primaryUser} = {
    home = {

      packages = [
        pkgs.go
      ];

      shellAliases = {
        ls = "eza -Ahl --git";
        cat = "bat";
        grep = "rg";
        find = "fd";
        du = "dust";
        ps = "procs";
        top = "btop";
        htop = "btop";
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

        zed = "zeditor";

        # commands starting with % for pasting from web
        "%" = " ";

      };

      sessionVariables = {
        EDITOR = "zeditor";
      };

      file.".config/fzf-git.sh".source = ./configs/fzf-git.sh;
      file."/Library/Application\ Support/com.mitchellh.ghostty/config".source = ./configs/ghostty.config;
      file.".config/zed/settings.json".source = ./configs/zed-settings.json;
    };

    programs = {
      zsh = {
        enable = true;
        initContent = "eval $(zoxide init zsh); source ~/.config/fzf-git.sh";
        shellAliases = {
          reload = ". ~/.zshenv && . ~/.zshrc";
        };
      };
      go.enable = true;
      ripgrep = {
        enable = true;
      };

    };
  };
  programs = {
    gnupg.agent = {
      enable = true;
    };
    zsh = {
      enable = true;
      enableBashCompletion = true;
      enableCompletion = true;
      enableFzfCompletion = true;
      enableFzfGit = true;
      enableFzfHistory = true;
    };

  };
}
