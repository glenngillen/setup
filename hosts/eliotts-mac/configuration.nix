{
  primaryUser,
  ...
}:
# Eliott's laptop. Built on darwin/core.nix, not my workstation config.
#
# Two accounts: mine (primaryUser, admin), which owns nix/Homebrew and runs
# rebuilds, and Eliott's (standard). Everything that matters for keeping the
# machine safe is set system-wide here, so it can only be changed with an
# admin password. Screen Time does the rest; it's configured from my phone
# through Family Sharing, not from nix. See README.md for the setup steps.
{
  imports = [
    ./eliott.nix
    ./tailscale.nix
  ];

  networking.hostName = "eliotts-mac";
  networking.localHostName = "eliotts-mac";
  networking.computerName = "Eliott's Mac";

  # Cloudflare for Families: blocks malware and adult content at DNS. Standard
  # users can't change a network service's DNS servers, so this sticks. Only
  # services that exist get set; the rest are for whatever adapter shows up.
  networking.knownNetworkServices = [
    "Wi-Fi"
    "USB 10/100/1000 LAN"
    "Thunderbolt Ethernet"
  ];
  networking.dns = [
    "1.1.1.3"
    "1.0.0.3"
    "2606:4700:4700::1113"
    "2606:4700:4700::1003"
  ];

  networking.applicationFirewall = {
    enable = true;
    enableStealthMode = true;
    allowSigned = true;
    allowSignedApp = true;
  };

  power.sleep.computer = 30;
  power.sleep.display = 10;

  system.startup.chime = false;

  system.defaults = {
    loginwindow = {
      autoLoginUser = null;
      GuestEnabled = false;
      DisableConsoleAccess = true;
      # user list with pictures rather than name + password fields
      SHOWFULLNAME = false;
      LoginwindowText = "If found please contact +61422164266";
    };

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

    # System domains (written as root), so they apply to every account.
    CustomSystemPreferences = {
      "/Library/Preferences/com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        AutomaticDownload = true;
        CriticalUpdateInstall = true;
        ConfigDataInstall = true;
      };
      "/Library/Preferences/com.apple.commerce".AutoUpdate = true;
    };
  };

  homebrew = {
    casks = [
      "google-drive"
      "scratch"
    ];
    # Installed with whatever Apple ID is signed into the App Store on the
    # admin account; they land in /Applications for every account.
    masApps = {
      "Pages" = 409201541;
      "Numbers" = 409203825;
      "Keynote" = 409183694;
      "GarageBand" = 682658836;
      "iMovie" = 408981434;
    };
  };

  # My admin account here is just for maintenance: shell, git and the
  # `setup` helper. None of ../../home/default.nix, which needs sops secrets.
  home-manager.users.${primaryUser} = {
    imports = [
      ../../home/packages.nix
      ../../home/shell.nix
      ../../home/git.nix
    ];
    home.stateVersion = "25.05";
  };
}
