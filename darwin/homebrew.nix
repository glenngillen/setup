{ ... }:
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
    casks = [

      # OS enhancements
      "aerospace"
      "cleanshot"
      "hiddenbar"
      "raycast"
      "betterdisplay"

      # dev
      "cursor"
      "ghostty"
      "visual-studio-code"
      "zed"

      # messaging
      "discord"
      "slack"
      "signal"
      "whatsapp"
      "zoom"

      # other
      "1password"
      "spotify"
      "tailscale"
      "lulu"
      "google-chrome"
    ];
    brews = [
      "docker"
      "colima"
    ];
    taps = [
      "nikitabobko/tap"
    ];
  };
}
