{
  pkgs,
  primaryUser,
  ...
}:
{
  imports = [
    ../../home/dev.nix
    ../../home/design.nix
    ../../home/ai.nix
    ../../home/personal.nix
    ../../home/dev-ai.nix
  ];

  networking.hostName = "scruffy";
  networking.localHostName = "scruffy";
  networking.computerName = "scruffy";

  power.sleep.computer = 60;
  power.sleep.display = 30;

  # host-specific homebrew casks
  homebrew.casks = [
    "finicky"
  ];

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    home.file.".config/finicky.ts".source = ../../home/configs/finicky.config.ts;

    programs = {
      zsh = {
        initContent = ''
          # Source shell functions
          source ${./shell-functions.sh}
        '';
      };
    };
  };
}
