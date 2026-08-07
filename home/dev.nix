{
  primaryUser,
  pkgs,
  inputs,
  ...
}:
let
  # Zed writes JSONC (trailing commas, comments) to its settings.json, which
  # jq refuses to parse, so merge with a JSON5-tolerant parser instead.
  mergeZedSettings =
    pkgs.writers.writePython3Bin "merge-zed-settings"
      {
        libraries = [ pkgs.python3Packages.json5 ];
      }
      ''
        """Merge Nix-managed Zed settings over Zed's own settings.json.

        Usage: merge-zed-settings <nix.json> <live.json>
        Writes the merged result to stdout; Nix-managed keys win.
        """
        import json
        import pathlib
        import sys

        import json5


        def merge(base, overrides):
            result = dict(base)
            for key, value in overrides.items():
                if isinstance(value, dict) and isinstance(result.get(key), dict):
                    result[key] = merge(result[key], value)
                else:
                    result[key] = value
            return result


        nix = json.loads(pathlib.Path(sys.argv[1]).read_text())
        live = json5.loads(pathlib.Path(sys.argv[2]).read_text())

        json.dump(merge(live, nix), sys.stdout, indent=2)
        sys.stdout.write("\n")
      '';

  # nixpkgs' ruby lives read-only in the store, so a bare `gem install` tries to
  # write into /nix/store and fails. Point GEM_HOME somewhere writable instead,
  # scoped by Ruby version so gems don't collide across upgrades. Bundler and
  # rubygems ship with the interpreter, so nothing needs installing to bootstrap.
  # `version.libDir` is the gem ABI directory ("3.4.0"), which is what rubygems
  # would have appended itself had GEM_HOME been left alone.
  rubyGemHome = "$HOME/.gem/ruby/${pkgs.ruby_3_4.version.libDir}";

  # GEM_HOME/bin has to sit ahead of /run/current-system/sw/bin so the Bundler we
  # install there wins over the interpreter's mismatched copy -- but that also
  # puts it ahead of /opt/homebrew/bin, so anything installed into it shadows
  # Homebrew. There is no ordering that satisfies both. Keep application
  # dependencies out of that directory entirely instead: `bundle install` writes
  # here (off PATH, reached via `bundle exec`), while `gem install` still goes to
  # GEM_HOME for tools deliberately wanted on PATH. Bundler appends its own
  # ruby/<abi>/ underneath, so this needs no version scoping.
  rubyBundlePath = "$HOME/.gem/bundle";
in
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
      # direnv now comes from home-manager's programs.direnv (with nix-direnv)
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
      "zig@0.15"
      "xcodegen"
      "libpq"
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
  home-manager.users.${primaryUser} =
    { lib, ... }:
    {
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

          # commands starting with % for pasting from web
          "%" = " ";

        };

        sessionVariables = {
          EDITOR = "zed --wait";
          GEM_HOME = rubyGemHome;
          BUNDLE_PATH = rubyBundlePath;
        };

        sessionPath = [ "${rubyGemHome}/bin" ];

        file.".config/fzf-git.sh".source = ./configs/fzf-git.sh;
        file."/Library/Application\ Support/com.mitchellh.ghostty/config".source = ./configs/ghostty.config;
      };

      # nixpkgs replaces the interpreter's bundled RubyGems with its own (see
      # `postUnpack` in pkgs/development/interpreters/ruby) but leaves Ruby's
      # Bundler in place, so the two arrive mismatched. A Bundler older than its
      # RubyGems re-defines Gem::Platform constants that RubyGems already
      # defines, and every `bundle` invocation prints a wall of "already
      # initialized constant" warnings.
      #
      # RubyGems 3.x and Bundler 2.x are released together and their minors move
      # in lockstep, so derive the wanted Bundler from whichever RubyGems we
      # ended up with rather than hardcoding it -- otherwise the next nixpkgs
      # RubyGems bump silently reintroduces the mismatch. GEM_HOME/bin precedes
      # the store copy on PATH, so this shadows the bundled one.
      home.activation.matchBundlerToRubygems = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${lib.makeBinPath [ pkgs.ruby_3_4 ]}:$PATH"
        export GEM_HOME="${rubyGemHome}"

        rubygems_minor="$(gem --version | cut -d. -f2)"
        want="~> 2.''${rubygems_minor}"

        if ! gem list -i bundler -v "$want" >/dev/null 2>&1; then
          $DRY_RUN_CMD gem install bundler -v "$want" --no-document
        fi
      '';

      home.activation.zedSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings_dir="$HOME/.config/zed"
        settings_file="$settings_dir/settings.json"
        settings_tmp="$settings_dir/.settings.json.tmp"

        mkdir -p "$settings_dir"
        if [ -f "$settings_file" ] && [ ! -L "$settings_file" ]; then
          # Preserve settings written by Zed while keeping Nix-managed values
          # authoritative when the same key exists in both files.
          ${mergeZedSettings}/bin/merge-zed-settings \
            ${./configs/zed-settings.json} "$settings_file" > "$settings_tmp"
        else
          cp ${./configs/zed-settings.json} "$settings_tmp"
        fi
        rm -f "$settings_file"
        install -m 0644 "$settings_tmp" "$settings_file"
        rm -f "$settings_tmp"
      '';

      programs = {
        zsh = {
          enable = true;
          initContent = ''
            export PATH="/opt/homebrew/opt/zig@0.15/bin:/opt/homebrew/opt/libpq/bin:$PATH"
            eval $(zoxide init zsh); source ~/.config/fzf-git.sh
          '';
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
