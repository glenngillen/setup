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

    masApps = {
    };

    casks = [
      "superhuman"
      "vlc"
      "trader-workstation"
      "shortcat"
    ];
  };

}
