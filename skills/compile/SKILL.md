---
name: compile
description: Group related atoms into a wiki page. Use when the user runs /atomic-wiki:compile, when enough new atoms have accumulated in a branch to warrant compiling them, or when the Stop hook or `lint-report.md` reports compile debt (atoms in no page, pages older than their atoms).
---

# Compile

Take a set of related atoms from `atoms/<branch>/` and produce a wiki page at `wiki/<branch>/<topic-slug>.md` that synthesizes them as coherent prose.

## When to use

- User runs `/atomic-wiki:compile <branch>` or `/atomic-wiki:compile <branch> <slug>`.
- A branch has accumulated 3–8 new atoms on a coherent subtopic.
- An existing wiki page needs to be rebuilt because one of its source atoms changed (look at the footer `*Compiled from atoms: ...*` line).
- The Stop hook sent you back with "atoms are not compiled into wiki pages", or the user runs `/atomic-wiki:compile pending`: follow **Pending mode** below.

## Procedure

1. **Pick the scope.** Either the user specifies the slug(s), or you propose a grouping: "these 5 atoms cluster around X, want me to compile them into `wiki/<branch>/<slug>.md`?"
2. **Confirm slug naming.** Filename pattern: `wiki/<branch>/<topic-slug>.md`, all lowercase, hyphens only. The folder carries the branch name — **do not repeat the branch in the slug** (`wiki/mcp/auth.md`, not `wiki/mcp/mcp-auth.md`).
3. **Synthesize.** Don't dump atoms one per section. Group by what a reader wants to understand. Write coherent prose. Preserve the original voice — wiki is opinionated knowledge, not encyclopedia.
4. **Write the summary line.** Directly under the title: `> <one sentence>`. The sentence names what the page covers, in the terms someone would use when asking about it — e.g. `> How MCP servers authenticate clients: OAuth flow, token storage, refresh.` `gen-index.sh` copies it into `index.md`, and `/atomic-wiki:query` picks pages by it without opening them.
5. **Cross-reference.** First mention of a related concept links to its page: `[[branch/slug]]`. The path must equal an existing wiki page (relative to `wiki/`, no `.md`). Subsequent mentions in the same page don't repeat the link.
6. **Carry image embeds.** When a source atom anchors its claim with an embedded image, carry the `![...](../../raw/...)` embed into the page next to the prose that uses it. Wiki pages sit at the same depth as atoms, so the path works verbatim. Don't repeat an image already embedded earlier on the same page.
7. **Use temporal markers correctly.** Specific dates (`as of 2026-04`) or version numbers (`v3.5`). Avoid bare `currently` / `latest` / `now` in time-sensitive contexts.
8. **Footer source list.** End with `*Compiled from atoms: branch/atom-a@2, branch/atom-b@1, ...*`: every atom the page was written from, each with the `version:` it had when you read it. `debt.sh` compares these with the atoms, so a missing atom or an old version shows up as compile debt.

## Wiki page structure

```markdown
# Page Title

> One sentence: what this page covers, in the terms someone would ask about it.

Opening paragraph: why this matters, common misconception, what the reader will get.

## Section
Integrated content from multiple atoms, coherent prose. First mention of a
related concept gets a [[branch/wiki-link]].

## Section
Continue.

---

**See also**
- [[other-branch/related-page]] — one-line description

---
*Compiled from atoms: branch/atom-slug-1@1, branch/atom-slug-2@3, ...*
```

## Pending mode

Pending mode clears the compile debt without asking the user anything: no grouping proposals, no slug confirmation. Steps 3–8 of the procedure still apply to every page you write.

1. **List the debt.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/debt.sh"`. Each line is one of:

   | Line | Meaning | What to do |
   |---|---|---|
   | `stale <atom> <page>` | the atom changed after the page was compiled | Re-read the page's atoms and rewrite the parts the atom touches. |
   | `gone <atom> <page>` | the page lists an atom that was deleted | Remove what came from it; drop it from the footer. |
   | `uncompiled <atom>` | no page was compiled from the atom | Place it (step 2). |

2. **Place every uncompiled atom.** Read `index.md` and the atom. In this order:
   - a page of the same branch already covers its topic → work the atom into that page;
   - other uncompiled atoms share its topic → compile them together into a new page;
   - neither → add it to the nearest page of its branch as its own section. Create a new page for a single atom only when the branch has no page yet.

   Every atom on the list ends up in a footer. The length targets below do not apply in pending mode: a short page beats an atom nobody finds.
3. **Touch only the pages the list names** and the new pages. Leave the rest of the wiki alone.
4. **Update each footer** with every atom's current `version:`.
5. **Check.** Run `debt.sh` again. It must print nothing. A line still there means a footer misses an atom or carries an old version: fix the footer or the page.
6. **Report to the user**, in this order:
   - contradictions between atoms you met while compiling (atom ids and the two claims) — these need the user's decision; write both claims into the page as a disagreement and do not pick one;
   - atoms you placed in a page that fits them poorly (a missing topic or branch);
   - new pages (slug and summary line);
   - how many existing pages you updated.

## Length

- Target 1500–2500 words per page.
- Past 2500 words: consider splitting.
- Below 800 words: consider merging or staying at atom level.

## Parallel compile: slug-lock procedure

When compiling multiple pages in parallel (multiple agents or one agent across multiple branches):

1. **A coordinator pre-locks the slug list per branch first.** This is a flat list, e.g., `mcp/auth`, `mcp/transport`, `mcp/tools`.
2. **Each agent is assigned slugs to fill.** Agents never name files.
3. **Each agent writes only into its assigned slugs.**

Without a slug lock, parallel agents will invent different filenames for overlapping content (`mcp-plus-skills.md` vs `mcp-plus-skills-architecture.md`).

## Constraints

- Group by topic, not one atom per page. Typical wiki page = 3–8 atoms.
- Filename `wiki/<branch>/<topic-slug>.md`, all lowercase, hyphens only, no branch prefix in the slug.
- First line must be `# title`; the first non-blank line after it is the `> summary` line.
- Use `[[branch/slug]]` for cross-references. The path inside `[[ ]]` must equal an existing wiki page.
- Image embeds keep the `../../raw/...` paths from their atoms; lint flags embeds whose file is missing.
- Footer lists source atoms as `id@version`.

## After compile

After writing or updating wiki pages, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gen-index.sh"
```

This regenerates `index.md` (belt-and-suspenders — the **atomic-wiki plugin** also ships a `PostToolUse` hook that rebuilds `index.md` when you write a `wiki/` file, and a `Stop` hook that runs the lint). Commit when ready.

If a wiki page is wrong because the underlying atom is wrong, fix the atom and recompile — never patch the wiki directly. The atom is truth; the wiki is a derived cache.

See `${CLAUDE_PLUGIN_ROOT}/reference/SCHEMA.md` and `${CLAUDE_PLUGIN_ROOT}/METHODOLOGY.md` (Phase 6) for the full reasoning.
