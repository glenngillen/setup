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
