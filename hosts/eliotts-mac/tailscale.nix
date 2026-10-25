{
  lib,
  pkgs,
  primaryUser,
  ...
}:
# Tailscale, locked on. The policies are delivered as a configuration profile
# because that's the only place macOS lets an admin set preferences a standard
# user can't override (and removing the profile needs an admin password).
# macOS no longer installs profiles silently, so nix only builds the file; it's
# approved once by hand (see README).
#
# Keys: https://tailscale.com/kb/1315/mdm-keys. The tailscale-app cask is the
# standalone build, which reads the io.tailscale.ipn.macsys domain.
#
# DNS is left alone: the tailnet has no global nameservers, so Tailscale falls
# back to the system resolvers (Cloudflare for Families, configuration.nix).
# Adding global nameservers with "Override local DNS" in the admin console would
# route this machine around that filter.
let
  domain = "io.tailscale.ipn.macsys";

  policies = {
    # can't disconnect or quit
    "AlwaysOn.Enabled" = true;
    TailscaleStartOnLogin = true;
    StartOnLoginMenuItem = "hide";
    # only our tailnet, so it can't be pointed at someone else's exit node
    Tailnet = "required:glenngillen.com";
    # this laptop is never an exit node for anyone else
    AdvertiseExitNode = "never";
    RunExitNode = "hide";
    ApplyUpdates = "always";
    ResetToDefaults = "hide";
    VPNOnDemandSettings = "hide";
    TestMenu = "hide";
    CLIIntegration = "hide";
    ManageTailnetLock = "hide";
  };

  profile = {
    PayloadType = "Configuration";
    PayloadVersion = 1;
    PayloadScope = "System";
    PayloadIdentifier = "com.glenngillen.eliotts-mac.tailscale";
    PayloadUUID = "B27353D7-1799-40FB-AE02-F2AF1414F31F";
    PayloadDisplayName = "Tailscale (Eliott's Mac)";
    PayloadDescription = "Keeps Tailscale connected to the family tailnet.";
    PayloadOrganization = "Gillen family";
    PayloadContent = [
      (
        {
          PayloadType = domain;
          PayloadVersion = 1;
          PayloadIdentifier = "com.glenngillen.eliotts-mac.tailscale.policies";
          PayloadUUID = "22DF7D66-D6B7-48F5-8D20-0212AECF1212";
          PayloadDisplayName = "Tailscale policies";
        }
        // policies
      )
    ];
  };

  mobileconfig = pkgs.writeText "eliotts-mac-tailscale.mobileconfig" (
    lib.generators.toPlist { escape = true; } profile
  );
in
{
  homebrew.casks = [ "tailscale-app" ];

  # In the admin account so it's there to double-click when setting up.
  home-manager.users.${primaryUser}.home.file."Profiles/eliotts-mac-tailscale.mobileconfig".source =
    mobileconfig;
}
