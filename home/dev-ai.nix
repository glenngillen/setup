{
  pkgs,
  primaryUser,
  lib,
  ...
}:
let
  codexUser = "_codex";
  claudeUser = "_claude";

  codexWrapper = pkgs.writeShellScriptBin "codex-brew" ''
    set -euo pipefail
    # try both common brew prefixes
    if [ -x /opt/homebrew/bin/codex ]; then
      exec /opt/homebrew/bin/codex "$@"
    elif [ -x /usr/local/bin/codex ]; then
      exec /usr/local/bin/codex "$@"
    else
      echo "codex not found in /opt/homebrew/bin or /usr/local/bin" >&2
      exit 127
    fi
  '';

  claudeWrapper = pkgs.writeShellScriptBin "claude-brew" ''
    set -euo pipefail
    # try both common brew prefixes
    if [ -x /opt/homebrew/bin/claude ]; then
      exec /opt/homebrew/bin/claude "$@"
    elif [ -x /usr/local/bin/claude ]; then
      exec /usr/local/bin/claude "$@"
    else
      echo "claude not found in /opt/homebrew/bin or /usr/local/bin" >&2
      exit 127
    fi
  '';

  aicoderPerms = pkgs.writeShellScriptBin "aicoder-perms" ''
    set -euo pipefail

    if [ "$#" -eq 0 ]; then
      echo "usage: aicoder-perms <path> [path ...]" >&2
      exit 2
    fi

    GROUP="aicoders"
    ACL_TRAVERSE="group:''${GROUP} allow search,readattr,readextattr,readsecurity"

    if [ "''${EUID:-$(id -u)}" -ne 0 ]; then
      echo "aicoder-perms: please run with sudo (e.g., sudo aicoder-perms ...)" >&2
      exit 2
    fi

    INVOKER="''${SUDO_USER:-}"
    if [ -z "$INVOKER" ]; then
      echo "aicoder-perms: SUDO_USER not set; run via sudo" >&2
      exit 2
    fi
    USER_HOME="/Users/$INVOKER"

    ensure_parent_acls() {
      local target="$1"

      local abs
      if [ -d "$target" ]; then
        abs="$(cd "$target" && pwd -P)"
      else
        abs="$(cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
      fi

      case "$abs" in
        "$USER_HOME"/*) ;;
        *)
          echo "aicoder-perms: refusing to modify parent ACLs outside $USER_HOME (got: $abs)" >&2
          return 0
          ;;
      esac

      local d
      if [ -d "$abs" ]; then
        d="$abs"
      else
        d="$(dirname "$abs")"
      fi

      while :; do
        if ! /bin/ls -lde "$d" 2>/dev/null | /usr/bin/grep -qE "group:''${GROUP} allow .*search"; then
          /bin/chmod +a "$ACL_TRAVERSE" "$d" || true
        fi

        [ "$d" = "$USER_HOME" ] && break
        [ "$d" = "/" ] && break
        d="$(dirname "$d")"
      done
    }

    for path in "$@"; do
      if [ ! -e "$path" ]; then
        echo "aicoder-perms: path does not exist: $path" >&2
        exit 1
      fi
    done

    for path in "$@"; do
      ensure_parent_acls "$path"
    done

    /usr/sbin/chown -R ":''${GROUP}" "$@"
    /bin/chmod -R g+rwX "$@"

    for path in "$@"; do
      if [ -d "$path" ]; then
        /bin/chmod g+s "$path"
        /usr/bin/find "$path" -type d -exec /bin/chmod g+s {} +
      fi
    done
  '';
in
{
  environment.systemPackages = with pkgs; [
    nixd
    claudeWrapper
    codexWrapper
    aicoderPerms
  ];

  users.knownUsers = [
    codexUser
    claudeUser
  ];

  users.knownGroups = [ "aicoders" ];
  users.groups.aicoders = {
    gid = 4210;
    members = [
      "_codex"
      "_claude"
      primaryUser
    ];
  };

  users.users.${codexUser} = {
    uid = 4200;
    gid = 4210;
    description = "Restricted service user for Codex";
    home = "/var/lib/codex";
    createHome = true;
    isHidden = true;
    shell = null;
  };

  users.users.${claudeUser} = {
    uid = 4201;
    gid = 4210;
    description = "Restricted service user for Claude";
    home = "/var/lib/claude";
    createHome = true;
    isHidden = true;
    shell = null;
  };

  system.activationScripts.codexHome.text = ''
    mkdir -p /var/lib/codex/.config /var/lib/codex/.cache /var/lib/codex/.local/share
    chmod 700 /var/lib/codex
  '';
  system.activationScripts.claudeHome.text = ''
    mkdir -p /var/lib/claude/.config /var/lib/claude/.cache /var/lib/claude/.local/share
    chmod 700 /var/lib/claude
  '';

  system.activationScripts.aiPermissions.text = ''
    sudo chmod +a "group:aicoders allow search,readattr,readextattr,readsecurity" /Users/${primaryUser}
  '';

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };

    caskArgs.no_quarantine = true;
    global.brewfile = true;

    taps = [
      "dagger/tap"
      "steveyegge/beads"
    ];

    brews = [
      "bd"
      "devcontainer"
      "opencode"
    ];

    casks = [
      "container-use"
      "claude-code"
      "codex"
    ];

    masApps = { };
  };

  home-manager.users.${primaryUser} =
    { lib, ... }:
    {
      home.file.".claude/CLAUDE.md".source = ./configs/agent.md;
      home.file.".claude/settings.json".source = ./configs/claude.settings.json;

      home.activation.container-use = lib.hm.dag.entryAfter [ "writeBoundary" "homebrew" ] ''
        PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              claude-code
            ]
          )
        }:$PATH"
        claude mcp add --scope user container-use -- container-use stdio
      '';

      programs = {
        zsh = {
          initContent = ''
            codex() {
              sudo -u _codex -H /bin/sh -lc '
                export HOME=/var/lib/codex
                export XDG_CONFIG_HOME="$HOME/.config"
                export XDG_CACHE_HOME="$HOME/.cache"
                export XDG_DATA_HOME="$HOME/.local/share"
                mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"

                /run/current-system/sw/bin/codex-brew "$@"
              ' sh "$@"
            }
            claude() {
              sudo -u _claude -H /bin/sh -lc '
                export HOME=/var/lib/claude
                export XDG_CONFIG_HOME="$HOME/.config"
                export XDG_CACHE_HOME="$HOME/.cache"
                export XDG_DATA_HOME="$HOME/.local/share"
                mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"

                /run/current-system/sw/bin/claude-brew "$@"
            ' sh "$@"
            }
          '';
        };
      };
    };

  security.sudo.extraConfig = ''
    ${primaryUser} ALL=(${claudeUser}) NOPASSWD: ${lib.getExe claudeWrapper}
    ${primaryUser} ALL=(${codexUser}) NOPASSWD: ${lib.getExe codexWrapper}
  '';
}
