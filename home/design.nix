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
      "Pixelmator Pro" = 1289583905;
      "Red Lines Tools" = 1469400117;
    };

    brews = [
      "brotli"
      "gifsicle"
    ];

    casks = [
      "screenflow"
    ];
  };

}
