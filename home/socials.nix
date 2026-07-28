{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
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
