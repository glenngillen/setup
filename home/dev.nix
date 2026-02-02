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
          system = prev.system;
          config = prev.config;
        };
        pkgsZed = import inputs.nixpkgs-zed {
          system = prev.system;
          config = prev.config;
        };
      in
      {
        go = pkgsGo.go;
        zed-editor = pkgsZed.zed-editor;
      }
    )
  ];
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
      "git-credential-manager"

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
        pkgs.zed-editor
        pkgs.go
      ];

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

        zed = "zeditor";

        # commands starting with % for pasting from web
        "%" = " ";

      };

      sessionVariables = {
        EDITOR = "zeditor";
      };

      file.".config/fzf-git.sh".source = ./configs/fzf-git.sh;
      file."/Library/Application\ Support/com.mitchellh.ghostty/config".source = ./configs/ghostty.config;
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

      zed-editor = {
        enable = true;
        extensions = [
          "html"
          "toml"
          "dockerfile"
          "svelte"
          "terraform"
          "prisma"
          "nix"
          "opencode"
          "docker-compose"
          "catppuccin"
          "catppuccin-icons"
          "git-firefly"
        ];
        userSettings = {
          vim_mode = true;
          buffer_font_family = "FiraCode Nerd Font Mono";
          ui_font_size = 16;
          buffer_font_size = 15;
          active_pane_modifiers = {
            border_size = 0.0;
            inactive_opacity = 0.5;
          };
          bottom_dock_layout = "full";
          auto_indent = true;
          auto_indent_on_paste = true;
          auto_install_extensions = {
            html = true;
            dockerfile = true;
            docker-compose = true;
            toml = true;
            svelte = true;
            terraform = true;
            prisma = true;
            nix = true;
            catppuccin = true;
            catppuccin-icons = true;
            opencode = true;
            git-firefly = true;
          };
          theme = {
            mode = "system";
            light = "Catppuccin Latte";
            dark = "Catppuccin Mocha";
          };
          icon_theme = {
            mode = "system";
            dark = "Catppuccin Mocha";
            light = "Catppuccin Latte";
          };
          autosave = "off";
          auto_signature_help = true;
          close_on_file_delete = true;
          confirm_quit = true;
          current_line_highlight = "all";
          selection_highlight = true;
          hide_mouse = "on_typing_and_movement";
          scrollbar = {
            show = "auto";
            cursors = true;
            git_diff = true;
            search_results = true;
            selected_text = true;
            selected_symbol = true;
            diagnostics = "all";
            axes = {
              horizontal = true;
              vertical = true;
            };
          };
          tabs = {
            close_position = "right";
            file_icons = true;
            git_status = true;
            activate_on_close = "history";
            show_close_button = "hover";
            show_diagnostics = "off";
          };
          enable_language_server = true;
          format_on_save = "on";
          use_autoclose = true;
          hard_tabs = false;
          remove_trailing_whitespace_on_save = true;
          restore_on_file_reopen = true;
          restore_on_startup = "last_session";
        };
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
