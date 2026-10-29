#!/bin/bash
# Wiki Lint — Programmatic Layer
# Checks: ghost links, orphan pages, format violations, outdated markers, ghost image embeds,
# missing summaries.
# Output: lint-report.md at repo root.

ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -d "$ROOT/wiki" ] || exit 0      # not a wiki project -> no-op silently
WIKI_DIR="$ROOT/wiki"
REPORT="$ROOT/lint-report.md"
ERRORS=0
WARNINGS=0

echo "# Wiki Lint Report" > "$REPORT"
echo "" >> "$REPORT"
echo "> Generated: $(date '+%Y-%m-%d %H:%M')" >> "$REPORT"
echo "" >> "$REPORT"

# Collect wiki slugs as <branch>/<page>, mirroring wiki/<branch>/<page>.md.
declare -A SLUGS
while IFS= read -r f; do
  rel="${f#$WIKI_DIR/}"
  slug="${rel%.md}"
  base="$(basename "$slug")"
  case "$base" in
    _template|README) continue ;;
  esac
  SLUGS["$slug"]=1
done < <(find "$WIKI_DIR" -type f -name '*.md')

# ─── 1. Ghost Links ───
echo "## 1. Ghost Links (links pointing to non-existent pages)" >> "$REPORT"
echo "" >> "$REPORT"
FOUND_GHOST=0

for slug in "${!SLUGS[@]}"; do
  f="$WIKI_DIR/$slug.md"
  while IFS= read -r link; do
    target="${link%%|*}"
    if [[ -z "${SLUGS[$target]}" ]]; then
      echo "- \`$slug\` → \`[[$target]]\` (not found)" >> "$REPORT"
      FOUND_GHOST=1
      ((ERRORS++))
    fi
  done < <(grep -o '\[\[[^]]*\]\]' "$f" 2>/dev/null | sed 's/^\[\[//;s/\]\]$//')
done

if [ $FOUND_GHOST -eq 0 ]; then
  echo "None." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 2. Orphan Pages ───
echo "## 2. Orphan Pages (no incoming links from other wiki pages)" >> "$REPORT"
echo "" >> "$REPORT"
FOUND_ORPHAN=0

declare -A INCOMING
for slug in "${!SLUGS[@]}"; do
  INCOMING["$slug"]=0
done

for slug in "${!SLUGS[@]}"; do
  f="$WIKI_DIR/$slug.md"
  while IFS= read -r link; do
    target="${link%%|*}"
    if [[ -n "${SLUGS[$target]}" ]]; then
      INCOMING["$target"]=$(( ${INCOMING[$target]:-0} + 1 ))
    fi
  done < <(grep -o '\[\[[^]]*\]\]' "$f" 2>/dev/null | sed 's/^\[\[//;s/\]\]$//')
done

for slug in $(echo "${!SLUGS[@]}" | tr ' ' '\n' | sort); do
  if [[ "${INCOMING[$slug]}" == "0" ]]; then
    echo "- \`$slug\`" >> "$REPORT"
    FOUND_ORPHAN=1
    ((WARNINGS++))
  fi
done

if [ $FOUND_ORPHAN -eq 0 ]; then
  echo "None." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 3. Format Violations ───
echo "## 3. Format Violations" >> "$REPORT"
echo "" >> "$REPORT"
FOUND_FORMAT=0

