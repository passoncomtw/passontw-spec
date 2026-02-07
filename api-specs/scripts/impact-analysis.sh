#!/bin/bash
CHANGED_FILE=$1
if [[ "$CHANGED_FILE" == shared/* ]]; then
  echo "共用 Schema 變更，可能影響所有項目:"
  grep -r "$(basename "$CHANGED_FILE")" projects/ 2>/dev/null || true
fi
