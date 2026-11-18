#!/bin/bash
# Stop hook: run the lint, then send Claude back to compile when enough atoms wait for a page.
# Reads the hook payload on stdin. Prints hook JSON on stdout, or nothing to let Claude stop.

THRESHOLD=8   # compile debt (lines of debt.sh) that starts an automatic compile
BULK=40       # above this the backlog is too large for the end of a turn: tell the user instead

DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$(cat)"

bash "$DIR/lint.sh" >/dev/null 2>&1

# Claude is already continuing because a stop hook asked: never ask twice in one turn.
case "$PAYLOAD" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac

ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
DEBT="$(bash "$DIR/debt.sh")"
[ -n "$DEBT" ] || exit 0
COUNT="$(printf '%s\n' "$DEBT" | wc -l | tr -d ' ')"
[ "$COUNT" -ge "$THRESHOLD" ] || exit 0

# Ask once per debt state: atoms a compile pass could not place must not bring Claude back every turn.
STATE="$(cd "$ROOT" && git rev-parse --git-path atomic-wiki-compile-debt)"
case "$STATE" in /*|[A-Za-z]:*) ;; *) STATE="$ROOT/$STATE" ;; esac
SIGNATURE="$(printf '%s\n' "$DEBT" | cksum)"
[ "$(cat "$STATE" 2>/dev/null)" = "$SIGNATURE" ] && exit 0
printf '%s\n' "$SIGNATURE" > "$STATE" 2>/dev/null

if [ "$COUNT" -gt "$BULK" ]; then
  printf '{"systemMessage":"atomic-wiki: %s atoms are not compiled into wiki pages. That is too many for an automatic pass; run /atomic-wiki:compile pending when you have time for it."}\n' "$COUNT"
else
  printf '{"decision":"block","reason":"atomic-wiki: %s atoms are not compiled into wiki pages (the list is section 7 of lint-report.md). Run the atomic-wiki:compile skill in pending mode now, then give the user its report."}\n' "$COUNT"
fi
exit 0
