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
  echo "找不到 Godot 4.6。請用 Godot 開啟此資料夾的 project.godot。"
  read -r "?按 Enter 關閉。"
  exit 1
fi
exec "$ENGINE" --path "$PROJECT_DIR" --rendering-method forward_plus
