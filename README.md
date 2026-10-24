# Workstation setup using Nix

Uses nix, flakes, nix-darwin, Home Manager, and Mise to setup my macOS machine(s)

## Prerequisites

- [Install Nix](https://docs.determinate.systems/#products) (download the graphical installer for macOS). After installation, restart your terminal.

## Quick Start

### Apply the Configuration

#### First-time setup

On a fresh machine, `darwin-rebuild` doesn't exist yet. Bootstrap nix-darwin with:

```bash
# Replace <hostname> with your host (e.g., calculon, scruffy)
sudo -H nix run nix-darwin -- switch --flake ".#<hostname>"
```

After the first run completes, restart your terminal to pick up the new shell configuration.

#### Subsequent updates

Use the `setup` command:

```bash
setup sync              # Apply current configuration
setup update            # Update all flake inputs + apply
setup update nixpkgs    # Update specific input + apply
setup upgrade nix       # Upgrade Determinate Nix
setup upgrade brew      # Upgrade Homebrew packages
setup status            # Show system status
setup edit              # Open config in $EDITOR
setup clean             # Garbage collect unused packages
setup clean generations # Delete old generations + gc
setup clean all         # Full cleanup + optimise store
```

Or use `darwin-rebuild` directly:

```bash
darwin-rebuild switch --flake ".#<hostname>"
```

## Eliott's Mac (`eliotts-mac`)

A family laptop built on `darwin/core.nix` only: none of my workstation apps,
preferences or sops secrets. There are two accounts: `glenn` (admin), which owns
nix/Homebrew and is the only one that runs rebuilds, and `eliott` (Standard).

What nix sets up (`hosts/eliotts-mac/`):

- Cloudflare for Families DNS (`1.1.1.3`) on Wi-Fi and wired adapters, which
  blocks malware and adult sites. A Standard account can't change it.
- Application firewall with stealth mode on, no guest account, user-list login
  window with a "please contact" message
- Automatic macOS, security and App Store updates
- Apps: Pages, Numbers, Keynote, GarageBand, iMovie, Scratch and Google Drive
- Eliott's Dock, Finder and a few safety-minded preferences (file extensions
  always shown, no personalised ads)

### First-time setup

These steps can't be done from nix, and the order matters:

1. In Setup Assistant, create the **admin** account with the short name
   `glenn`, and turn on FileVault when it offers.
2. In System Settings → Users & Groups, add **Eliott** as a **Standard** user
   with the short name `eliott`. Log in as him once so his home folder exists.
   If he has a child Apple ID in Family Sharing, sign in with it on his account.
3. Back on `glenn`, sign into the App Store. `mas` installs the App Store apps
   with this Apple ID.
4. Install Determinate Nix (see Prerequisites), clone this repo to
   `~/.config/nix`, then run:
   ```bash
   sudo -H nix run nix-darwin -- switch --flake ".#eliotts-mac"
   ```
   After that, `setup sync` from the `glenn` account works like on the other hosts.
5. Turn on Find My Mac (System Settings → Apple Account → iCloud).

### Screen Time (from your iPhone, via Family Sharing)

Screen Time does the per-app and per-hour controls. nix can't manage it, and
because it's tied to his Apple ID it follows him across devices. In Settings →
Screen Time → Eliott:

- **Downtime** and **App Limits**: whatever schedule you agree on
- **Content & Privacy Restrictions**: on
  - Store: app age rating, and require approval for purchases (Ask to Buy)
  - Web content: **Limit Adult Websites**. This applies only in Safari, so it
    complements the DNS filter rather than replacing it.
  - Account changes / passcode changes: **Don't Allow**
- Set a **Screen Time passcode** he doesn't know.
- Make sure **iCloud Private Relay** is off for his Apple ID. Safari sends DNS
  lookups through Private Relay, which skips the Cloudflare filter.

The DNS filter can still be bypassed by a VPN app, or by a browser using its own
encrypted DNS. A Standard account plus Screen Time's app restrictions is what
keeps those off the machine.

## FlakeHub Cache Authentication

This configuration uses the [Determinate Nix](https://determinate.systems) installer, which includes the FlakeHub binary cache. If you see `HTTP error 401` warnings during rebuild:

```
warning: unable to download 'https://cache.flakehub.com/nix-cache-info': HTTP error 401
```

Your FlakeHub token has expired. Re-authenticate:

```bash
determinate-nixd login
```

You can check your current auth status with:

```bash
determinate-nixd status
```

This is non-blocking — builds will fall back to building from source — but re-authenticating restores faster cached builds.

## Managing Claude Code OAuth Token

The Claude Code CLI runs as the `_synapseagent` service user and uses an OAuth token stored in an encrypted secrets file.

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

The encrypted secret will be decrypted at runtime to `/run/secrets/CLAUDE_CODE_OAUTH_TOKEN`, owned by `_synapseagent:aicoders` with mode `0440`, so both the agent user and `gg` can read it.

The `claude` wrapper also supports a second token profile, `infracost`, backed by `secrets/claude-oauth-infracost.env` — update it the same way.

### Infracost LiteLLM Gateway

`claude --as infracost` and `codex --as infracost` use the LiteLLM gateway and share
the `LITELLM_API_KEY_INFRACOST` secret in `secrets/litellm-infracost.json`.
Before applying the configuration, replace the encrypted `<YOUR KEY>` placeholder
with your gateway key:

```bash
sops secrets/litellm-infracost.json
setup sync
```

SOPS renders the key into Claude's `ANTHROPIC_CUSTOM_HEADERS` and Codex's
`model_providers.litellm.http_headers` during activation. The resulting configs
are installed with mode `0600` in `/var/synapse/agent-home/.claude-infracost/settings.json`
and `/var/synapse/agent-home/.codex-infracost/config.toml`; the plaintext key stays
out of the Nix store. The existing Claude OAuth token and Codex OpenAI login
continue to provide authentication alongside the gateway header.

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
