{
  primaryUser,
  ...
}:
# Personal workstation: the shared core plus my apps, macOS preferences and
# home-manager setup (which needs the sops age key to build).
{
  imports = [
    ./core.nix
    ./homebrew.nix
    ./settings.nix
  ];

  home-manager.users.${primaryUser} = {
    imports = [
      ../home
    ];
  };
}
