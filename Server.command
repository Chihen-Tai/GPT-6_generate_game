#!/bin/zsh
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$PROJECT_DIR/tools/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$ENGINE" ]]; then
  ENGINE="/Applications/Godot.app/Contents/MacOS/Godot"
fi
if [[ ! -x "$ENGINE" ]]; then
  ENGINE="$(command -v godot || true)"
fi
if [[ ! -x "$ENGINE" ]]; then
  echo "找不到 Godot 4.6。請先安裝引擎，或使用 godot --headless --path . -- --server。"
  exit 1
fi
exec "$ENGINE" --headless --path "$PROJECT_DIR" -- --server --port=24567
