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

    casks = [
      "chatgpt"
      "claude"

      "ollama-app"

      "diffusionbee"
    ];

    brews = [
    ];
  };
}
