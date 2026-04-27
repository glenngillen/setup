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

    masApps = {
    };

    casks = [
      "superhuman"
      "vlc"
      "trader-workstation"
    ];
  };

}
