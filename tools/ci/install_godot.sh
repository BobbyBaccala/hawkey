#!/usr/bin/env bash
# Linux x86_64 CI toolchain; no root installation or third-party setup action.
set -euo pipefail
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'This helper installs Linux x86_64 only. Install Godot 4.6.3 manually on other platforms.' >&2
  exit 1
fi
target="${1:-build/tools/bin}"
archive='Godot_v4.6.3-stable_linux.x86_64.zip'
# Official 4.6.3-stable SHA512-SUMS.txt, verified 2026-10-20.
expected='a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c'
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
curl --fail --location --silent --show-error --retry 3 --max-time 180 \
  "https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/$archive" \
  --output "$staging/$archive"
printf '%s  %s\n' "$expected" "$staging/$archive" | sha512sum --check --status
unzip -p "$staging/$archive" 'Godot_v4.6.3-stable_linux.x86_64' > "$staging/godot"
mkdir -p "$target"
install -m 755 "$staging/godot" "$target/godot"
"$target/godot" --headless --version
