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

    masApps = {
      # "1Password for Safari" = 1569813296;
      "Pixelmator Pro" = 1289583905;
    };
  };

}
