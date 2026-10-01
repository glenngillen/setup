{
  pkgs,
  primaryUser,
  lib,
  config,
  ...
}:
let
  synapseAgentUser = "_synapseagent";
  synapseAgentHome = "/var/synapse/agent-home";
  gitName = "Glenn Gillen";
  gitEmail = "me@glenngillen.com";
  primaryUserHome = "/Users/${primaryUser}";
  synapseDebugPath = "${primaryUserHome}/Development/personal/synapse/target/debug";

  # MCP server configuration (shared between gg and _synapseagent)
  mcpConfig = {
    mcpServers = {
    };
  };

  # Shared Claude Code settings (source of truth for both gg and _synapseagent)
  baseClaudeSettings = builtins.fromJSON (builtins.readFile ./configs/claude.settings.json);

  # _synapseagent gets the shared settings + LSP tool + extra plugins
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

  # Read-only MCP policy for the infracost profile. Denies every write-capable
  # tool on the close/linear/mixpanel/notion MCP servers by exact name (99 of
  # 255 tools, classified 2026-10-02). Passed via --settings from the read-only
  # nix store, so the agent can't edit it the way it can edit
  # .claude-infracost/settings.json, and deny rules from a lower settings
  # source can't remove it. Deny rules hold under --dangerously-skip-permissions
  # and hide the tools from the model entirely. New vendor tools are NOT
  # covered until added here.
  claudeInfracostMcpPolicy = pkgs.writeText "claude-infracost-mcp-policy.json" (
    builtins.readFile ./configs/claude-infracost-mcp-deny.json
  );

  # Infracost profile: same settings but routed through LiteLLM gateway
  claudeSettingsInfracost = claudeSettings // {
    env = claudeSettings.env // {
      ANTHROPIC_BASE_URL = "https://litellm.internal.dev.infracost.io";
      ANTHROPIC_CUSTOM_HEADERS = "x-litellm-api-key: ${config.sops.placeholder.LITELLM_API_KEY_INFRACOST}";
      OTEL_EXPORTER_OTLP_METRICS_PROTOCOL = "http/protobuf";
      OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
      CLAUDE_CODE_ENABLE_TELEMETRY = "1";
    };
  };

  # Preferred codex settings, merged into every codex config we manage:
  # the primary user's ~/.codex/config.toml and the agent's infracost profile.
  # Codex writes to these files itself (trust levels, project entries), so
  # they are merged rather than replaced with a store symlink.
  codexSettings = {
    check_for_update_on_startup = false;
  };

  # Merges the declared settings into a config.toml in place, leaving
  # everything codex wrote itself untouched.
  mergeCodexSettings =
    pkgs.writers.writePython3Bin "merge-codex-settings"
      {
        libraries = [ pkgs.python3Packages.tomlkit ];
      }
      ''
        """Merge settings into a codex config.toml in place.

        Usage: merge-codex-settings <config.toml> <settings-json>
        Only keys present in the JSON are touched.
        """
        import json
        import pathlib
        import sys

        import tomlkit


        def merge(target, updates):
            for key, value in updates.items():
                if isinstance(value, dict):
                    if not isinstance(target.get(key), dict):
                        target[key] = tomlkit.table()
                    merge(target[key], value)
                elif target.get(key) != value:
                    target[key] = value


        path = pathlib.Path(sys.argv[1])
        before = path.read_text() if path.exists() else ""

        doc = tomlkit.parse(before)
        merge(doc, json.loads(sys.argv[2]))
        after = tomlkit.dumps(doc)

        if after != before:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(after)
            print("updated " + str(path), file=sys.stderr)
      '';

  # Shared toolchain PATH: prioritize nix system packages, then homebrew
  toolchainPath = lib.concatStringsSep ":" [
    "/run/current-system/sw/bin" # System packages (nodejs, cargo, etc.)
    "${primaryUserHome}/go/bin" # Go binaries
    synapseDebugPath # Synapse debug binaries
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/etc/profiles/per-user/${primaryUser}/bin"
  ];

  codexAsUser = pkgs.writeShellScriptBin "codex-as-agent" ''
    set -euo pipefail

    CWD="/tmp"
    GH_TOKEN_VALUE=""
    TOKEN_PROFILE="default"
    CARGO_TARGET_DIR_VALUE=""
    HTTPS_PROXY_VALUE=""

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --cwd) CWD="$2"; shift 2 ;;
        --gh-token) GH_TOKEN_VALUE="$2"; shift 2 ;;
        --token-profile) TOKEN_PROFILE="$2"; shift 2 ;;
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
    export GIT_CONFIG_COUNT=3
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0="$CWD"
    export GIT_CONFIG_KEY_1=user.name
    export GIT_CONFIG_VALUE_1="${gitName}"
    export GIT_CONFIG_KEY_2=user.email
    export GIT_CONFIG_VALUE_2="${gitEmail}"
    export PATH="${synapseAgentHome}/.cargo/bin:${synapseAgentHome}/.local/bin:${toolchainPath}:$PATH"

    # Select codex config directory based on profile
    case "$TOKEN_PROFILE" in
      default)
        ;;
      infracost)
        export CODEX_HOME="${synapseAgentHome}/.codex-infracost"
        ;;
      *)
        echo "codex: unknown token profile: $TOKEN_PROFILE" >&2
        echo "       available profiles: default, infracost" >&2
        exit 1
        ;;
    esac

    umask 0002

    if ! cd "$CWD" 2>/dev/null; then
      echo "codex: cannot access working directory: $CWD" >&2
      echo "       (check aicoders ACLs / aicoder-perms on this path)" >&2
      exit 1
    fi

    # Point git at gh's credential helper for github.com and gist.github.com.
    # gh reads the token exported above, so this needs no login of its own.
    # It rewrites ~/.gitconfig and is idempotent, so running it per launch is
    # cheap. Non-fatal on failure: concurrent agent sessions can lose a race
    # for git's config lock, and that shouldn't stop the session starting.
    if [ -n "$GH_TOKEN_VALUE" ]; then
      /opt/homebrew/bin/gh auth setup-git 2>/dev/null \
        || echo "codex: gh auth setup-git failed; git may not authenticate to github.com" >&2
    fi

    exec /opt/homebrew/bin/codex "$@"
  '';

  codexScript = pkgs.writeShellScriptBin "codex" ''
    set -euo pipefail

    CWD_REAL="$(/bin/pwd -P 2>/dev/null || /bin/pwd)"

    # Resolve a GitHub token to hand to the agent. `gh auth token` echoes
    # $GH_TOKEN when that is set and otherwise reads the keyring login, so this
    # covers both an explicit override and a plain `gh auth login`. It has to be
    # resolved here, as the calling user: the agent uid has no keyring login of
    # its own, and sudo's env_reset means the variable can't just be inherited.
    GH_TOKEN_VALUE="$(/opt/homebrew/bin/gh auth token 2>/dev/null || true)"
    if [ -z "$GH_TOKEN_VALUE" ]; then
      echo "codex: no GitHub token (is \`gh auth login\` done?); git and gh will be unauthenticated" >&2
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

    CODEX_ARGS=(
      ${lib.getExe codexAsUser}
      --cwd "$CWD_REAL"
      --gh-token "$GH_TOKEN_VALUE"
      --token-profile "$TOKEN_PROFILE"
      --cargo-target-dir "''${CARGO_TARGET_DIR:-${synapseAgentHome}/.cache/synapse/target/$(basename "$CWD_REAL")}"
      "''${HTTPS_PROXY_ARGS[@]}"
      -- "''${PASSTHROUGH_ARGS[@]}"
    )

    if [ "$(id -un)" = "${synapseAgentUser}" ]; then
      exec "''${CODEX_ARGS[@]}"
    else
      exec sudo -u ${synapseAgentUser} -H "''${CODEX_ARGS[@]}"
    fi
  '';

  claudeAsUser = pkgs.writeShellScriptBin "claude-as-agent" ''
    set -euo pipefail

    CWD="/tmp"
    GH_TOKEN_VALUE=""
    TOKEN_PROFILE="default"
    POLICY_ARGS=()
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
    export GIT_CONFIG_COUNT=3
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0="$CWD"
    export GIT_CONFIG_KEY_1=user.name
    export GIT_CONFIG_VALUE_1="${gitName}"
    export GIT_CONFIG_KEY_2=user.email
    export GIT_CONFIG_VALUE_2="${gitEmail}"
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
        POLICY_ARGS=(--settings ${claudeInfracostMcpPolicy})
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

    # Belt-and-braces: a reboot leaves the login keychain locked until the
    # next darwin-rebuild; unlock it here so credential writes (e.g. MCP
    # OAuth tokens) never raise a GUI keychain prompt mid-session.
    /usr/bin/security unlock-keychain -p "" "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null || true

    # Point git at gh's credential helper for github.com and gist.github.com.
    # gh reads the token exported above, so this needs no login of its own.
    # It rewrites ~/.gitconfig and is idempotent, so running it per launch is
    # cheap. Non-fatal on failure: concurrent agent sessions can lose a race
    # for git's config lock, and that shouldn't stop the session starting.
    if [ -n "$GH_TOKEN_VALUE" ]; then
      /opt/homebrew/bin/gh auth setup-git 2>/dev/null \
        || echo "claude: gh auth setup-git failed; git may not authenticate to github.com" >&2
    fi

    export NODE_OPTIONS="--import ${synapseAgentHome}/.claude/synapse-interceptor.mjs"
    exec /opt/homebrew/bin/claude ''${POLICY_ARGS[@]+"''${POLICY_ARGS[@]}"} "$@"
  '';

  claudeScript = pkgs.writeShellScriptBin "claude" ''
    set -euo pipefail

    CWD_REAL="$(/bin/pwd -P 2>/dev/null || /bin/pwd)"

    # Resolve a GitHub token to hand to the agent. `gh auth token` echoes
    # $GH_TOKEN when that is set and otherwise reads the keyring login, so this
    # covers both an explicit override and a plain `gh auth login`. It has to be
    # resolved here, as the calling user: the agent uid has no keyring login of
    # its own, and sudo's env_reset means the variable can't just be inherited.
    GH_TOKEN_VALUE="$(/opt/homebrew/bin/gh auth token 2>/dev/null || true)"
    if [ -z "$GH_TOKEN_VALUE" ]; then
      echo "claude: no GitHub token (is \`gh auth login\` done?); git and gh will be unauthenticated" >&2
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
      --cargo-target-dir "''${CARGO_TARGET_DIR:-${synapseAgentHome}/.cache/synapse/target/$(basename "$CWD_REAL")}"
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
      # _synapseagent that inherit a reduced permission set).
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

    # Parents (so _synapseagent can reach the tree under /Users/gg)
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
  # Make locally built Synapse tools available to launchd/service contexts,
  # including commands executed as _synapseagent outside the wrappers above.
  environment.systemPath = [ synapseDebugPath ];

  sops = {
    age.keyFile = "/Users/${primaryUser}/.config/sops/age/keys.txt";
    secrets."CLAUDE_CODE_OAUTH_TOKEN" = {
      sopsFile = ../secrets/claude-oauth.env;
      format = "dotenv";
      owner = synapseAgentUser;
      group = "aicoders";
      mode = "0440";
    };
    secrets."CLAUDE_CODE_OAUTH_TOKEN_INFRACOST" = {
      sopsFile = ../secrets/claude-oauth-infracost.env;
      format = "dotenv";
      owner = synapseAgentUser;
      group = "aicoders";
      mode = "0440";
    };
    secrets."LITELLM_API_KEY_INFRACOST" = {
      sopsFile = ../secrets/litellm-infracost.json;
      format = "json";
      owner = synapseAgentUser;
      group = "aicoders";
      mode = "0440";
    };

    # Substitute the gateway key after decryption, keeping it out of the Nix store.
    templates."claude-infracost-settings.json".content = builtins.toJSON claudeSettingsInfracost;
    templates."codex-infracost-config.toml".content = ''
      model_provider = "litellm"

      [model_providers.litellm]
      name = "LiteLLM gateway"
      base_url = "https://litellm.internal.dev.infracost.io/chatgpt"
      wire_api = "responses"
      requires_openai_auth = true
      http_headers = { "x-litellm-api-key" = "${config.sops.placeholder.LITELLM_API_KEY_INFRACOST}" }
    '';
  };

  environment.systemPackages = with pkgs; [
    nixd
    codexScript
    claudeScript
    aicoderPerms

    # Development languages and tools (available to all users including _synapseagent)
    nodejs_22 # or nodejs-slim if you don't need npm
    bun
    deno
    cargo
    rustc
    rust-analyzer
    rustfmt
    clippy
    cargo-sweep # synapse loop_maintenance silently no-ops target-dir GC without it
    python312
    uv # Python package manager
    go
    ruby_3_4 # ships bundler 2.6 + rubygems 3.7; see GEM_HOME in dev.nix

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
    synapseAgentUser
  ];

  users.knownGroups = [ "aicoders" ];
  users.groups.aicoders = {
    gid = 4210;
    members = [
      "_synapseagent"
      primaryUser
    ];
  };

  users.users.${synapseAgentUser} = {
    uid = 319;
    gid = 319;
    description = "Synapse agent service user";
    home = synapseAgentHome;
    createHome = true;
    isHidden = true;
    shell = null;
  };

  # sops-nix decrypts secrets at mkAfter (1500); copy its rendered templates afterwards.
  system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
    echo "setting up synapse agent home..." >&2
    mkdir -p ${synapseAgentHome}/.claude ${synapseAgentHome}/.config ${synapseAgentHome}/.cache ${synapseAgentHome}/.local/share ${synapseAgentHome}/.local/bin ${synapseAgentHome}/.claude-infracost ${synapseAgentHome}/.codex ${synapseAgentHome}/.codex-infracost
    # Re-own only what is actually mis-owned. A blanket `chown -R` over the
    # whole home walked ~950k paths on every switch to change nothing in steady
    # state, and it only had to hit one transient read error to take the entire
    # rebuild down with it: readdir on macOS' sandbox containers under
    # Library/Containers intermittently fails with EINTR ("Interrupted system
    # call"), GNU chown treats that as fatal, and `set -e` at the top of
    # nix-darwin's activation script does the rest. Those containers are only
    # ever written by processes already running as the agent user, so prune
    # them; and warn rather than abort if anything else refuses to be read.
    # Xcode also attaches its downloaded toolchains (e.g. MetalToolchain) as
    # read-only disk images under DVTDownloads/*/mounts; chown can't touch
    # those and produced hundreds of EROFS errors per switch, so prune them too.
    if ! find ${synapseAgentHome} \
      \( -path "${synapseAgentHome}/Library/Containers" \
         -o -path "${synapseAgentHome}/Library/Group Containers" \
         -o -path "${synapseAgentHome}/Library/Developer/DVTDownloads/*/mounts" \) -prune -o \
      \( ! -user ${synapseAgentUser} -o ! -group aicoders \) \
      -exec chown -h ${synapseAgentUser}:aicoders {} + ; then
      echo "warning: some paths under ${synapseAgentHome} could not be re-owned" >&2
    fi

    # Login keychain for the service user, empty password, kept UNLOCKED with
    # auto-lock disabled. The earlier "leave it locked, tools fall back to
    # file storage" theory was wrong in practice: a locked DEFAULT keychain
    # doesn't trigger file fallback (only a missing one does) — it makes
    # `security` raise a GUI unlock prompt on the console user's screen
    # (bit the Claude Code MCP OAuth flow, 2026-08-24; the default
    # lock-on-sleep timeout=300s meant it was always locked again by the
    # time a token write happened). Unlocked-with-empty-password is the
    # strongest posture actually available to a headless uid: a passphrase
    # would have to live in a file the same uid can read, item ACLs still
    # gate cross-process reads, and at-rest protection is FileVault + file
    # perms — same as this user's sops-managed credentials.
    SA_KC="${synapseAgentHome}/Library/Keychains/login.keychain-db"
    if [ ! -f "$SA_KC" ]; then
      mkdir -p "$(dirname "$SA_KC")"
      sudo -u ${synapseAgentUser} -H env HOME=${synapseAgentHome} /usr/bin/security create-keychain -p "" "$SA_KC"
      sudo -u ${synapseAgentUser} -H env HOME=${synapseAgentHome} /usr/bin/security default-keychain -s "$SA_KC"
    fi
    # Unlock BEFORE changing settings, and never let either step be fatal.
    # set-keychain-settings on a locked keychain has to unlock it first, and
    # with no password on the command line that means raising the GUI unlock
    # panel. Activation has no one to answer it, so it comes back
    # errSecUserCanceled ("User canceled the operation") and `set -e` takes
    # the entire switch down with it — which is exactly what happened on
    # 2026-08-31: the system profile advanced to the new generation but
    # /run/current-system stayed on the old one, so the rebuild looked
    # applied while the old wrappers kept running. unlock-keychain is safe
    # to go first because -p supplies the password rather than prompting.
    if ! sudo -u ${synapseAgentUser} -H env HOME=${synapseAgentHome} /usr/bin/security unlock-keychain -p "" "$SA_KC" 2>/dev/null; then
      echo "warning: could not unlock the agent login keychain ($SA_KC);" >&2
      echo "         credential writes may raise a GUI prompt" >&2
    # no -l/-u/-t flags => never auto-lock, no lock-on-sleep
    elif ! sudo -u ${synapseAgentUser} -H env HOME=${synapseAgentHome} /usr/bin/security set-keychain-settings "$SA_KC" 2>/dev/null; then
      echo "warning: could not disable auto-lock on the agent login keychain" >&2
    fi

    # Write claude settings.json
    rm -f ${synapseAgentHome}/.claude/settings.json
    cat > ${synapseAgentHome}/.claude/settings.json <<'SETTINGS_EOF'
    ${builtins.toJSON claudeSettings}
    SETTINGS_EOF
    chown ${synapseAgentUser}:aicoders ${synapseAgentHome}/.claude/settings.json
    chmod 600 ${synapseAgentHome}/.claude/settings.json

    # Copy rendered configs as writable files; both CLIs may update their settings.
    rm -f ${synapseAgentHome}/.claude-infracost/settings.json
    install -m 600 -o ${synapseAgentUser} -g aicoders \
      ${config.sops.templates."claude-infracost-settings.json".path} \
      ${synapseAgentHome}/.claude-infracost/settings.json

    # Write infracost codex config.toml (LiteLLM gateway provider)
    install -m 600 -o ${synapseAgentUser} -g aicoders \
      ${config.sops.templates."codex-infracost-config.toml".path} \
      ${synapseAgentHome}/.codex-infracost/config.toml
    ${mergeCodexSettings}/bin/merge-codex-settings \
      ${synapseAgentHome}/.codex-infracost/config.toml \
      ${lib.escapeShellArg (builtins.toJSON codexSettings)}
    chown ${synapseAgentUser}:aicoders ${synapseAgentHome}/.codex-infracost/config.toml
    chmod 600 ${synapseAgentHome}/.codex-infracost/config.toml

    # Merge preferred settings into the agent's default codex profile
    ${mergeCodexSettings}/bin/merge-codex-settings \
      ${synapseAgentHome}/.codex/config.toml \
      ${lib.escapeShellArg (builtins.toJSON codexSettings)}
    chown ${synapseAgentUser}:aicoders ${synapseAgentHome}/.codex/config.toml
    chmod 600 ${synapseAgentHome}/.codex/config.toml

    # Merge mcpServers into ~/.claude.json
    CLAUDE_JSON="${synapseAgentHome}/.claude.json"
    if [ ! -f "$CLAUDE_JSON" ]; then
      echo '{}' > "$CLAUDE_JSON"
      chown ${synapseAgentUser}:aicoders "$CLAUDE_JSON"
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

    # Install rustup components as _synapseagent
    if command -v rustup >/dev/null 2>&1; then
      sudo -u ${synapseAgentUser} -H env HOME=${synapseAgentHome} PATH="/run/current-system/sw/bin:${synapseAgentHome}/.cargo/bin:/opt/homebrew/bin:$PATH" rustup component add rust-analyzer rustfmt 2>/dev/null || true
    fi

    # Install and enable plugins as _synapseagent
    echo "installing claude plugins for ${synapseAgentUser}..." >&2
    if [ -x /opt/homebrew/bin/claude ]; then
      SA_CMD="sudo -u ${synapseAgentUser} -H env HOME=${synapseAgentHome} PATH=/run/current-system/sw/bin:${synapseAgentHome}/.cargo/bin:/opt/homebrew/bin:''$PATH"

      # Marketplaces
      $SA_CMD /opt/homebrew/bin/claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
      $SA_CMD /opt/homebrew/bin/claude plugin marketplace add infracost/agent-skills 2>/dev/null || true
      $SA_CMD /opt/homebrew/bin/claude plugin marketplace add /Users/${primaryUser}/Development/personal/synapse/.claude-marketplace 2>/dev/null || true

      # Infracost plugin
      $SA_CMD /opt/homebrew/bin/claude plugin install infracost@infracost 2>/dev/null || true

      # Official LSP plugins
      for plugin in \
        rust-analyzer-lsp \
        typescript-lsp \
        swift-lsp \
        pyright-lsp \
        gopls-lsp \
        ruby-lsp \
      ; do
        $SA_CMD /opt/homebrew/bin/claude plugin install "$plugin@claude-plugins-official" 2>/dev/null || true
        $SA_CMD /opt/homebrew/bin/claude plugin enable "$plugin@claude-plugins-official" 2>/dev/null || true
      done

      # Synapse marketplace plugins
      for plugin in \
        spec-language-server \
        bash-language-server \
        svelte-lsp \
        terraform-ls \
        astro-lsp \
      ; do
        $SA_CMD /opt/homebrew/bin/claude plugin install "$plugin@synapse" 2>/dev/null || true
        $SA_CMD /opt/homebrew/bin/claude plugin enable "$plugin@synapse" 2>/dev/null || true
      done
    fi

    echo "setting up ai permissions..." >&2
    # Grant aicoders group basic access to traverse user home and system directories
    chmod +a "group:aicoders allow read,execute,search" "$TMPDIR" 2>/dev/null || true
    chmod +a "group:aicoders allow read,execute,search,file_inherit,directory_inherit" "$\{TMPDIR\}TemporaryItems" 2>/dev/null || true
    chmod +a "group:aicoders allow search" /var/folders/ 2>/dev/null || true

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
    };

    global.brewfile = true;

    taps = [
      "dagger/tap"
    ];

    brews = [
      "swift"
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

      # ~/.codex/config.toml is codex's own file (it appends project trust
      # levels), so merge the preferred settings in instead of managing it.
      home.activation.codexSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${mergeCodexSettings}/bin/merge-codex-settings \
          ${primaryUserHome}/.codex/config.toml \
          ${lib.escapeShellArg (builtins.toJSON codexSettings)}
      '';

      programs.tmux = {
        enable = true;
      };
    };

  home-manager.users.${synapseAgentUser} = {
    sops.age.sshKeyPaths = [ ];
    home = {
      stateVersion = "25.05";
      homeDirectory = synapseAgentHome;
    };
    programs.git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        user.name = gitName;
        user.email = gitEmail;
        credential.interactive = false;
        "credential \"https://github.com\"".helper = [
          ""
          "!f() { test \"$1\" = get && test -n \"$GH_TOKEN\" && printf 'username=x-access-token\\npassword=%s\\n' \"$GH_TOKEN\"; }; f"
        ];
        "credential \"https://gist.github.com\"".helper = [
          ""
          "!f() { test \"$1\" = get && test -n \"$GH_TOKEN\" && printf 'username=x-access-token\\npassword=%s\\n' \"$GH_TOKEN\"; }; f"
        ];
      };
    };
    programs.tmux = {
      enable = true;
    };
  };

  security.sudo.extraConfig = ''
    ${primaryUser} ALL=(${synapseAgentUser}) NOPASSWD: ALL
  '';
}
