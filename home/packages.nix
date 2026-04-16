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

      colima

      # misc
      nil
      biome
      nixfmt
      yt-dlp

      # fonts
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.droid-sans-mono
    ];
  };
}
