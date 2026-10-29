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

# Case 3: image embeds -> missing targets flagged (atoms + wiki), existing ones pass.
t3="$(mktemp -d)"; git -C "$t3" init -q
mkdir -p "$t3/wiki/mcp" "$t3/atoms/mcp" "$t3/raw/src/images"
printf 'x' > "$t3/raw/src/images/good.jpg"
printf '# Auth\n\n![ok](../../raw/src/images/good.jpg)\n' > "$t3/wiki/mcp/auth.md"
printf -- '---\nid: mcp/a\nversion: 1\n---\n\n![gone](../../raw/src/images/missing.jpg)\n' > "$t3/atoms/mcp/a.md"
( cd "$t3" && CLAUDE_PROJECT_DIR="$t3" bash "$LINT" >/dev/null 2>&1 )
if grep -q 'missing.jpg' "$t3/lint-report.md" && ! grep -q 'good.jpg' "$t3/lint-report.md"; then
  echo "PASS case3"
else
  echo "FAIL case3"; fail=1
fi

# Case 4: a page without a `> summary` line under the title is flagged; one with it is not.
t4="$(mktemp -d)"; git -C "$t4" init -q
mkdir -p "$t4/wiki/mcp"
printf '# Auth\n\n> How tokens flow.\n\nbody\n' > "$t4/wiki/mcp/auth.md"
printf '# Transport\n\nbody\n' > "$t4/wiki/mcp/transport.md"
( cd "$t4" && CLAUDE_PROJECT_DIR="$t4" bash "$LINT" >/dev/null 2>&1 )
section="$(sed -n '/^## 6\. Missing Summaries/,/^---$/p' "$t4/lint-report.md")"
if grep -qF '`mcp/transport`' <<<"$section" && ! grep -qF '`mcp/auth`' <<<"$section"; then
  echo "PASS case4"
else
  echo "FAIL case4"; fail=1
fi

rm -rf "$t1" "$t2" "$t3" "$t4"
exit $fail
