#!/bin/bash
# Register the atom version-bump check as a pre-commit hook in the CURRENT git repo.
# Uses Git 2.54+ config-based hooks when available, else falls back to a .git/hooks/pre-commit file.
# Idempotent. Safe to re-run (e.g. after a fresh clone).
set -e

ROOT="$(git rev-parse --show-toplevel)"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Vendor the (git-relative) check script into the repo so it survives plugin updates and is committed.
mkdir -p "$ROOT/.wiki"
cp "$HERE/check-version-bump.sh" "$ROOT/.wiki/check-version-bump.sh"
chmod +x "$ROOT/.wiki/check-version-bump.sh"

# Parse git version major.minor.
gv="$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)"
gmaj="${gv%%.*}"; gmin="${gv#*.}"
if [ -z "$gv" ]; then echo "atomic-wiki: ERROR cannot parse git version from '$(git --version)'" >&2; exit 1; fi

if [ "$gmaj" -gt 2 ] || { [ "$gmaj" -eq 2 ] && [ "$gmin" -ge 54 ]; }; then
  # Config-based hook (coexists with any existing .git/hooks/pre-commit).
  git config --local hook.atomic-wiki-versionbump.event pre-commit
  # Dynamic root resolution (survives repo moves); mirrors the file-based fallback.
  git config --local hook.atomic-wiki-versionbump.command 'bash "$(git rev-parse --show-toplevel)/.wiki/check-version-bump.sh"'
  echo "atomic-wiki: registered config-based pre-commit hook (git $gv)."
else
  # File-based fallback. Generate a pre-commit that calls the vendored script.
  HOOK="$ROOT/.git/hooks/pre-commit"
  if [ -e "$HOOK" ] && ! grep -q 'atomic-wiki' "$HOOK" 2>/dev/null; then
    echo "atomic-wiki: WARNING existing $HOOK left untouched; add a call to .wiki/check-version-bump.sh manually." >&2
  else
    printf '#!/bin/bash\n# atomic-wiki version-bump check\nexec "$(git rev-parse --show-toplevel)/.wiki/check-version-bump.sh"\n' > "$HOOK"
    chmod +x "$HOOK"
    echo "atomic-wiki: installed file-based pre-commit hook (git $gv)."
  fi
fi
