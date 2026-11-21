#!/usr/bin/env bash
# Idempotent setup for a Linux cloud session (Claude Code on the web, scheduled
# runs). Safe to run every time; it only does what is missing:
#   - Godot 4.6.2 headless binary, cached in ~/.cache/hawkey-godot and linked
#     to /usr/local/bin/godot (falls back to ~/.local/bin if not writable)
#   - xvfb for renders (only installs if apt is available and it's missing)
#   - the Godot import, skipped when .godot/ is newer than every asset
# Usage: tools/cloud_setup.sh            (from anywhere inside the repo)
set -euo pipefail
cd "$(dirname "$0")/.."
VER=4.6.2
NAME="Godot_v${VER}-stable_linux.x86_64"
CACHE="${HOME}/.cache/hawkey-godot"
BIN="${CACHE}/${NAME}"

if ! command -v godot >/dev/null 2>&1 || ! godot --version 2>/dev/null | grep -q "^${VER}"; then
  if [ ! -x "$BIN" ]; then
    mkdir -p "$CACHE"
    echo "Downloading Godot ${VER}..."
    curl -fsSL -o "${CACHE}/godot.zip" "https://github.com/godotengine/godot/releases/download/${VER}-stable/${NAME}.zip"
    (cd "$CACHE" && unzip -oq godot.zip && rm godot.zip)
    chmod +x "$BIN"
  fi
  if ln -sf "$BIN" /usr/local/bin/godot 2>/dev/null; then :; else
    mkdir -p "${HOME}/.local/bin" && ln -sf "$BIN" "${HOME}/.local/bin/godot"
    echo "Linked godot into ~/.local/bin (add it to PATH if needed)."
  fi
fi
godot --version | head -1

if ! command -v xvfb-run >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  echo "Installing xvfb for renders..."
  (apt-get install -y -qq xvfb >/dev/null 2>&1 || sudo apt-get install -y -qq xvfb >/dev/null 2>&1) || echo "xvfb install failed; renders need it."
fi

# Import only when something under assets/ (or project.godot) is newer than
# the import cache.
stamp=".godot/.hawkey-import-stamp"
if [ ! -f "$stamp" ] || [ -n "$(find assets project.godot -newer "$stamp" -print -quit 2>/dev/null)" ]; then
  echo "Importing project (first time takes a few minutes)..."
  godot --headless --import >/dev/null 2>&1 || true
  mkdir -p .godot && touch "$stamp"
else
  echo "Import cache up to date."
fi
echo "Ready. Tests: tools/run_tests.sh  (or one: godot --headless --script tests/<name>.gd)"
