#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

PROJECTS="pos-systems p2p-exchange-service games-system staff-scheduling"

for project in $PROJECTS; do
  echo "Validating $project..."
  if command -v spectral &>/dev/null; then
    spectral lint "projects/$project/openapi.yaml" --ruleset .spectral.yaml 2>/dev/null || spectral lint "projects/$project/openapi.yaml"
  elif command -v npx &>/dev/null; then
    npx --yes @stoplight/spectral-cli lint "projects/$project/openapi.yaml"
  else
    echo "Spectral not found, skip lint. Install: npm i -g @stoplight/spectral-cli"
  fi
done

echo "Validate done."
