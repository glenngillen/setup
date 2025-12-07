{ pkgs, ... }:
{
  home = {
    fonts = with pkgs; [
      nerd-fonts.droid-sans-mono
    ];
  };
}
