{ self, ... }:
{
  # touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # system defaults and preferences
  system = {
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;

    startup.chime = false;

    defaults = {
      ".GlobalPreferences" = {
        "com.apple.mouse.scaling" = -1.0;
      };

      controlcenter = {
        AirDrop = false;
        BatteryShowPercentage = true;
        Bluetooth = false;
        Display = false;
        FocusModes = false;
        NowPlaying = true;
        Sound = false;
      };

      dock = {
        appswitcher-all-displays = false;
        # autoHide = true;
        autohide-delay = 0.24;
        launchanim = false;
        magnification = false;
        orientation = "bottom";
        show-recents = false;
        static-only = true;
        wvous-tr-corner = 5; # screensaver
      };

      loginwindow = {
        autoLoginUser = null;
        GuestEnabled = false;
        DisableConsoleAccess = true;
        LoginwindowText = "If found please contact +61422164266";
        SHOWFULLNAME = true;
      };

      finder = {
        AppleShowAllFiles = true; # hidden files
        AppleShowAllExtensions = true; # file extensions
        _FXShowPosixPathInTitle = true; # title bar full path
        _FXSortFoldersFirst = true;
        _FXSortFoldersFirstOnDesktop = true;
        FXPreferredViewStyle = "Nlsv"; # list view
        FXRemoveOldTrashItems = true;
        ShowExternalHardDrivesOnDesktop = false;
        ShowHardDrivesOnDesktop = false;
        ShowMountedServersOnDesktop = false;
        ShowRemovableMediaOnDesktop = false;
        ShowPathbar = true; # breadcrumb nav at bottom
        ShowStatusBar = true; # file count & disk space

        # When performing a search, search the current folder by default
        FXDefaultSearchScope = "SCcf";

      };

      iCal = {
        "first day of week" = "Monday";
        "TimeZone support enabled" = true;
        CalendarSidebarShown = true;
      };

      menuExtraClock = {
        FlashDateSeparators = false;
        IsAnalog = false;
        Show24Hour = false;
        ShowAMPM = true;
        ShowDate = 1;
        ShowDayOfMonth = true;
        ShowDayOfWeek = true;
        ShowSeconds = false;
      };

      NSGlobalDomain = {
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        "com.apple.sound.beep.feedback" = 0;
        "com.apple.swipescrolldirection" = true;
        "com.apple.trackpad.enableSecondaryClick" = true;
        "com.apple.trackpad.scaling" = 2.0;
        "com.apple.trackpad.trackpadCornerClickBehavior" = 1; # clicking in the corner = right click
        _HIHideMenuBar = false;
        AppleInterfaceStyleSwitchesAutomatically = true;
        AppleMeasurementUnits = "Centimeters";
        AppleMetricUnits = 1;
        AppleScrollerPagingBehavior = true; # jump to the point on the scroll bar when clicked
        AppleTemperatureUnit = "Celsius";
        NSDocumentSaveNewDocumentsToCloud = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSWindowShouldDragOnGesture = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
      };

      screencapture = {
        include-date = true;
        location = "~/Screenshots";
        show-thumbnail = false;
        target = "file";
        type = "png";
      };

      screensaver = {
        askForPassword = true;
        askForPasswordDelay = 5;
      };

      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

      trackpad = {
        # ActuateDetents = true;
        ActuationStrength = 1;
        FirstClickThreshold = 1;
        SecondClickThreshold = 1;
        # TrackpadCornerSecondaryClick = 2; # bottom right corner
        # TrackpadMomentumScroll = true;
        # TrackpadPinch = true;
        TrackpadRightClick = true; # two-finger right click
      };

      universalaccess = {
        closeViewScrollWheelToggle = true;
        closeViewZoomFollowsFocus = true;
        reduceMotion = true;
        reduceTransparency = true;

      };

    };

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };

  system.defaults.CustomUserPreferences = {
    NSGlobalDomain = {
      # Add a context menu item for showing the Web Inspector in web views
      WebKitDeveloperExtras = true;
      NSStatusItemSelectionPadding = 6;
      NSStatusItemSpacing = 12;
    };
    "com.apple.finder" = {
    };
    "com.apple.desktopservices" = {
      # Avoid creating .DS_Store files on network or USB volumes
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };
    "com.apple.screensaver" = {
      # Require password immediately after sleep or screen saver begins
      askForPassword = 1;
      askForPasswordDelay = 0;
    };
    "com.apple.screencapture" = {
      location = "~/Desktop";
      type = "png";
    };
    "com.apple.Safari" = {
      # Privacy: don’t send search queries to Apple
      UniversalSearchEnabled = false;
      SuppressSearchSuggestions = true;
      # Press Tab to highlight each item on a web page
      WebKitTabToLinksPreferenceKey = true;
      ShowFullURLInSmartSearchField = true;
      # Prevent Safari from opening ‘safe’ files automatically after downloading
      AutoOpenSafeDownloads = false;
      ShowFavoritesBar = false;
      IncludeInternalDebugMenu = true;
      IncludeDevelopMenu = true;
      WebKitDeveloperExtrasEnabledPreferenceKey = true;
      WebContinuousSpellCheckingEnabled = true;
      WebAutomaticSpellingCorrectionEnabled = false;
      AutoFillFromAddressBook = false;
      AutoFillCreditCardData = false;
      AutoFillMiscellaneousForms = false;
      WarnAboutFraudulentWebsites = true;
      WebKitJavaEnabled = false;
      WebKitJavaScriptCanOpenWindowsAutomatically = false;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" = true;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled" = false;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled" = false;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles" = false;
      "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically" = false;
    };
    "com.apple.mail" = {
      # Disable inline attachments (just show the icons)
      DisableInlineAttachmentViewing = true;
    };
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
    };
    "com.apple.print.PrintingPrefs" = {
      # Automatically quit printer app once the print jobs complete
      "Quit When Finished" = true;
    };
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      # Check for software updates daily, not just once per week
      ScheduleFrequency = 1;
      # Download newly available updates in background
      AutomaticDownload = 1;
      # Install System data files & security updates
      CriticalUpdateInstall = 1;
    };
    "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
    # Prevent Photos from opening automatically when devices are plugged in
    "com.apple.ImageCapture".disableHotPlug = true;
    # Turn on app auto-update
    "com.apple.commerce".AutoUpdate = true;
  };
}
