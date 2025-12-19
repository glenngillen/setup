{
  primaryUser,
  config,
  ...
}:
{
  imports = [
    ./packages.nix
    ./git.nix
    ./shell.nix
    ./mise.nix
  ];

  home = {
    username = primaryUser;
    stateVersion = "25.05";
    sessionVariables = {
      # shared environment variables
    };

    # create .hushlogin file to suppress login messages
    file.".hushlogin".text = "";
    file.".gitconfig".source = ./configs/gitconfig.config;

  };

  programs.fzf = {
    enable = true;
  };
  programs.zoxide = {
    enable = true;
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.ssh = {
    enable = true;
  };

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets."aws.config.infracost.ini" = {
      sopsFile = ../secrets/aws.config.infracost.ini;
      format = "ini";
      path = "${config.home.homeDirectory}/.aws/config";
    };
  };

  # # Ensure ~/.aws exists
  # home.file.".aws/.keep".text = "";

  # # Put decrypted config at ~/.aws/config
  # home.file.".aws/config".source = config.sops.secrets."aws-config-infracost".path;
}
