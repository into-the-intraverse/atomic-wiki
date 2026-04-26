#!/bin/bash
# Copy hooks from scripts/hooks/ into .git/hooks/ and make them executable.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$REPO_ROOT/scripts/hooks"
DST_DIR="$REPO_ROOT/.git/hooks"

if [ ! -d "$DST_DIR" ]; then
  echo "ERROR: $DST_DIR not found — is this a git repo?"
  exit 1
fi

for hook in "$SRC_DIR"/*; do
  [ -f "$hook" ] || continue
  name=$(basename "$hook")
  cp "$hook" "$DST_DIR/$name"
  chmod +x "$DST_DIR/$name"
  echo "installed: $name"
done

echo "Done. Atom version-bump check is now active on commit."
