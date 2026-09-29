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
      "chatgpt"
      "claude"

      "ollama-app"

      "diffusionbee"
    ];

    brews = [
    ];
  };
}
