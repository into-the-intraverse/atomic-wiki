#!/bin/bash
# Auto-generate index.md from wiki/<branch>/<page>.md filenames + first-line titles.
# No LLM needed — pure filesystem scan.
#
# Branches are auto-discovered from the subfolders of wiki/. To control order or
# display names (e.g. "MCP" instead of "Mcp"), edit the BRANCHES override below.

WIKI_DIR="$(cd "$(dirname "$0")/../wiki" && pwd)"
INDEX="$WIKI_DIR/../index.md"

# ─── Branch order and display names ───
# Format: "branch-folder|Display Name". Leave empty for auto-discovery.
declare -a BRANCHES=()

# ─── Auto-discover branches if not overridden ───
if [ ${#BRANCHES[@]} -eq 0 ]; then
  for d in "$WIKI_DIR"/*/; do
    [ -d "$d" ] || continue
    branch=$(basename "$d")
    display=$(echo "$branch" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    BRANCHES+=("$branch|$display")
  done
  IFS=$'\n' BRANCHES=($(sort <<<"${BRANCHES[*]}"))
  unset IFS
fi

# ─── Count pages ───
PAGE_COUNT=0
for entry in "${BRANCHES[@]}"; do
  PREFIX="${entry%%|*}"
  for f in "$WIKI_DIR/$PREFIX"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md)
    [[ "$base" == "_template" || "$base" == "README" ]] && continue
    ((PAGE_COUNT++))
  done
done

# ─── Write header ───
echo "# Wiki Index" > "$INDEX"
echo "" >> "$INDEX"
echo "> Total pages: $PAGE_COUNT" >> "$INDEX"
echo "> Auto-generated: $(date '+%Y-%m-%d %H:%M')" >> "$INDEX"
echo "" >> "$INDEX"
echo "---" >> "$INDEX"
echo "" >> "$INDEX"

# ─── Write branches ───
for entry in "${BRANCHES[@]}"; do
  PREFIX="${entry%%|*}"
  DISPLAY="${entry##*|}"

  FILES=()
  for f in "$WIKI_DIR/$PREFIX"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md)
    [[ "$base" == "_template" || "$base" == "README" ]] && continue
    FILES+=("$f")
  done

  [ ${#FILES[@]} -eq 0 ] && continue

  echo "## $DISPLAY (${#FILES[@]} pages)" >> "$INDEX"
  echo "" >> "$INDEX"
  echo "| Slug | Title |" >> "$INDEX"
  echo "|------|-------|" >> "$INDEX"

  for f in $(printf '%s\n' "${FILES[@]}" | sort); do
    base=$(basename "$f" .md)
    slug="$PREFIX/$base"
    title=$(head -1 "$f" | sed 's/^# //')
    echo "| [[$slug]] | $title |" >> "$INDEX"
  done

  echo "" >> "$INDEX"
done

echo "Index generated: $PAGE_COUNT pages → $INDEX"
