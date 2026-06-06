#!/bin/bash
# Verifies lint.sh resolves the CONSUMER git root and no-ops outside wiki projects.
set -u
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$PLUGIN_DIR/scripts/lint.sh"
fail=0

# Case 1: a wiki project -> lint-report.md is written at the project root.
t1="$(mktemp -d)"; git -C "$t1" init -q
mkdir -p "$t1/wiki/mcp"; printf '# Auth\n\nbody\n' > "$t1/wiki/mcp/auth.md"
( cd "$t1" && CLAUDE_PROJECT_DIR="$t1" bash "$LINT" >/dev/null 2>&1 )
if [ -f "$t1/lint-report.md" ]; then echo "PASS case1"; else echo "FAIL case1"; fail=1; fi

# Case 2: a git repo WITHOUT wiki/ -> no-op, no report.
t2="$(mktemp -d)"; git -C "$t2" init -q
( cd "$t2" && CLAUDE_PROJECT_DIR="$t2" bash "$LINT" >/dev/null 2>&1 )
if [ ! -f "$t2/lint-report.md" ]; then echo "PASS case2"; else echo "FAIL case2"; fail=1; fi

rm -rf "$t1" "$t2"
exit $fail
