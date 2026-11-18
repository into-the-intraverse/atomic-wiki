#!/bin/bash
# Verifies stop-hook.sh sends Claude back to compile once debt reaches the threshold, and only once per debt state.
set -u
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_DIR/scripts/stop-hook.sh"
fail=0

project() { # project <atom count> -> path of a wiki project with that many uncompiled atoms
  local t; t="$(mktemp -d)"; git -C "$t" init -q; mkdir -p "$t/wiki/mcp" "$t/atoms/mcp"
  local i; for i in $(seq 1 "$1"); do
    printf -- '---\nid: mcp/a%s\nversion: 1\n---\n\nClaim.\n' "$i" > "$t/atoms/mcp/a$i.md"
  done
  echo "$t"
}
hook() { ( cd "$1" && printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null ); }
IDLE='{"hook_event_name":"Stop","stop_hook_active":false}'
ACTIVE='{"hook_event_name":"Stop","stop_hook_active":true}'

# Case 1: below the threshold -> no output, lint report still written.
t1="$(project 7)"; out="$(hook "$t1" "$IDLE")"
if [ -z "$out" ] && [ -f "$t1/lint-report.md" ]; then echo "PASS case1"; else echo "FAIL case1: $out"; fail=1; fi

# Case 2: at the threshold -> block with the count; the same debt does not block twice.
t2="$(project 8)"; out="$(hook "$t2" "$IDLE")"; again="$(hook "$t2" "$IDLE")"
if grep -q '"decision":"block"' <<<"$out" && grep -q '8 atoms' <<<"$out" && [ -z "$again" ]; then
  echo "PASS case2"
else
  echo "FAIL case2: $out / $again"; fail=1
fi

# Case 3: debt that changed since the last block blocks again.
printf -- '---\nid: mcp/b\nversion: 1\n---\n\nClaim.\n' > "$t2/atoms/mcp/b.md"
out="$(hook "$t2" "$IDLE")"
if grep -q '"decision":"block"' <<<"$out" && grep -q '9 atoms' <<<"$out"; then echo "PASS case3"; else echo "FAIL case3: $out"; fail=1; fi

# Case 4: while Claude is already continuing from a stop hook -> never block.
t4="$(project 12)"; out="$(hook "$t4" "$ACTIVE")"
if [ -z "$out" ]; then echo "PASS case4"; else echo "FAIL case4: $out"; fail=1; fi

# Case 5: a backlog too large for one pass -> tell the user, do not block.
t5="$(project 41)"; out="$(hook "$t5" "$IDLE")"
if grep -q '"systemMessage"' <<<"$out" && ! grep -q '"decision"' <<<"$out" && grep -q '41 atoms' <<<"$out"; then
  echo "PASS case5"
else
  echo "FAIL case5: $out"; fail=1
fi

# Case 6: not a wiki project -> no output, exit 0.
t6="$(mktemp -d)"; git -C "$t6" init -q; out="$(hook "$t6" "$IDLE")"; rc=$?
if [ -z "$out" ] && [ $rc -eq 0 ]; then echo "PASS case6"; else echo "FAIL case6: $out rc=$rc"; fail=1; fi

# Case 7: the state file stays out of the work tree.
if [ -z "$(git -C "$t2" status --porcelain -- . ':!atoms' ':!wiki' ':!lint-report.md')" ]; then echo "PASS case7"; else echo "FAIL case7"; fail=1; fi

rm -rf "$t1" "$t2" "$t4" "$t5" "$t6"
exit $fail
