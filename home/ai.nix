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
      "chatgpt"
      "claude"

      "ollama-app"

      "diffusionbee"
    ];

    brews = [
    ];
  };
}
