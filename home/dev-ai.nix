{
  pkgs,
  primaryUser,
  lib,
  config,
  ...
}:
let
  codexUser = "_codex";
  codexHome = "/private/var/lib/codex";
  synapseAgentUser = "_synapseagent";
  synapseAgentHome = "/var/synapse/agent-home";
  claudeUser = "_claude";
  claudeHome = "/private/var/lib/claude";
  gitName = "Glenn Gillen";
  gitEmail = "me@glenngillen.com";
  primaryUserHome = "/Users/${primaryUser}";

  # MCP server configuration (shared between gg and _claude)
  mcpConfig = {
    mcpServers = {
      pencil = {
        type = "stdio";
        command = "/Applications/Pencil.app/Contents/Resources/app.asar.unpacked/out/mcp-server-darwin-arm64";
        args = [
          "--app"
          "desktop"
        ];
        env = { };
      };
    };
  };

  # Shared Claude Code settings (source of truth for both gg and _claude)
  baseClaudeSettings = builtins.fromJSON (builtins.readFile ./configs/claude.settings.json);

  # _claude user gets the shared settings + LSP tool + extra plugins
  claudeSettings = baseClaudeSettings // {
    env = baseClaudeSettings.env // {
      ENABLE_LSP_TOOL = "1";
    };
    enabledPlugins = baseClaudeSettings.enabledPlugins // {
      "infracost@infracost" = true;
      "rust-analyzer-lsp@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "gopls-lsp@claude-plugins-official" = true;
      "ruby-lsp@claude-plugins-official" = true;
      "spec-language-server@synapse" = true;
      "bash-language-server@synapse" = true;
      "svelte-lsp@synapse" = true;
      "terraform-ls@synapse" = true;
      "astro-lsp@synapse" = true;
    };
    skipDangerousModePermissionPrompt = true;
  };

  # Shared toolchain PATH: prioritize nix system packages, then homebrew
  toolchainPath = lib.concatStringsSep ":" [
    "/run/current-system/sw/bin" # System packages (nodejs, cargo, etc.)
    "${primaryUserHome}/go/bin" # Go binaries
    "${primaryUserHome}/Development/personal/synapse/target/debug" # Synapse debug binaries
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/etc/profiles/per-user/${primaryUser}/bin"
  ];

  codexAsUser = pkgs.writeShellScriptBin "codex-as-codexuser" ''
    set -euo pipefail

    CWD="/tmp"
    GH_TOKEN_VALUE=""
    CARGO_TARGET_DIR_VALUE=""
    HTTPS_PROXY_VALUE=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --cwd) CWD="$2"; shift 2 ;;
        --gh-token) GH_TOKEN_VALUE="$2"; shift 2 ;;
        --cargo-target-dir) CARGO_TARGET_DIR_VALUE="$2"; shift 2 ;;
        --https-proxy) HTTPS_PROXY_VALUE="$2"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
      esac
    done

    export HOME=${synapseAgentHome}
    export XDG_CONFIG_HOME=${synapseAgentHome}/.config
    export XDG_CACHE_HOME=${synapseAgentHome}/.cache
    export XDG_DATA_HOME=${synapseAgentHome}/.local/share
    export TERM="''${TERM:-xterm-ghostty}"
    export COLORTERM="''${COLORTERM:-xterm-ghostty}"
    export LANG="''${LANG:-}"
    export LC_ALL="''${LC_ALL:-}"
    export GH_TOKEN="$GH_TOKEN_VALUE"
    export CARGO_TARGET_DIR="$CARGO_TARGET_DIR_VALUE"
    if [ -n "$HTTPS_PROXY_VALUE" ]; then
      export HTTPS_PROXY="$HTTPS_PROXY_VALUE"
    fi
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0="$CWD"
    export PATH="${synapseAgentHome}/.cargo/bin:${synapseAgentHome}/.local/bin:${toolchainPath}:$PATH"
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
    HTTPS_PROXY_ARGS=()
    if [ -n "''${HTTPS_PROXY:-}" ]; then
      HTTPS_PROXY_ARGS+=(--https-proxy "$HTTPS_PROXY")
    fi

    CODEX_ARGS=(
      ${lib.getExe codexAsUser}
      --cwd "$CWD_REAL"
      --gh-token "$GH_TOKEN_VALUE"
      --cargo-target-dir "''${CARGO_TARGET_DIR:-}"
      "''${HTTPS_PROXY_ARGS[@]}"
      -- "$@"
    )

    if [ "$(id -un)" = "${synapseAgentUser}" ]; then
      exec "''${CODEX_ARGS[@]}"
    else
      exec sudo -u ${synapseAgentUser} -H "''${CODEX_ARGS[@]}"
    fi
  '';

  claudeAsUser = pkgs.writeShellScriptBin "claude-as-claudeuser" ''
    set -euo pipefail

    CWD="/tmp"
    GH_TOKEN_VALUE=""
    TOKEN_PROFILE="default"
    CARGO_TARGET_DIR_VALUE=""
    HTTPS_PROXY_VALUE=""
    IS_DEMO_VALUE=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --cwd) CWD="$2"; shift 2 ;;
        --gh-token) GH_TOKEN_VALUE="$2"; shift 2 ;;
        --token-profile) TOKEN_PROFILE="$2"; shift 2 ;;
        --cargo-target-dir) CARGO_TARGET_DIR_VALUE="$2"; shift 2 ;;
        --https-proxy) HTTPS_PROXY_VALUE="$2"; shift 2 ;;
        --is-demo) IS_DEMO_VALUE="$2"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
      esac
    done

    export HOME=${synapseAgentHome}
    export XDG_CONFIG_HOME=${synapseAgentHome}/.config
    export XDG_CACHE_HOME=${synapseAgentHome}/.cache
    export XDG_DATA_HOME=${synapseAgentHome}/.local/share
    export TERM="''${TERM:-xterm-256color}"
    export COLORTERM="''${COLORTERM:-}"
    export LANG="''${LANG:-}"
    export LC_ALL="''${LC_ALL:-}"
    export GH_TOKEN="$GH_TOKEN_VALUE"
    export CARGO_TARGET_DIR="$CARGO_TARGET_DIR_VALUE"
    if [ -n "$HTTPS_PROXY_VALUE" ]; then
      export HTTPS_PROXY="$HTTPS_PROXY_VALUE"
    fi
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0="$CWD"
    export IS_DEMO="$IS_DEMO_VALUE"
    export AWS_EC2_METADATA_DISABLED=true
    export PATH="${synapseAgentHome}/.cargo/bin:${synapseAgentHome}/.local/bin:${toolchainPath}:$PATH"

    # Select OAuth token and config directory based on profile
    case "$TOKEN_PROFILE" in
      default)
        OAUTH_SECRET="${config.sops.secrets."CLAUDE_CODE_OAUTH_TOKEN".path}"
        ;;
      infracost)
        OAUTH_SECRET="${config.sops.secrets."CLAUDE_CODE_OAUTH_TOKEN_INFRACOST".path}"
        export CLAUDE_CONFIG_DIR="${synapseAgentHome}/.claude-infracost"
        ;;
      *)
        echo "claude: unknown token profile: $TOKEN_PROFILE" >&2
        echo "       available profiles: default, infracost" >&2
        exit 1
        ;;
    esac

    if [ -r "$OAUTH_SECRET" ]; then
      export CLAUDE_CODE_OAUTH_TOKEN="$(grep '^CLAUDE_CODE_OAUTH_TOKEN=' "$OAUTH_SECRET" | cut -d= -f2-)"
    else
      echo "claude: cannot read OAuth secret for profile '$TOKEN_PROFILE'" >&2
      exit 1
    fi

    # Pre-seed hasCompletedOnboarding in alternate config dirs to skip the login/onboarding flow
    if [ -n "''${CLAUDE_CONFIG_DIR:-}" ]; then
        mkdir -p "$CLAUDE_CONFIG_DIR"
        CLAUDE_JSON="$CLAUDE_CONFIG_DIR/.claude.json"
        if [ ! -f "$CLAUDE_JSON" ]; then
            echo '{"hasCompletedOnboarding":true}' > "$CLAUDE_JSON"
        elif ! grep -q '"hasCompletedOnboarding"' "$CLAUDE_JSON"; then
            python3 -c "
        import json, sys
        path = sys.argv[1]
        with open(path) as f:
            d = json.load(f)
        d['hasCompletedOnboarding'] = True
        with open(path, 'w') as f:
            json.dump(d, f, indent=2)
        " "$CLAUDE_JSON"
        fi
    fi

    umask 0002

    if ! cd "$CWD" 2>/dev/null; then
      echo "claude: cannot access working directory: $CWD" >&2
      echo "       (check aicoders ACLs / aicoder-perms on this path)" >&2
      exit 1
    fi

    export NODE_OPTIONS="--import ${synapseAgentHome}/.claude/synapse-interceptor.mjs"
    exec /opt/homebrew/bin/claude "$@"
  '';

  claudeScript = pkgs.writeShellScriptBin "claude" ''
    set -euo pipefail

    CWD_REAL="$(/bin/pwd -P 2>/dev/null || /bin/pwd)"

    GH_TOKEN_VALUE="''${GH_TOKEN:-}"
    if [ -z "$GH_TOKEN_VALUE" ] && command -v gh >/dev/null 2>&1; then
      GH_TOKEN_VALUE="$(gh auth token 2>/dev/null || true)"
    fi

    TOKEN_PROFILE="default"
    PASSTHROUGH_ARGS=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --as=*) TOKEN_PROFILE="''${1#--as=}"; shift ;;
        --as)   TOKEN_PROFILE="$2"; shift 2 ;;
        *)      PASSTHROUGH_ARGS+=("$1"); shift ;;
      esac
    done

    HTTPS_PROXY_ARGS=()
    if [ -n "''${HTTPS_PROXY:-}" ]; then
      HTTPS_PROXY_ARGS+=(--https-proxy "$HTTPS_PROXY")
    fi

    IS_DEMO_ARGS=(--is-demo "''${IS_DEMO:-1}")

    CLAUDE_ARGS=(
      ${lib.getExe claudeAsUser}
      --cwd "$CWD_REAL"
      --gh-token "$GH_TOKEN_VALUE"
      --token-profile "$TOKEN_PROFILE"
      --cargo-target-dir "''${CARGO_TARGET_DIR:-}"
      "''${HTTPS_PROXY_ARGS[@]}"
      "''${IS_DEMO_ARGS[@]}"
      -- "''${PASSTHROUGH_ARGS[@]}"
    )

    if [ "$(id -un)" = "${synapseAgentUser}" ]; then
      exec "''${CLAUDE_ARGS[@]}"
    else
      exec sudo -u ${synapseAgentUser} -H "''${CLAUDE_ARGS[@]}"
    fi
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

    # Full collaborative ACL string. All three variables use the same value:
    # macOS ignores inheritance flags (file_inherit/directory_inherit) on files,
    # so a single ACL string works for both files and directories.
    ACL_PARENT_TRAVERSE="group:''${GROUP} allow append,list,add_file,search,delete,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,read,write,execute,file_inherit,directory_inherit"
    ACL_DIR_COLLAB="group:''${GROUP} allow append,list,add_file,search,delete,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,read,write,execute,file_inherit,directory_inherit"
    ACL_FILE_COLLAB="group:''${GROUP} allow append,list,add_file,search,delete,add_subdirectory,delete_child,readattr,writeattr,readextattr,writeextattr,read,write,execute,file_inherit,directory_inherit"

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

      # Apply ACLs unconditionally to all items. chmod +a is idempotent —
      # macOS merges permissions into existing ACEs for the same group and
      # won't create duplicate entries. This handles both items with no ACL
      # and items with partial inherited ACLs (e.g. directories created by
      # _codex/_claude that inherit a reduced permission set).
      echo "Applying ACLs..."
      /usr/bin/find "$root" -type d -exec /bin/chmod +a "$ACL_DIR_COLLAB" {} +
      /usr/bin/find "$root" -type f -exec /bin/chmod +a "$ACL_FILE_COLLAB" {} +
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

    # Fix group ownership, mode bits, and setgid.
    # Only items that fail a check are touched — a second run is a no-op.
    echo "Checking ownership, mode bits, and setgid..."
    for path in "$@"; do
      /usr/bin/find "$path" \! -group "''${GROUP}" -exec /usr/sbin/chown ":''${GROUP}" {} +
      /usr/bin/find "$path" -type d \( \! -perm -g+rwx -o \! -perm -g+s \) -exec /bin/chmod g+rwxs {} +
      /usr/bin/find "$path" -type f \! -perm -g+rw -exec /bin/chmod g+rw {} +
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
  sops = {
    age.keyFile = "/Users/${primaryUser}/.config/sops/age/keys.txt";
    secrets."CLAUDE_CODE_OAUTH_TOKEN" = {
      sopsFile = ../secrets/claude-oauth.env;
      format = "dotenv";
      owner = claudeUser;
      group = "aicoders";
      mode = "0440";
    };
    secrets."CLAUDE_CODE_OAUTH_TOKEN_INFRACOST" = {
      sopsFile = ../secrets/claude-oauth-infracost.env;
      format = "dotenv";
      owner = claudeUser;
      group = "aicoders";
      mode = "0440";
    };
  };

  environment.systemPackages = with pkgs; [
    nixd
    codexScript
    claudeScript
    aicoderPerms
    pkgs.llm-agents.rtk

    # Development languages and tools (available to all users including _claude/_codex)
    nodejs_22 # or nodejs-slim if you don't need npm
    bun
    deno
    cargo
    rustc
    rust-analyzer
    python312
    uv # Python package manager
    go

    # Language servers
    typescript-language-server
    typescript
    pyright
    gopls
    ruby-lsp
    bash-language-server
    svelte-language-server
    terraform-ls
    astro-language-server
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
      "_synapseagent"
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
    mkdir -p ${codexHome}/.config ${codexHome}/.cache ${codexHome}/.local/share ${codexHome}/.local/bin
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
    mkdir -p ${claudeHome}/.config ${claudeHome}/.cache ${claudeHome}/.local/share ${claudeHome}/.local/bin ${claudeHome}/.claude-infracost
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
    # Grant aicoders group basic access to traverse user home and system directories
    sudo chmod +a "group:aicoders allow read,execute,search" "$TMPDIR"
    sudo chmod +a "group:aicoders allow read,execute,search,file_inherit,directory_inherit" "$\{TMPDIR\}TemporaryItems"
    sudo chmod +a "group:aicoders allow search" /var/folders/

    # Grant access to go binaries (if needed for project-installed tools)
    for d in /Users/${primaryUser}/go \
             /Users/${primaryUser}/go/bin; do
      if [ -d "$d" ]; then
        chmod +a "group:aicoders allow read,execute,search,readattr,readextattr,readsecurity" "$d" 2>/dev/null || true
      fi
    done
  '';

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "zap";
    };

    global.brewfile = true;

    taps = [
      "dagger/tap"
    ];

    brews = [
    ];

    casks = [
      "claude-code@latest"
      "codex"
      "copilot-cli"
    ];

    masApps = { };
  };

  home-manager.users.${primaryUser} =
    { lib, ... }:
    {
      home.file.".claude/CLAUDE.md".source = ./configs/agent.md;
      home.file.".claude/settings.json".source = ./configs/claude.settings.json;

      programs.rtk-hooks = {
        enable = true;
        integrations = {
          claude.enable = true;
          codex.enable = true;
        };
      };

      programs.tmux = {
        enable = true;
      };
    };

  home-manager.users.${codexUser} = {
    sops.age.sshKeyPaths = [ ];
    home = {
      stateVersion = "25.05";
      homeDirectory = codexHome;
    };
    programs.rtk-hooks = {
      enable = true;
      integrations.codex.enable = true;
    };
    programs.git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        user.name = gitName;
        user.email = gitEmail;
        "credential \"https://github.com\"".helper = [
          ""
          "!/opt/homebrew/bin/gh auth git-credential"
        ];
        "credential \"https://gist.github.com\"".helper = [
          ""
          "!/opt/homebrew/bin/gh auth git-credential"
        ];
      };
    };
    programs.tmux = {
      enable = true;
    };
  };

  home-manager.users.${claudeUser} =
    { lib, pkgs, ... }:
    {
      sops.age.sshKeyPaths = [ ];
      programs.rtk-hooks = {
        enable = true;
        integrations.claude.enable = true;
      };
      home = {
        stateVersion = "25.05";
        homeDirectory = claudeHome;

        # Write settings.json as a regular file (not a symlink) so that
        # `claude plugin install` can update it. Nix re-seeds the content
        # on each rebuild, and the plugin installer can layer on top.
        activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                  mkdir -p ${claudeHome}/.claude
                  rm -f ${claudeHome}/.claude/settings.json
                  cat > ${claudeHome}/.claude/settings.json <<'SETTINGS_EOF'
          ${builtins.toJSON claudeSettings}
          SETTINGS_EOF
                  chown ${claudeUser}:aicoders ${claudeHome}/.claude/settings.json
                  chmod 600 ${claudeHome}/.claude/settings.json

                  # Merge mcpServers into ~/.claude.json (Claude Code manages this file;
                  # we only upsert the mcpServers key so we don't clobber other state).
                  CLAUDE_JSON="${claudeHome}/.claude.json"
                  if [ ! -f "$CLAUDE_JSON" ]; then
                    echo '{}' > "$CLAUDE_JSON"
                    chown ${claudeUser}:aicoders "$CLAUDE_JSON"
                    chmod 600 "$CLAUDE_JSON"
                  fi
                  ${pkgs.python3}/bin/python3 -c "
          import json, sys
          path = sys.argv[1]
          with open(path) as f:
              d = json.load(f)
          d['mcpServers'] = json.loads(sys.argv[2])
          with open(path, 'w') as f:
              json.dump(d, f, indent=2)
          " "$CLAUDE_JSON" '${builtins.toJSON mcpConfig.mcpServers}'
        '';

        activation.claudePlugins = lib.hm.dag.entryAfter [ "claudeSettings" ] ''
          if [ -x /opt/homebrew/bin/claude ]; then
            CLAUDE_ENV="HOME=${claudeHome} PATH=/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"

            # Marketplaces
            env $CLAUDE_ENV /opt/homebrew/bin/claude plugin marketplace add infracost/agent-skills 2>/dev/null || true
            env $CLAUDE_ENV /opt/homebrew/bin/claude plugin marketplace add /Users/${primaryUser}/Development/personal/synapse/.claude-marketplace 2>/dev/null || true

            # Infracost plugin
            env $CLAUDE_ENV /opt/homebrew/bin/claude plugin install infracost@infracost 2>/dev/null || true

            # Official LSP plugins
            for plugin in \
              swift-lsp \
              rust-analyzer-lsp \
              typescript-lsp \
              pyright-lsp \
              gopls-lsp \
              ruby-lsp \
            ; do
              env $CLAUDE_ENV /opt/homebrew/bin/claude plugin install "$plugin@claude-plugins-official" 2>/dev/null || true
            done

            # Synapse marketplace plugins
            for plugin in \
              spec-language-server \
              bash-language-server \
              svelte-lsp \
              terraform-ls \
              astro-lsp \
            ; do
              env $CLAUDE_ENV /opt/homebrew/bin/claude plugin install "$plugin@synapse" 2>/dev/null || true
            done
          fi
        '';
      };
      programs.git = {
        enable = true;
        settings = {
          init.defaultBranch = "main";
          user.name = gitName;
          user.email = gitEmail;
          "credential \"https://github.com\"".helper = [
            ""
            "!/opt/homebrew/bin/gh auth git-credential"
          ];
          "credential \"https://gist.github.com\"".helper = [
            ""
            "!/opt/homebrew/bin/gh auth git-credential"
          ];
        };
      };
      programs.tmux = {
        enable = true;
      };
    };
  security.sudo.extraConfig = ''
    ${primaryUser} ALL=(${claudeUser}) NOPASSWD: ${lib.getExe claudeAsUser}
    ${primaryUser} ALL=(${codexUser}) NOPASSWD: ${lib.getExe codexAsUser}
    ${primaryUser} ALL=(_synapseagent) NOPASSWD: ALL

    ${claudeUser} ALL=(${claudeUser}) NOPASSWD: ${lib.getExe claudeAsUser}
    ${claudeUser} ALL=(${codexUser}) NOPASSWD: ALL
    ${codexUser} ALL=(${claudeUser}) NOPASSWD: ALL
    ${claudeUser} ALL=(_synapseagent) NOPASSWD: ALL
    ${codexUser} ALL=(_synapseagent) NOPASSWD: ALL
  '';
}
