{
  pkgs,
  primaryUser,
  ...
}:
{
  imports = [
    ../../home/infracost.nix
    ../../home/dev.nix
    ../../home/design.nix
    ../../home/ai.nix
  ];

  networking.hostName = "calculon";
  networking.localHostName = "calculon";
  networking.computerName = "calculon";

  power.sleep.computer = 60;
  power.sleep.display = 30;

  # host-specific homebrew casks
  homebrew.casks = [
    "finicky"
  ];

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    home.packages = with pkgs; [
      graphite-cli
    ];

    home.file.".config/finicky.ts".source = ../../home/finicky.config.ts;
    home.file.".config/aerospace/aerospace.toml".source = ../../home/aerospace.config.toml;
    home.file.".config/fzf-git.sh".source = ../../home/fzf-git.sh;
    home.file."/Library/Application\ Support/com.mitchellh.ghostty/config".source =
      ../../home/ghostty.config;
    home.file.".gitconfig".source = ../../home/configs/gitconfig.config;

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
