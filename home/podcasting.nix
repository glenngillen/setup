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
      "screenflow"
      "descript"
    ];

    brews = [
    ];

    masApps = {
      "Teleprompter: Floating Notes" = 1559566851;
    };
  };
}
