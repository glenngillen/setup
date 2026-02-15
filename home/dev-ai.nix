{
  pkgs,
  primaryUser,
  lib,
  ...
}:
let
  codexUser = "_codex";
  codexHome = "/private/var/lib/codex";
  claudeUser = "_claude";
  claudeHome = "/private/var/lib/claude";
  gitName = "Glenn Gillen";
  gitEmail = "me@glenngillen.com";
  primaryUserHome = "/Users/${primaryUser}";

  # Shared toolchain PATH: mise shims, go bin, homebrew, and nix-darwin paths
  toolchainPath = lib.concatStringsSep ":" [
    "${primaryUserHome}/.local/share/mise/shims"
    "${primaryUserHome}/go/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/run/current-system/sw/bin"
    "/etc/profiles/per-user/${primaryUser}/bin"
  ];

  codexAsUser = pkgs.writeShellScriptBin "codex-as-codexuser" ''
    set -euo pipefail

    CWD="/tmp"
    GH_TOKEN_VALUE=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --cwd) CWD="$2"; shift 2 ;;
        --gh-token) GH_TOKEN_VALUE="$2"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
      esac
    done

    export HOME=${codexHome}
    export XDG_CONFIG_HOME=${codexHome}/.config
    export XDG_CACHE_HOME=${codexHome}/.cache
    export XDG_DATA_HOME=${codexHome}/.local/share
    export TERM="''${TERM:-xterm-ghostty}"
    export COLORTERM="''${COLORTERM:-xterm-ghostty}"
    export LANG="''${LANG:-}"
    export LC_ALL="''${LC_ALL:-}"
    export GH_TOKEN="$GH_TOKEN_VALUE"
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0="$CWD"
    export PATH="${toolchainPath}:$PATH"
    umask 0002

    if ! cd "$CWD" 2>/dev/null; then
      echo "codex: cannot access working directory: $CWD" >&2
      echo "       (check aicoders ACLs / aicoder-perms on this path)" >&2
      exit 1
    fi

    exec /opt/homebrew/bin/codex "$@"
  '';

  codexScript = pkgs.writeShellScriptBin "codex" ''
    set -euo pipefail

    CWD_REAL="$(/bin/pwd -P 2>/dev/null || /bin/pwd)"

    GH_TOKEN_VALUE="''${GH_TOKEN:-}"
    if [ -z "$GH_TOKEN_VALUE" ] && command -v gh >/dev/null 2>&1; then
      GH_TOKEN_VALUE="$(gh auth token 2>/dev/null || true)"
    fi
    exec sudo -u ${codexUser} -H \
      ${lib.getExe codexAsUser} \
      --cwd "$CWD_REAL" \
      --gh-token "$GH_TOKEN_VALUE" \
      -- "$@"
  '';

  claudeAsUser = pkgs.writeShellScriptBin "claude-as-claudeuser" ''
    set -euo pipefail

    CWD="/tmp"
    GH_TOKEN_VALUE=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --cwd) CWD="$2"; shift 2 ;;
        --gh-token) GH_TOKEN_VALUE="$2"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
      esac
    done

    export HOME=${claudeHome}
    export XDG_CONFIG_HOME=${claudeHome}/.config
    export XDG_CACHE_HOME=${claudeHome}/.cache
    export XDG_DATA_HOME=${claudeHome}/.local/share
    export TERM="''${TERM:-xterm-256color}"
    export COLORTERM="''${COLORTERM:-}"
    export LANG="''${LANG:-}"
    export LC_ALL="''${LC_ALL:-}"
    export GH_TOKEN="$GH_TOKEN_VALUE"
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0="$CWD"
    export AWS_EC2_METADATA_DISABLED=true
    export PATH="${toolchainPath}:$PATH"
    umask 0002

    if ! cd "$CWD" 2>/dev/null; then
      echo "claude: cannot access working directory: $CWD" >&2
      echo "       (check aicoders ACLs / aicoder-perms on this path)" >&2
      exit 1
    fi

    exec /opt/homebrew/bin/claude "$@"
  '';

  claudeScript = pkgs.writeShellScriptBin "claude" ''
    set -euo pipefail

    CWD_REAL="$(/bin/pwd -P 2>/dev/null || /bin/pwd)"

    GH_TOKEN_VALUE="''${GH_TOKEN:-}"
    if [ -z "$GH_TOKEN_VALUE" ] && command -v gh >/dev/null 2>&1; then
      GH_TOKEN_VALUE="$(gh auth token 2>/dev/null || true)"
    fi
    exec sudo -u ${claudeUser} -H \
      ${lib.getExe claudeAsUser} \
      --cwd "$CWD_REAL" \
      --gh-token "$GH_TOKEN_VALUE" \
      -- "$@"
  '';

  aicoderPerms = pkgs.writeShellScriptBin "aicoder-perms" ''
    set -euo pipefail

    if [ "$#" -eq 0 ]; then
      echo "usage: aicoder-perms <path> [path ...]" >&2
      exit 2
    fi

    if [ "''${EUID:-$(id -u)}" -ne 0 ]; then
      echo "aicoder-perms: please run with sudo (e.g., sudo aicoder-perms ...)" >&2
      exit 2
    fi

    GROUP="aicoders"
    INVOKER="''${SUDO_USER:-}"
    if [ -z "$INVOKER" ]; then
      echo "aicoder-perms: SUDO_USER not set; run via sudo" >&2
      exit 2
    fi
    USER_HOME="/Users/$INVOKER"

    ACL_PARENT_TRAVERSE="group:''${GROUP} allow search,readattr,readextattr,readsecurity"

    # Strong collaborative ACLs for the shared trees.
    # - directory_inherit/file_inherit ensures new children get these permissions.
    ACL_DIR_COLLAB="group:''${GROUP} allow read,write,execute,delete,add_file,add_subdirectory,file_inherit,directory_inherit"
    ACL_FILE_COLLAB="group:''${GROUP} allow read,write,execute"

    ensure_parent_acls() {
      echo "Checking parent directory ACLs..."
      local target="$1"

      local abs
      if [ -d "$target" ]; then
        abs="$(cd "$target" && pwd -P)"
      else
        abs="$(cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
      fi

      case "$abs" in
        "$USER_HOME"/*) ;;
        *) return 0 ;; # don't touch parents outside your home
      esac

      local d
      if [ -d "$abs" ]; then d="$abs"; else d="$(dirname "$abs")"; fi

      while :; do
        echo "Checking $d..."
        if ! /bin/ls -lde "$d" 2>/dev/null | /usr/bin/grep -qE "group:''${GROUP} allow .*search"; then
          /bin/chmod +a "$ACL_PARENT_TRAVERSE" "$d" || true
        fi
        [ "$d" = "$USER_HOME" ] && break
        [ "$d" = "/" ] && break
        d="$(dirname "$d")"
      done
    }

    ensure_collab_acls() {
      local root="$1"

      # Add the dir-collab ACL to the root directory (inherited by children).
      if [ -d "$root" ]; then
        if ! /bin/ls -lde "$root" 2>/dev/null | /usr/bin/grep -qE "group:''${GROUP} allow .*file_inherit"; then
          /bin/chmod +a "$ACL_DIR_COLLAB" "$root" || true
        fi
      fi

      # Ensure all subdirectories have at least the inherited directory ACL too.
      /usr/bin/find "$root" -type d -print0 | /usr/bin/xargs -0 -I{} /bin/sh -lc '
        d="$1"
        if ! /bin/ls -lde "$d" 2>/dev/null | /usr/bin/grep -qE "group:'"''${GROUP}"' allow .*file_inherit"; then
          echo "Fixing ACLs on $d"
          /bin/chmod +a "'"$ACL_DIR_COLLAB"'" "$d" || true
        fi
      ' sh {}

      # For existing files, add a non-inherited ACL so current files become editable/executable by group.
      /usr/bin/find "$root" -type f -print0 | /usr/bin/xargs -0 -I{} /bin/sh -lc '
        f="$1"
        if ! /bin/ls -le "$f" 2>/dev/null | /usr/bin/grep -qE "group:'"''${GROUP}"' allow .*read"; then
          echo "Fixing ACLs on $f"
          /bin/chmod +a "'"$ACL_FILE_COLLAB"'" "$f" || true
        fi
      ' sh {}
    }

    # Validate
    for path in "$@"; do
      if [ ! -e "$path" ]; then
        echo "aicoder-perms: path does not exist: $path" >&2
        exit 1
      fi
    done

    # Parents (so _codex/_claude can reach the tree under /Users/gg)
    for path in "$@"; do
      ensure_parent_acls "$path"
      abs="$(cd "$path" && pwd -P)"
      git config --global --add safe.directory "$abs/*x"
    done

    # Group ownership + mode bits
    echo "Updating group ownership..."
    /usr/sbin/chown -R ":''${GROUP}" "$@"
    /bin/chmod -R g+rwX "$@"

    # setgid on directories so new children inherit group
    for path in "$@"; do
      if [ -d "$path" ]; then
        echo "Setting setgid on directories..."
        /usr/bin/find . -type d \! -perm -g+s -exec /bin/chmod g+s {} +
      fi
    done

    # ACLs for collaborative access (existing + future)
    for path in "$@"; do
      if [ -d "$path" ]; then
        ensure_collab_acls "$path"
      fi
    done
  '';
in
{
  environment.systemPackages = with pkgs; [
    nixd
    codexScript
    claudeScript
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
    home = codexHome;
    createHome = true;
    isHidden = true;
    shell = null;
  };

  users.users.${claudeUser} = {
    uid = 4201;
    gid = 4210;
    description = "Restricted service user for Claude";
    home = claudeHome;
    createHome = true;
    isHidden = true;
    shell = null;
  };

  system.activationScripts.codexHome.text = ''
    mkdir -p ${codexHome}/.config ${codexHome}/.cache ${codexHome}/.local/share
    chmod 700 ${codexHome}

    # Create a login keychain for the service user so macOS doesn't show
    # "Keychain Not Found" popups. Left locked so nothing writes to it;
    # the tool falls back to file-based credential storage.
    CODEX_KC="${codexHome}/Library/Keychains/login.keychain-db"
    if [ ! -f "$CODEX_KC" ]; then
      mkdir -p "$(dirname "$CODEX_KC")"
      sudo -u ${codexUser} /usr/bin/security create-keychain -p "" "$CODEX_KC"
      sudo -u ${codexUser} /usr/bin/security default-keychain -s "$CODEX_KC"
      /usr/bin/security lock-keychain "$CODEX_KC"
    fi
  '';
  system.activationScripts.claudeHome.text = ''
    mkdir -p ${claudeHome}/.config ${claudeHome}/.cache ${claudeHome}/.local/share
    chmod 700 ${claudeHome}

    # Create a login keychain for the service user so macOS doesn't show
    # "Keychain Not Found" popups. Left locked so nothing writes to it;
    # the tool falls back to file-based credential storage.
    CLAUDE_KC="${claudeHome}/Library/Keychains/login.keychain-db"
    if [ ! -f "$CLAUDE_KC" ]; then
      mkdir -p "$(dirname "$CLAUDE_KC")"
      sudo -u ${claudeUser} /usr/bin/security create-keychain -p "" "$CLAUDE_KC"
      sudo -u ${claudeUser} /usr/bin/security default-keychain -s "$CLAUDE_KC"
      /usr/bin/security lock-keychain "$CLAUDE_KC"
    fi
  '';

  system.activationScripts.aiPermissions.text = ''
    sudo chmod +a "group:aicoders allow search,readattr,readextattr,readsecurity" /Users/${primaryUser}
    sudo chmod +a "group:aicoders allow read,execute,search" "$TMPDIR"
    sudo chmod +a "group:aicoders allow read,execute,search,file_inherit,directory_inherit" "$\{TMPDIR\}TemporaryItems"
    sudo chmod +a "group:aicoders allow search" /var/folders/

    # Grant aicoders read/execute access to mise shims and go binaries
    for d in /Users/${primaryUser}/.local \
             /Users/${primaryUser}/.local/share \
             /Users/${primaryUser}/.local/share/mise \
             /Users/${primaryUser}/.local/share/mise/shims \
             /Users/${primaryUser}/go \
             /Users/${primaryUser}/go/bin; do
      if [ -d "$d" ]; then
        chmod +a "group:aicoders allow read,execute,search,readattr,readextattr,readsecurity" "$d" 2>/dev/null || true
      fi
    done

    # Also grant access to mise installs directory (where the actual binaries live)
    if [ -d "/Users/${primaryUser}/.local/share/mise/installs" ]; then
      /usr/bin/find "/Users/${primaryUser}/.local/share/mise/installs" -type d \
        -exec chmod +a "group:aicoders allow read,execute,search,readattr,readextattr,readsecurity" {} \; 2>/dev/null || true
      /usr/bin/find "/Users/${primaryUser}/.local/share/mise/installs" -type f \
        -exec chmod +a "group:aicoders allow read,execute,readattr,readextattr,readsecurity" {} \; 2>/dev/null || true
    fi
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

      programs.zsh.initContent = ''
        # Put nix-darwin bins first (mise/brew often prepend themselves)
        path=(/run/current-system/sw/bin /etc/profiles/per-user/${primaryUser}/bin $path)

        # Remove duplicates and sync PATH correctly (colon-separated)
        typeset -U path
        export PATH="''${(j/:/)path}"

        hash -r
      '';
      programs.tmux = {
        enable = true;
      };
    };

  home-manager.users.${codexUser} = {
    home = {
      stateVersion = "25.05";
      homeDirectory = codexHome;
    };
    programs.git = {
      enable = true;
      extraConfig = {
        init.defaultBranch = "main";
        user.name = gitName;
        user.email = gitEmail;
      };
    };
    programs.tmux = {
      enable = true;
    };
  };

  home-manager.users.${claudeUser} = {
    home = {
      stateVersion = "25.05";
      homeDirectory = claudeHome;
    };
    programs.git = {
      enable = true;
      extraConfig = {
        init.defaultBranch = "main";
        user.name = gitName;
        user.email = gitEmail;
      };
    };
    programs.tmux = {
      enable = true;
    };
  };
  security.sudo.extraConfig = ''
    ${primaryUser} ALL=(${claudeUser}) NOPASSWD: ${lib.getExe claudeAsUser}
    ${primaryUser} ALL=(${codexUser}) NOPASSWD: ${lib.getExe codexAsUser}
    ${claudeUser} ALL=(${codexUser}) NOPASSWD: ALL
    ${codexUser} ALL=(${claudeUser}) NOPASSWD: ALL
  '';
}
