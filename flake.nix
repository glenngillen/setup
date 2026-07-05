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
      url = "github:Homebrew/brew/5.1.10";
      flake = false;
    };

    # sops (secrets management)
    sops-nix.url = "github:Mic92/sops-nix";

    # rtk (token-efficient proxy for AI coding agents)
    nix-rtk.url = "github:deepwatrcreatur/nix-rtk";
    nix-rtk.inputs.nixpkgs.follows = "nixpkgs";
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
      mkDarwinSystem = { hostname, primaryUser }: darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./darwin
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
      packages.aarch64-darwin.default = { };
    };
}
