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
