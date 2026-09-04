{
  pkgs,
  primaryUser,
  config,
  ...
}:
{
  imports = [
    ./packages.nix
    ./git.nix
    ./shell.nix

  ];

  home = {
    username = primaryUser;
    stateVersion = "25.05";
    sessionPath = [
      "$HOME/.local/bin"
      "/Users/${primaryUser}/Development/personal/synapse/target/debug"
    ];
    sessionVariables = {
      GOBIN = "$HOME/go/bin";
      PATH = "$HOME/go/bin:$PATH";

      # `cd` is aliased to `z` (dev.nix), so every cd runs zoxide's `z`, which
      # runs its doctor check: "is __zoxide_hook still in chpwd_functions?".
      # Zed's and Claude Code's shells replay a captured snapshot of functions,
      # aliases and exported vars rather than a full interactive startup, and a
      # plain zsh array like chpwd_functions doesn't survive that — so `z` and
      # `cd=z` come back but the hook doesn't, and the doctor cries wolf on
      # every cd. Interactive shells register it fine, so this is a false
      # positive in exactly the shells that can't ever satisfy the check.
      _ZO_DOCTOR = "0";
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
    enableZshIntegration = true;
  };
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    # Caches `use flake` evaluations and keeps the result GC-rooted, so entering
    # a project shell is instant rather than a re-evaluation each cd.
    nix-direnv.enable = true;
  };
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
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
