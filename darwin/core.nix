{
  lib,
  pkgs,
  inputs,
  self,
  primaryUser,
  ...
}:
# The minimum every host needs: nix, Homebrew and home-manager plumbing, and
# the primary (admin) user. Nothing personal lives here, so a host can build
# on this without any of the workstation apps, settings or sops secrets.
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  # nix config
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # disabled due to https://github.com/NixOS/nix/issues/7273
      # auto-optimise-store = true;
    };
    enable = false; # using determinate installer
  };

  nixpkgs.config.allowUnfree = true;

  # homebrew installation manager
  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
    enableZshIntegration = false;
  };

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
      # nix-darwin's cleanup option still emits the deprecated --cleanup flag.
      cleanup = "none";
      extraFlags = [
        "--force-cleanup"
        "--zap"
      ];
    };

    global.brewfile = true;
  };

  # home-manager config
  home-manager = {
    backupFileExtension = "backup";
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs self primaryUser;
    };
    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops
    ];
  };

  # touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;
    primaryUser = primaryUser;
  };

  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;
  };

  environment = {
    # After nix-darwin's profile paths (1000) so ~/.nix-profile and the per-user
    # profile win over Homebrew, but before /usr/bin and friends (1200). Without
    # an explicit order the tie is broken by module import order.
    systemPath = lib.mkOrder 1100 [
      "/run/current-system/sw/bin"
      "/etc/profiles/per-user/${primaryUser}/bin"
      "/opt/homebrew/bin"
    ];
    pathsToLink = [ "/Applications" ];
  };

  system.activationScripts.activateSettings.text = ''
    # Following line should allow us to avoid a logout/login cycle
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
