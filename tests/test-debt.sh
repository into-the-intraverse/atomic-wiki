#!/bin/bash
# Verifies debt.sh lists atoms no page was compiled from, and pages compiled from an older or deleted atom.
set -u
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEBT="$PLUGIN_DIR/scripts/debt.sh"
fail=0

atom() { # atom <root> <branch/slug> <version>
  mkdir -p "$1/atoms/$(dirname "$2")"
  printf -- '---\nid: %s\ntype: explanation\nversion: %s\n---\n\nClaim.\n' "$2" "$3" > "$1/atoms/$2.md"
}
page() { # page <root> <branch/slug> <footer atom list>
  mkdir -p "$1/wiki/$(dirname "$2")"
  printf '# T\n\n> s\n\nbody\n\n---\n*Compiled from atoms: %s*\n' "$3" > "$1/wiki/$2.md"
}
run() { ( cd "$1" && CLAUDE_PROJECT_DIR="$1" bash "$DEBT" "${@:2}" 2>&1 ); }

# Case 1: atoms in no footer are uncompiled; templates and README are not atoms.
t1="$(mktemp -d)"; git -C "$t1" init -q
atom "$t1" mcp/auth 1; atom "$t1" mcp/tokens 1; atom "$t1" mcp/transport 1
printf 'template\n' > "$t1/atoms/_template.md"; printf 'readme\n' > "$t1/atoms/mcp/README.md"
page "$t1" mcp/auth 'mcp/auth@1, `mcp/tokens@1`'
printf '# T\n\n---\n*Compiled from atoms: `branch/atom-slug-1`*\n' > "$t1/wiki/_template.md"
out="$(run "$t1")"
if [ "$out" = "uncompiled mcp/transport" ]; then echo "PASS case1"; else echo "FAIL case1: $out"; fail=1; fi

# Case 2: a footer version below the atom's version is stale; no @version counts as version 1.
t2="$(mktemp -d)"; git -C "$t2" init -q
atom "$t2" mcp/auth 3; atom "$t2" mcp/tokens 2; atom "$t2" mcp/transport 1
page "$t2" mcp/auth 'mcp/auth@2, mcp/tokens, mcp/transport'
out="$(run "$t2")"
want=$'stale mcp/auth mcp/auth\nstale mcp/tokens mcp/auth'
if [ "$out" = "$want" ]; then echo "PASS case2"; else echo "FAIL case2: $out"; fail=1; fi

# Case 3: a footer naming an atom that no longer exists is reported as gone.
t3="$(mktemp -d)"; git -C "$t3" init -q
atom "$t3" mcp/auth 1
page "$t3" mcp/auth 'mcp/auth@1, mcp/deleted@1'
out="$(run "$t3")"
if [ "$out" = "gone mcp/deleted mcp/auth" ]; then echo "PASS case3"; else echo "FAIL case3: $out"; fail=1; fi

# Case 4: --count prints the number of lines; a clean wiki prints 0 and no list.
c2="$(run "$t2" --count)"
atom "$t3" mcp/x 1; rm "$t3/atoms/mcp/x.md"; page "$t3" mcp/auth 'mcp/auth@1'
c3="$(run "$t3" --count)"; l3="$(run "$t3")"
if [ "$c2" = "2" ] && [ "$c3" = "0" ] && [ -z "$l3" ]; then echo "PASS case4"; else echo "FAIL case4: $c2 / $c3 / $l3"; fail=1; fi

# Case 5: no wiki/ or no atoms/ -> no output, exit 0; also outside git.
t5="$(mktemp -d)"; git -C "$t5" init -q; mkdir -p "$t5/wiki/mcp"
t6="$(mktemp -d)"
o5="$(run "$t5")"; r5=$?; o6="$(run "$t6")"; r6=$?
if [ -z "$o5" ] && [ $r5 -eq 0 ] && [ -z "$o6" ] && [ $r6 -eq 0 ]; then echo "PASS case5"; else echo "FAIL case5: $o5 $r5 $o6 $r6"; fail=1; fi

# Case 6: an atom compiled into two pages is stale only in the page with the old version.
t7="$(mktemp -d)"; git -C "$t7" init -q
atom "$t7" mcp/auth 2
page "$t7" mcp/a 'mcp/auth@2'; page "$t7" mcp/b 'mcp/auth@1'
out="$(run "$t7")"
if [ "$out" = "stale mcp/auth mcp/b" ]; then echo "PASS case6"; else echo "FAIL case6: $out"; fail=1; fi

rm -rf "$t1" "$t2" "$t3" "$t5" "$t6" "$t7"
exit $fail
