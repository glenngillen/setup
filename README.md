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

## Managing Claude Code OAuth Token

The Claude Code CLI runs as a separate `_claude` user and uses an OAuth token stored in an encrypted secrets file.

### Generating a New OAuth Token

1. Visit https://claude.ai/settings/security (must be logged in with Claude Max subscription)
2. Under "Developer access", create a new OAuth token
3. Copy the token value (starts with `sk-ant-oat01-`)

### Updating the Encrypted Secret

1. Edit the plaintext secrets file temporarily:
   ```bash
   # Create/edit with your new token
   echo "CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-YOUR_TOKEN_HERE" > secrets/claude-oauth.env
   ```

2. Encrypt the file with sops:
   ```bash
   nix run nixpkgs#sops -- --encrypt --input-type dotenv --output-type dotenv secrets/claude-oauth.env > /tmp/encrypted.env
   mv /tmp/encrypted.env secrets/claude-oauth.env
   ```

3. Rebuild your configuration:
   ```bash
   nix-switch
   ```

The encrypted secret will be decrypted at runtime to `/run/secrets/CLAUDE_CODE_OAUTH_TOKEN` and made available to the `_claude` user.

### Troubleshooting

If you get "Invalid bearer token" errors:

1. Verify the decrypted secret exists and has correct permissions:
   ```bash
   ls -la /run/secrets/CLAUDE_CODE_OAUTH_TOKEN
   ```

2. Check the token value (first 60 chars):
   ```bash
   cat /run/secrets/CLAUDE_CODE_OAUTH_TOKEN | head -c 60
   ```

3. Verify you can decrypt the source file:
   ```bash
   nix run nixpkgs#sops -- --decrypt secrets/claude-oauth.env
   ```
