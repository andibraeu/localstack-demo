#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

rm -rf "$BUILD_DIR" "$SCRIPT_DIR/function.zip"
mkdir -p "$BUILD_DIR"

python3 -m pip install -r "$SCRIPT_DIR/requirements.txt" -t "$BUILD_DIR" >/dev/null
cp "$SCRIPT_DIR/handler.py" "$BUILD_DIR/handler.py"

(
  cd "$BUILD_DIR"
  zip -qr "$SCRIPT_DIR/function.zip" .
)

echo "Created $SCRIPT_DIR/function.zip"
