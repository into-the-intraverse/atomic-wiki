#!/bin/bash
# Verifies the installer vendors the check script and registers a working pre-commit hook
# (config-based on git >= 2.54, else file-based), and that the hook rejects an unbumped body change.
# NOTE: on git >= 2.54 only the config-based path is exercised; the file-based fallback is not.
set -u
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$PLUGIN_DIR/scripts/install-versionbump-hook.sh"
fail=0

t="$(mktemp -d)"; git -C "$t" init -q
git -C "$t" config user.email t@t.t; git -C "$t" config user.name t

# Run the installer from inside the scratch repo (as /wiki-init would).
( cd "$t" && bash "$INSTALLER" >/dev/null 2>&1 )

# Vendored script must exist.
if [ -f "$t/.wiki/check-version-bump.sh" ]; then echo "PASS vendored"; else echo "FAIL vendored"; fail=1; fi

# A new atom with version: 1 commits fine.
mkdir -p "$t/atoms/x"
printf -- '---\nid: x/a\nversion: 1\n---\n\nbody one\n' > "$t/atoms/x/a.md"
git -C "$t" add atoms/x/a.md
if git -C "$t" commit -q -m "add atom"; then echo "PASS commit-new"; else echo "FAIL commit-new"; fail=1; fi

# Editing the body without bumping version must be REJECTED.
printf -- '---\nid: x/a\nversion: 1\n---\n\nbody two changed\n' > "$t/atoms/x/a.md"
git -C "$t" add atoms/x/a.md
if git -C "$t" commit -q -m "change body no bump"; then echo "FAIL reject"; fail=1; else echo "PASS reject"; fi

rm -rf "$t"
exit $fail
