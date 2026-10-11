#!/usr/bin/env bash
# Build every Blender-authored asset into assets/art/models/*.glb
#
# WHY THE SANITISED PATH:
# Blender ships its own Python 3.14. If another Python 3.14 (the Hermes
# toolchain) appears earlier in PATH, Blender's embedded interpreter
# resolves that stdlib and every core addon dies with
# "ModuleNotFoundError: No module named 'math'". We therefore run Blender
# with a minimal PATH and no inherited PYTHON* variables.
set -euo pipefail

BLENDER="${BLENDER:-/usr/bin/blender}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="$REPO_ROOT/assets/art/blender"

cd "$REPO_ROOT"

run() {
    local script="$1"
    echo "==> $script"
    env -i \
        HOME="$HOME" \
        PATH=/usr/bin:/bin \
        TERM="${TERM:-dumb}" \
        "$BLENDER" --background --python "$SRC_DIR/$script" 2>&1 \
        | grep -E "^\[(BOUNDS|EXPORT|MESHES)\]|Error|Traceback" || true
}

run build_player_idle.py
run build_powerup_orb.py
run build_buildings.py
run build_props.py

echo
echo "==> assets/art/models/"
ls -la "$REPO_ROOT/assets/art/models/"
