# setup - unified command for managing nix/darwin configuration
#
# Usage: setup <command>
#
# Commands:
#   sync      Apply current configuration (darwin-rebuild switch)
#   update    Update flake inputs and apply (nix flake update + sync)
#   upgrade   Upgrade components (nix, brew)
#   status    Show current system status
#   edit      Open nix config in editor
#   clean     Garbage collect and reclaim disk space

NIXCONFIG="${HOME}/.config/nix"

setup() {
    local cmd="${1:-help}"
    shift 2>/dev/null

    case "$cmd" in
        sync)
            _setup_sync "$@"
            ;;
        update)
            _setup_update "$@"
            ;;
        upgrade)
            _setup_upgrade "$@"
            ;;
        status)
            _setup_status "$@"
            ;;
        edit)
            _setup_edit "$@"
            ;;
        clean)
            _setup_clean "$@"
            ;;
        help|--help|-h)
            _setup_help
            ;;
        *)
            echo "Unknown command: $cmd"
            _setup_help
            return 1
            ;;
    esac
}

_setup_help() {
    cat <<EOF
setup - manage your nix-darwin configuration

Usage: setup <command>

Commands:
  sync              Apply current configuration
  update [input]    Update flake inputs (or specific input) and apply
  upgrade <target>  Upgrade a component:
                      nix   - upgrade Determinate Nix
                      brew  - upgrade Homebrew packages
  status            Show system status
  edit              Open config in \$EDITOR
  clean [level]     Garbage collect and reclaim disk space:
                      (default) - remove unused packages
                      generations - also delete old generations
                      all - full cleanup + optimise store

Examples:
  setup sync                 # Apply current config
  setup update               # Update all flake inputs + apply
  setup update nixpkgs       # Update only nixpkgs + apply
  setup upgrade nix          # Upgrade Nix itself
  setup upgrade brew         # Upgrade Homebrew packages
EOF
}

_setup_sync() {
    echo "Applying configuration..."
    sudo -H darwin-rebuild switch --flake "${NIXCONFIG}"
}

_setup_update() {
    local input="$1"

    if [[ -n "$input" ]]; then
        echo "Updating flake input: $input"
        nix flake update "$input" --flake "${NIXCONFIG}"
    else
        echo "Updating all flake inputs..."
        nix flake update --flake "${NIXCONFIG}"
    fi

    if [[ $? -eq 0 ]]; then
        echo ""
        _setup_sync
    fi
}

_setup_upgrade() {
    local target="${1:-help}"

    case "$target" in
        nix)
            echo "Upgrading Determinate Nix..."
            sudo -i nix upgrade-nix
            ;;
        brew)
            echo "Upgrading Homebrew packages..."
            brew update && brew upgrade
            ;;
        help|--help|-h)
            echo "Usage: setup upgrade <target>"
            echo ""
            echo "Targets:"
            echo "  nix   - Upgrade Determinate Nix installation"
            echo "  brew  - Upgrade Homebrew packages (outside nix management)"
            ;;
        *)
            echo "Unknown upgrade target: $target"
            echo "Run 'setup upgrade help' for options"
            return 1
            ;;
    esac
}

_setup_status() {
    echo "=== Nix ==="
    nix --version
    echo ""

    echo "=== Darwin Generation ==="
    darwin-rebuild --list-generations 2>/dev/null | tail -5
    echo ""

    echo "=== Flake Inputs ==="
    nix flake metadata "${NIXCONFIG}" 2>/dev/null | grep -A100 "Inputs:" | head -20
    echo ""

    echo "=== FlakeHub Auth ==="
    determinate-nixd status 2>/dev/null || echo "determinate-nixd not available"
}

_setup_edit() {
    ${EDITOR:-code} "${NIXCONFIG}"
}

_setup_clean() {
    local level="${1:-default}"

    case "$level" in
        default)
            echo "=== Garbage collecting unused packages ==="
            nix store gc
            echo ""
            echo "=== Disk usage ==="
            _setup_clean_usage
            ;;
        generations)
            echo "=== Deleting old generations ==="
            sudo nix-collect-garbage -d
            echo ""
            echo "=== Disk usage ==="
            _setup_clean_usage
            ;;
        all)
            echo "=== Deleting old generations ==="
            sudo nix-collect-garbage -d
            echo ""
            echo "=== Optimising store (deduplication) ==="
            nix store optimise
            echo ""
            echo "=== Disk usage ==="
            _setup_clean_usage
            ;;
        help|--help|-h)
            echo "Usage: setup clean [level]"
            echo ""
            echo "Levels:"
            echo "  (default)    - Remove unused packages from store"
            echo "  generations  - Delete old generations + garbage collect"
            echo "  all          - Full cleanup: delete generations, gc, and optimise store"
            echo ""
            echo "Examples:"
            echo "  setup clean              # Quick cleanup"
            echo "  setup clean generations  # Remove old system generations"
            echo "  setup clean all          # Maximum disk reclamation"
            ;;
        *)
            echo "Unknown clean level: $level"
            echo "Run 'setup clean help' for options"
            return 1
            ;;
    esac
}

_setup_clean_usage() {
    local store_size=$(du -sh /nix/store 2>/dev/null | cut -f1)
    echo "Nix store: ${store_size:-unknown}"
}
