# Nix macOS Starter

A beginner-friendly Nix configuration for macOS using flakes, nix-darwin, Home Manager, and Mise.

## About

A clean, well-documented starting point for managing your macOS system declaratively with Nix. Includes sensible defaults for development tools, shell configuration, and system settings.

**Author:** Ben Gubler

## Prerequisites

1. **Install Nix** using the [Determinate Systems installer](https://docs.determinate.systems/#products) (download the graphical installer for macOS). After installation, restart your terminal.

**Note:** Homebrew is managed declaratively via nix-homebrew - if you already have it installed, it will auto-migrate. Otherwise, it's installed automatically.

## Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/nebrelbug/nix-macos-starter ~/.config/nix
cd ~/.config/nix
```

### 2. Customize Your Configuration

**For Intel Mac Users:** Change the system architecture in `flake.nix` from `"aarch64-darwin"` to `"x86_64-darwin"` on line 28.

**Replace all placeholders:**

- `flake.nix`: `YOUR_USERNAME` (this sets the username for the entire system)
- `home/git.nix`: `YOUR_NAME`, `YOUR_EMAIL`

### 3. Apply the Configuration

```bash
# Build and switch to the configuration
darwin-rebuild switch --flake .#my-macbook

# Or use the alias after initial setup
nix-switch
```

## What's Included

**Development Tools**: [mise](https://mise.jdx.dev/) for Node.js/Python/Rust/etc., Zsh with Starship prompt, essential CLI tools (curl, vim, tmux, htop, tree, ripgrep, gh, zoxide), code quality tools (nil, biome, nixfmt-rfc-style)

**GUI Applications**: Cursor, Ghostty, VS Code, Zed, Raycast, CleanShot, HiddenBar, BetterDisplay, Discord, Slack, 1Password, Brave Browser, Obsidian, Spotify

**System Configuration**: Git setup, macOS optimizations (Finder, Touch ID sudo), Nix settings (flakes, garbage collection), declarative Homebrew management

## Project Structure

```
nix-macos-starter/
├── flake.nix                    # Main flake configuration and inputs
├── darwin/
│   ├── default.nix              # Core macOS system configuration
│   ├── settings.nix             # macOS UI/UX preferences and defaults
│   └── homebrew.nix             # GUI applications via Homebrew
├── home/
│   ├── default.nix              # Home Manager configuration entry point
│   ├── packages.nix             # Package declarations and mise setup
│   ├── git.nix                  # Git configuration
│   ├── shell.nix                # Shell configuration
│   └── mise.nix                 # Development runtime management
└── hosts/
    └── my-macbook/
        ├── configuration.nix    # Host-specific packages and settings
        └── shell-functions.sh   # Custom shell scripts
```

## Customization

**Add CLI Tools**: Edit `home/packages.nix` packages array  
**Add GUI Apps**: Edit `darwin/homebrew.nix` casks array  
**Add Development Tools**: Add `${pkgs.mise}/bin/mise use --global tool@version` to `home/mise.nix` activation script  
**Host-Specific Config**: Use `hosts/my-macbook/configuration.nix` for machine-specific packages/apps and `custom-scripts.sh` for shell scripts

## Troubleshooting

**"Command not found"**: Restart terminal  
**Permission denied**: Use `sudo darwin-rebuild switch --flake .#my-macbook`  
**Homebrew apps not installing**: nix-homebrew handles this automatically; ensure `/opt/homebrew/bin` in PATH  
**Git config not applying**: Replace all `YOUR_*` placeholders, re-run darwin-rebuild

**Need help?** Check [Nix manual](https://nixos.org/manual/nix/stable/), [nix-darwin docs](https://github.com/LnL7/nix-darwin), [Home Manager options](https://nix-community.github.io/home-manager/options.html)

## Credits

- [Ethan Niser](https://github.com/ethanniser) for his [config repo](https://github.com/ethanniser/config) which I used as a reference for this project.
- David Haupt's excellent [tutorial series](https://davi.sh/blog/2024/01/nix-darwin/) which (although slightly outdated) helped me understand the basics of Nix.
