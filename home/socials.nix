{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };

    global.brewfile = true;

    casks = [
      "discord"
      "slack"
      "whatsapp"
      "signal"
    ];

    brews = [
    ];
  };
}
