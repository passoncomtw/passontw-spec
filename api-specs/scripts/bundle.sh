#!/bin/bash
set -e
PROJECTS="pos-systems token-system games-system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"
mkdir -p dist

for project in $PROJECTS; do
  echo "Bundling $project..."
  redocly bundle "projects/$project/openapi.yaml" -o "dist/$project.json" 2>/dev/null || true
done
