_: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # direnv's zsh hook comes from programs.direnv.enableZshIntegration.
    initContent = ''
      source ~/.config/nix/home/configs/setup.sh
    '';

    shellAliases = {
      la = "ls -la";
      ".." = "cd ..";
      # legacy alias - use 'setup sync' instead
      "nix-switch" = "setup sync";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      scan_timeout = 30;
      format = builtins.concatStringsSep "" [
        "$directory"
        "$git_branch"
        "$git_status"
        "$git_metrics"
        "$cmd_duration"
        "$line_break"
        # languages / tools
        "$nix_shell"
        "$golang"
        "$nodejs"
        "$python"
        "$terraform"
        "$rust"
        "$ruby"
        "$swift"
        "$docker_context"
        "$aws"
        "$character"
      ];

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[✗](bold red)";
      };

      # Starship only shells out for a version when the module's format
      # references $version. Omitting it skips the subprocess entirely, which
      # keeps the prompt off the 500ms command_timeout: cold, `rustc --version`
      # takes 1.3s here (it's a bash wrapper) and `node --version` 0.4s.
      golang.format = "[ $symbol]($style)";
      nodejs.format = "[ $symbol]($style)";
      ruby.format = "[ $symbol]($style)";
      rust.format = "[ $symbol]($style)";
      swift.format = "[ $symbol]($style)";
      # $virtualenv comes from the environment, not a subprocess, so it stays.
      python.format = "[ $symbol(\\($virtualenv\\) )]($style)";
      cmd_duration = {
        format = "[  $duration ]($style)";
        style = "fg:bright-white bg:18";
      };
      directory = {
        format = "[  $path ]($style)";
        style = "fg:#E4E4E4 bg:#3B76F0";
      };
      git_branch = {
        format = "[ $symbol$branch(:$remote_branch) ]($style)";
        symbol = "  ";
        style = "fg:#1C3A5E bg:#FCF392";
      };
      git_status = {
        format = "[$all_status]($style)";
        style = "fg:#1C3A5E bg:#FCF392";
      };
      git_metrics = {
        format = "([+$added]($added_style))[]($added_style)";
        added_style = "fg:#1C3A5E bg:#FCF392";
        deleted_style = "fg:bright-red bg:235";
        disabled = false;
      };
      directory = {
        "substitutions" = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = " ";
          "Pictures" = " ";
          "Development" = "󱃖 ";
        };
      };
    };
  };
}
