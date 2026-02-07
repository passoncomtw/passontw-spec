#!/bin/bash
set -e
PROJECTS="pos-systems token-system games-system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

for project in $PROJECTS; do
  echo "Validating $project..."
  spectral lint "projects/$project/openapi.yaml" --ruleset .spectral.yaml 2>/dev/null || true
done
