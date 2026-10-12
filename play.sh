#!/usr/bin/env bash
# Launch Arcade Block: 5 Minute Overdrive.
#
# Godot is not on PATH on this machine (it lives in ~/bin), and the game must
# run with the project root as the working directory or it cannot find
# res://assets, res://src or its autoloads. This script handles both.
#
# Usage:
#   ./play.sh                  windowed, vsync on (the default look)
#   ./play.sh --fullscreen     borderless fullscreen
#   ./play.sh --vsync-off      uncapped, for measuring real capacity
#   ./play.sh --both           fullscreen AND vsync off
#
# Any other argument is passed straight to Godot, so
#   ./play.sh --resolution 1280x720
# still works.

set -euo pipefail

# The directory this script lives in is the project root, wherever it is
# called from.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Find a Godot binary. PATH first so a user-installed editor wins, then the
# locations this machine actually uses.
find_godot() {
    if command -v godot >/dev/null 2>&1; then
        command -v godot
        return 0
    fi
    for candidate in \
        "$HOME/bin/godot" \
        /usr/local/bin/godot \
        /usr/bin/godot
    do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

GODOT_BIN="$(find_godot)" || {
    echo "Godot not found. Looked in PATH, \$HOME/bin, /usr/local/bin and /usr/bin." >&2
    echo "Install Godot 4.4+ or set GODOT=/path/to/godot ./play.sh" >&2
    exit 1
}

# An explicit GODOT= override always wins, so the script works on a machine
# where Godot lives somewhere unusual without editing it.
if [ -n "${GODOT:-}" ]; then
    GODOT_BIN="$GODOT"
fi

ARGS=()
FULLSCREEN=""
VSYNC=""

for arg in "$@"; do
    case "$arg" in
        --fullscreen)
            FULLSCREEN="--fullscreen"
            ;;
        --vsync-off)
            VSYNC="--disable-vsync"
            ;;
        --both)
            FULLSCREEN="--fullscreen"
            VSYNC="--disable-vsync"
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

echo "Launching with $GODOT_BIN"
exec "$GODOT_BIN" \
    --path "$PROJECT_DIR" \
    ${FULLSCREEN:+"$FULLSCREEN"} \
    ${VSYNC:+"$VSYNC"} \
    "${ARGS[@]+"${ARGS[@]}"}"
