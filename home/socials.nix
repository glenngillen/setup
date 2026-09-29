{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
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
