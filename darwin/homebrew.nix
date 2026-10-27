{ primaryUser, ... }:
{
  homebrew = {
    # homebrew is best for GUI apps
    # nixpkgs is best for CLI tools

    # Homebrew 6 refuses to load casks from third-party taps until they're
    # trusted, and `brew cleanup` (run during activation) loads every installed
    # cask — so without this the rebuild fails at cleanup even after the cask
    # installs. `brew bundle` applies `trusted:` before loading, keeping
    # activation self-contained (no out-of-band `brew trust` needed on a fresh
    # machine). Lives in extraConfig because nix-darwin's tap submodule has no
    # `trusted` option yet. See the same pattern in home/infracost.nix.
    extraConfig = ''
      tap "nikitabobko/tap", trusted: { casks: "aerospace" }
    '';
    casks = [

      # OS enhancements
      "cleanshot"
      "jordanbaird-ice@beta"
      "raycast"
      "betterdisplay"
      "aerospace" # tiling window manager (config deployed below)

      # messaging
      "discord"
      "slack"
      "signal"
      "whatsapp"
      "zoom"

      # other
      "1password"
      "spotify"
      "tailscale-app"
      "little-snitch"
      "google-chrome"
      "licecap"

      # security
      "yubico-authenticator"

    ];
    brews = [
      "mas"

      # security
      "gnupg"
      "ykman"
      "pinentry-mac"
      "age"
    ];
    masApps = {
      "1Blocker - Ad Blocker" = 1365531024;
      "1Password for Safari" = 1569813296;
      "Amphetamine" = 937984704;
      "Kagi for Safari" = 1622835804;
      "Noizio" = 928871589;
    };
  };
  home-manager.users.${primaryUser} = {
    home.file.".config/aerospace/aerospace.toml".source = ../home/configs/aerospace.config.toml;
    home.file.".config/aerospace/aerospace-workspace-change.sh" = {
      source = ../home/configs/aerospace-workspace-change.sh;
      executable = true;
    };
  };
}
