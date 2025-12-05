{
  pkgs,
  primaryUser,
  ...
}:
{
   imports = [
    ../../home/infracost.nix
    ../../home/design.nix
  ];

  networking.hostName = "calculon";

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
