#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

PROJECTS="pos-systems token-system games-system staff-scheduling"
mkdir -p dist

for project in $PROJECTS; do
  echo "Bundling $project..."
  if command -v redocly &>/dev/null; then
    redocly bundle "projects/$project/openapi.yaml" -o "dist/$project.json"
  elif command -v npx &>/dev/null; then
    npx --yes @redocly/cli bundle "projects/$project/openapi.yaml" -o "dist/$project.json"
  else
    echo "Redocly not found. Install: npm i -g @redocly/cli"
    exit 1
  fi
done

echo "Bundle done. Output: dist/"
