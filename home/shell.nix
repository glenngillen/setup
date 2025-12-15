_: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      la = "ls -la";
      ".." = "cd ..";
      "nix-switch" = "sudo darwin-rebuild switch --flake ~/.config/nix";
      "rm" = "/opt/homebrew/opt/trash-cli/bin/trash";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      scan_timeout = 10;
      format = "$all";

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[✗](bold red)";
      };
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
