#!/bin/bash
# Verifies gen-index.sh resolves the CONSUMER git root and no-ops outside wiki projects.
set -u
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$PLUGIN_DIR/scripts/gen-index.sh"
fail=0

# Case 1: a wiki project -> index.md is written at the project root with the page listed.
t1="$(mktemp -d)"; git -C "$t1" init -q
mkdir -p "$t1/wiki/mcp"; printf '# Auth\n\nbody\n' > "$t1/wiki/mcp/auth.md"
( cd "$t1" && CLAUDE_PROJECT_DIR="$t1" bash "$GEN" >/dev/null 2>&1 )
if [ -f "$t1/index.md" ] && grep -q 'mcp/auth' "$t1/index.md"; then echo "PASS case1"; else echo "FAIL case1"; fail=1; fi

# Case 2: a git repo WITHOUT wiki/ -> no-op, no index.md created.
t2="$(mktemp -d)"; git -C "$t2" init -q
( cd "$t2" && CLAUDE_PROJECT_DIR="$t2" bash "$GEN" >/dev/null 2>&1 )
if [ ! -f "$t2/index.md" ]; then echo "PASS case2"; else echo "FAIL case2"; fail=1; fi

# Case 3: a non-git directory -> exit 0, no error, no file.
t3="$(mktemp -d)"
( cd "$t3" && CLAUDE_PROJECT_DIR="$t3" bash "$GEN" >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$t3/index.md" ]; then echo "PASS case3"; else echo "FAIL case3 rc=$rc"; fail=1; fi

# Case 4: the `> summary` line under the title lands in the index; pipes are escaped;
# a page without a summary is still listed, with an empty cell.
t4="$(mktemp -d)"; git -C "$t4" init -q
mkdir -p "$t4/wiki/mcp"
printf '# Auth\n\n> Token flow | expiry.\n\nbody\n' > "$t4/wiki/mcp/auth.md"
printf '# Transport\n\nbody\n' > "$t4/wiki/mcp/transport.md"
( cd "$t4" && CLAUDE_PROJECT_DIR="$t4" bash "$GEN" >/dev/null 2>&1 )
if grep -qF '| [[mcp/auth]] | Auth | Token flow \| expiry. |' "$t4/index.md" \
   && grep -qF '| [[mcp/transport]] | Transport |  |' "$t4/index.md"; then
  echo "PASS case4"
else
  echo "FAIL case4"; fail=1
fi

rm -rf "$t1" "$t2" "$t3" "$t4"
exit $fail
