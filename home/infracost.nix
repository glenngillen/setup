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

    casks = [
      "slack"
      "zoom"
      "tailscale"
      "google-chrome"

      "notion"
      "notion-calendar"

      "finicky"
    ];
    brews = [
      "docker"
      "colima"
    ];
  };
}
