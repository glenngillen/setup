_:
let
  user = "eliott";

  # Same tile shape nix-darwin's system.defaults.dock.persistent-apps writes,
  # which only applies to the primary user.
  dockApp = path: {
    tile-type = "file-tile";
    tile-data.file-data = {
      _CFURLString = path;
      _CFURLStringType = 0;
    };
  };
in
{
  # The account itself is created by hand (System Settings → Users & Groups,
  # type Standard) so it gets a password and a FileVault secure token. Listing
  # it here only tells nix-darwin where its home is; it isn't in
  # users.knownUsers, so nix-darwin never creates or deletes it.
  users.users.${user}.home = "/Users/${user}";

  home-manager.users.${user} = {
    home.stateVersion = "25.05";

    # `defaults import` merges keys, so anything not listed is left as he has it.
    # The Dock's app list is the exception: it's one key, so it's reset to this
    # on every rebuild (and shows up at his next login).
    targets.darwin.defaults = {
      NSGlobalDomain = {
        # Shows ".app" / ".pkg" so a download pretending to be a document stands out
        AppleShowAllExtensions = true;
        AppleInterfaceStyleSwitchesAutomatically = true;
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = true;
        AppleTemperatureUnit = "Celsius";
      };

      "com.apple.dock" = {
        show-recents = false;
        persistent-apps = map dockApp [
          "/Applications/Safari.app"
          "/System/Applications/Mail.app"
          "/System/Applications/Calendar.app"
          "/Applications/Pages.app"
          "/Applications/Keynote.app"
          "/Applications/Numbers.app"
          "/Applications/GarageBand.app"
          "/Applications/iMovie.app"
          "/Applications/Scratch 3.app"
          "/System/Applications/System Settings.app"
        ];
      };

      "com.apple.finder" = {
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXSortFoldersFirst = true;
        FXRemoveOldTrashItems = true;
      };

      "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
      # Don't open Photos every time a phone is plugged in
      "com.apple.ImageCapture".disableHotPlug = true;
    };
  };
}
