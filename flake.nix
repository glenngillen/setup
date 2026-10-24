{
  description = "My system configuration";
  inputs = {
    # monorepo w/ recipes ("derivations")
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # pinned package sources for overlays
    nixpkgs-go.url = "github:nixos/nixpkgs/a1bab9e494f5f4939442a57a58d0449a109593fe";

    # manages configs
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # system-level software and settings (macOS)
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # declarative homebrew management
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-homebrew.inputs.brew-src.follows = "brew-src";
    brew-src = {
      url = "github:Homebrew/brew/7.0.4";
      flake = false;
    };

    # sops (secrets management)
    sops-nix.url = "github:Mic92/sops-nix";

  };

  outputs =
    {
      self,
      darwin,
      nixpkgs,
      home-manager,
      nix-homebrew,
      sops-nix,
      ...
    }@inputs:
    let
      mkDarwinSystem =
        {
          hostname,
          primaryUser,
          # ./darwin is my personal workstation; ./darwin/core.nix is the bare
          # minimum for machines that aren't mine (no apps, prefs or secrets).
          base ? ./darwin,
        }:
        darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            base
            ./hosts/${hostname}/configuration.nix
            sops-nix.darwinModules.sops
          ];
          specialArgs = { inherit inputs self primaryUser; };
        };
    in
    {
      # build darwin flake using:
      # $ nix run nix-darwin -- switch --flake .#<name>  (first time)
      # $ darwin-rebuild switch --flake .#<name>        (subsequent)
      darwinConfigurations."calculon" = mkDarwinSystem {
        hostname = "calculon";
        primaryUser = "gg";
      };
      darwinConfigurations."scruffy" = mkDarwinSystem {
        hostname = "scruffy";
        primaryUser = "glenn";
      };
      # Eliott's laptop. primaryUser is my admin account on it, which owns
      # nix/Homebrew and runs rebuilds; Eliott's own account is a standard one.
      darwinConfigurations."eliotts-mac" = mkDarwinSystem {
        hostname = "eliotts-mac";
        primaryUser = "glenn";
        base = ./darwin/core.nix;
      };
      packages.aarch64-darwin.default = { };
    };
}
