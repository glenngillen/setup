{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
    };

    global.brewfile = true;

    masApps = {
    };

    casks = [
      "superhuman"
      "vlc"
      "trader-workstation"
      "shortcat"
      "temurin"
    ];
  };

}
