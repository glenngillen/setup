{ pkgs, lib, ... }:
{
  programs.mise = {
    enable = false;
  };

  home.extraActivationPath = with pkgs; [
    curl
  ];

  # activation script to set up mise configuration
  home.activation.setupMise = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    MISE="/opt/homebrew/bin/mise"
    if [ -x "$MISE" ]; then
      # enable corepack (pnpm, yarn, etc.)
      "$MISE" set MISE_NODE_COREPACK=true

      # disable warning about */.node-version files
      "$MISE" settings add idiomatic_version_file_enable_tools "[]"

      # set global tool versions (auto_install will handle installation)
      "$MISE" use --global node@lts
      "$MISE" use --global bun@latest
      "$MISE" use --global uv@latest
    fi
  '';
}
