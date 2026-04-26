#!/bin/bash
# Verify staged atom files have a version bump when content changed substantively.
# Compares git index (staged) against HEAD.
#
# Pure formatting changes (whitespace, blank lines) don't require a bump.
# Any other body change does. New atoms must declare `version: 1`.
#
# Exit 0 = OK. Exit 1 = at least one violation. Used by .git/hooks/pre-commit.

REPO_ROOT="$(git rev-parse --show-toplevel)"
ERRORS=0

STAGED_ATOMS=$(git diff --cached --name-only --diff-filter=AM | grep '^atoms/.*\.md$' || true)

for f in $STAGED_ATOMS; do
  base=$(basename "$f")
  case "$base" in
    _template.md|README.md) continue ;;
  esac

  # New file path: must declare version: 1
  if ! git cat-file -e "HEAD:$f" 2>/dev/null; then
    if ! git show ":$f" | grep -qE '^version:[[:space:]]*1[[:space:]]*$'; then
      echo "ERROR: $f is new — frontmatter must include 'version: 1'"
      ERRORS=$((ERRORS+1))
    fi
    continue
  fi

  # Substantive diff = anything beyond pure whitespace / blank lines.
  DIFF=$(git diff --cached --ignore-all-space --ignore-blank-lines -- "$f" 2>/dev/null)
  if [ -z "$DIFF" ]; then
    continue
  fi

  OLD_VERSION=$(git show "HEAD:$f" | awk '/^version:/{print $2; exit}')
  NEW_VERSION=$(git show ":$f"     | awk '/^version:/{print $2; exit}')

  if [ -z "$NEW_VERSION" ]; then
    echo "ERROR: $f is missing 'version' field in frontmatter"
    ERRORS=$((ERRORS+1))
    continue
  fi

  if ! [[ "$NEW_VERSION" =~ ^[0-9]+$ ]] || ! [[ "$OLD_VERSION" =~ ^[0-9]+$ ]]; then
    echo "ERROR: $f version must be an integer (got old='$OLD_VERSION' new='$NEW_VERSION')"
    ERRORS=$((ERRORS+1))
    continue
  fi

  if [ "$NEW_VERSION" -le "$OLD_VERSION" ]; then
    echo "ERROR: $f content changed but version not bumped (was $OLD_VERSION, still $NEW_VERSION)"
    echo "       Bump 'version:' in frontmatter, or revert non-formatting changes."
    ERRORS=$((ERRORS+1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "Version-bump check failed: $ERRORS atom file(s) need attention."
  exit 1
fi

exit 0
