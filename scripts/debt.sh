#!/bin/bash
# Compile debt: what the wiki pages do not yet say that the atoms do.
# Prints one line per item, sorted:
#   uncompiled <atom id>            no page footer names the atom
#   stale <atom id> <page slug>     the footer names an older version of the atom
#   gone <atom id> <page slug>      the footer names an atom that no longer exists
# A footer entry is `<atom id>@<version>`; without `@<version>` it counts as version 1.
# With --count: prints only the number of lines.
# No LLM needed. Exit 0 always; no output outside a wiki project.

ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -d "$ROOT/wiki" ] && [ -d "$ROOT/atoms" ] || exit 0
cd "$ROOT" || exit 0

LIST="$(
  {
    # F <atom file>
    find atoms -type f -name '*.md' ! -name '_template.md' ! -name 'README.md' | sed 's/^/F\t/'
    # V <atom file> <version>   (one awk for all atoms: a process per file is slow on Windows)
    find atoms -type f -name '*.md' ! -name '_template.md' ! -name 'README.md' -print0 |
      xargs -0 awk '/^version:[[:space:]]*[0-9]+/ && !(FILENAME in seen) { seen[FILENAME] = 1; print "V\t" FILENAME "\t" $2 }' /dev/null
    # P <page file>:<footer line>
    grep -rH --include='*.md' --exclude='_template.md' --exclude='README.md' '^\*Compiled from atoms:' wiki 2>/dev/null |
      sed 's/^/P\t/'
  } | awk -F '\t' '
    function atom_id(path) { sub(/^atoms\//, "", path); sub(/\.md$/, "", path); return path }
    $1 == "F" { exists[atom_id($2)] = 1 }
    $1 == "V" { version[atom_id($2)] = $3 + 0 }
    $1 == "P" {
      marker = ":*Compiled from atoms:"
      at = index($2, marker)
      page = substr($2, 1, at - 1); sub(/^wiki\//, "", page); sub(/\.md$/, "", page)
      rest = substr($2, at + length(marker))
      gsub(/[*`\r]/, "", rest)
      count = split(rest, entries, ",")
      for (i = 1; i <= count; i++) {
        entry = entries[i]; gsub(/^[ \t]+|[ \t]+$/, "", entry)
        if (entry == "" || entry == "...") continue
        seen_version = 1
        cut = index(entry, "@")
        if (cut > 0) { seen_version = substr(entry, cut + 1) + 0; entry = substr(entry, 1, cut - 1) }
        compiled[entry] = 1
        refs++; ref_atom[refs] = entry; ref_page[refs] = page; ref_version[refs] = seen_version
      }
    }
    END {
      for (i = 1; i <= refs; i++) {
        id = ref_atom[i]
        if (!(id in exists)) { print "gone " id " " ref_page[i]; continue }
        current = (id in version) ? version[id] : 1
        if (ref_version[i] < current) print "stale " id " " ref_page[i]
      }
      for (id in exists) if (!(id in compiled)) print "uncompiled " id
    }
  ' | LC_ALL=C sort
)"

if [ "$1" = "--count" ]; then
  if [ -z "$LIST" ]; then echo 0; else printf '%s\n' "$LIST" | wc -l | tr -d ' '; fi
elif [ -n "$LIST" ]; then
  printf '%s\n' "$LIST"
fi
exit 0
