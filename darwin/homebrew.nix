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
      "jordanbaird-ice@beta"
      "raycast"
      "betterdisplay"

      # messaging
      "discord"
      "slack"
      "signal"
      "whatsapp"
      "zoom"

      # other
      "1password"
      "spotify"
      "tailscale-app"
      "little-snitch"
      "google-chrome"
      "licecap"
    ];
    brews = [
    ];
    taps = [
      "nikitabobko/tap"
    ];

    masApps = {
      "1Blocker - Ad Blocker" = 1365531024;
      "1Password for Safari" = 1569813296;
      "Amphetamine" = 937984704;
      "Kagi for Safari" = 1622835804;
      "Noizio" = 928871589;
      "Webcam Effects" = 1525288396;
    };
  };
}