for slug in "${!SLUGS[@]}"; do
  f="$WIKI_DIR/$slug.md"

  # 3a. First line must be `# title`
  first_line=$(head -1 "$f")
  if [[ ! "$first_line" =~ ^#\  ]]; then
    echo "- \`$slug\`: first line is not \`# title\` → \`$first_line\`" >> "$REPORT"
    FOUND_FORMAT=1
    ((ERRORS++))
  fi

  # 3b. Path components must be lowercase with hyphens only
  if [[ "$slug" =~ [A-Z_] ]]; then
    echo "- \`$slug\`: path contains uppercase or underscore" >> "$REPORT"
    FOUND_FORMAT=1
    ((ERRORS++))
  fi

  # 3c. Wiki page must live in a branch subfolder (slug must contain at least one /)
  if [[ "$slug" != */* ]]; then
    echo "- \`$slug\`: wiki page must live in a branch subfolder (wiki/<branch>/<slug>.md)" >> "$REPORT"
    FOUND_FORMAT=1
    ((ERRORS++))
  fi
done

if [ $FOUND_FORMAT -eq 0 ]; then
  echo "None." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 4. Outdated Markers ───
# Tight patterns only — flag temporal claims tied to specific versions/release events
# that are likely to expire. Generic rhetorical "currently"/"now" is intentionally excluded.
echo "## 4. Outdated Markers (time-sensitive language)" >> "$REPORT"
echo "" >> "$REPORT"
FOUND_OUTDATED=0

PATTERNS='currently v[0-9]|latest v[0-9]|just released|recently released|brand new|newly released'

for slug in "${!SLUGS[@]}"; do
  f="$WIKI_DIR/$slug.md"
  matches=$(grep -nE "$PATTERNS" "$f" 2>/dev/null)
  if [ -n "$matches" ]; then
    echo "### \`$slug\`" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo "$matches" >> "$REPORT"
    echo '```' >> "$REPORT"
    FOUND_OUTDATED=1
    ((WARNINGS++))
  fi
done

if [ $FOUND_OUTDATED -eq 0 ]; then
  echo "None." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 5. Ghost Image Embeds ───
# Every ![...](path) in atoms/ and wiki/ must resolve to an existing file
# relative to the markdown file's directory. External URLs are not checked.
echo "## 5. Ghost Image Embeds (image paths that do not resolve)" >> "$REPORT"
echo "" >> "$REPORT"
FOUND_GHOST_IMG=0

while IFS= read -r f; do
  case "$(basename "$f")" in
    _template.md|README.md) continue ;;
  esac
  dir="$(dirname "$f")"
  rel="${f#$ROOT/}"
  while IFS= read -r path; do
    path="${path%% *}"   # drop optional markdown title after the path
    case "$path" in
      http://*|https://*|data:*) continue ;;
    esac
    if [ ! -f "$dir/$path" ]; then
      echo "- \`$rel\` → \`$path\` (missing)" >> "$REPORT"
      FOUND_GHOST_IMG=1
      ((ERRORS++))
    fi
  done < <(grep -o '!\[[^]]*\]([^)]*)' "$f" 2>/dev/null | sed 's/^!\[[^]]*\](//;s/)$//')
done < <(find "$ROOT/atoms" "$WIKI_DIR" -type f -name '*.md' 2>/dev/null)

if [ $FOUND_GHOST_IMG -eq 0 ]; then
  echo "None." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 6. Missing Summaries ───
# The first non-blank line after the title must be a `> summary` blockquote —
# gen-index.sh copies it into index.md so pages can be picked without opening them.
echo "## 6. Missing Summaries (no \`> summary\` line under the title)" >> "$REPORT"
echo "" >> "$REPORT"
FOUND_NO_SUMMARY=0

for slug in $(echo "${!SLUGS[@]}" | tr ' ' '\n' | sort); do
  f="$WIKI_DIR/$slug.md"
  if ! awk 'NR==1{next} /^[[:space:]]*$/{next} {found = /^> ?[^[:space:]]/; exit} END{exit !found}' "$f"; then
    echo "- \`$slug\`" >> "$REPORT"
    FOUND_NO_SUMMARY=1
    ((WARNINGS++))
  fi
done

if [ $FOUND_NO_SUMMARY -eq 0 ]; then
  echo "None." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── Summary ───
echo "---" >> "$REPORT"
echo "" >> "$REPORT"
echo "**Summary**: $ERRORS errors, $WARNINGS warnings across ${#SLUGS[@]} wiki pages" >> "$REPORT"

echo "Lint complete: $ERRORS errors, $WARNINGS warnings. Report: $REPORT"
