# Workstation setup using Nix

Uses nix, flakes, nix-darwin, Home Manager, and Mise to setup my macOS machine(s)

## Prerequisites

* [Install Nix](https://docs.determinate.systems/#products) (download the graphical installer for macOS). After installation, restart your terminal.

## Quick Start

### Apply the Configuration

#### First-time

```bash
# Build and switch to the configuration
darwin-rebuild switch --flake .#my-macbook
```

#### Subsequent updates

# Or use the alias after initial setup

```bash
nix-switch
```
