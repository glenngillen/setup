{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      # dev tools
      curl
      wget
      vim
      tmux
      htop
      tree
      ripgrep
      gh
      zoxide

      colima

      # programming languages
      mise # node, deno, bun, rust, python, etc.

      # misc
      nil
      biome
      nixfmt-rfc-style
      yt-dlp
      ffmpeg
      ollama

      # containerisation
      colima

      # fonts
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.droid-sans-mono
    ];
  };
}
