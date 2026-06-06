---
name: compile
description: Group related atoms into a wiki page. Use when the user runs /atomic-wiki:compile, or when enough new atoms have accumulated in a branch to warrant compiling them.
---

# Compile

Take a set of related atoms from `atoms/<branch>/` and produce a wiki page at `wiki/<branch>/<topic-slug>.md` that synthesizes them as coherent prose.

## When to use

- User runs `/atomic-wiki:compile <branch>` or `/atomic-wiki:compile <branch> <slug>`.
- A branch has accumulated 3–8 new atoms on a coherent subtopic.
- An existing wiki page needs to be rebuilt because one of its source atoms changed (look at the footer `*Compiled from atoms: ...*` line).

## Procedure

1. **Pick the scope.** Either the user specifies the slug(s), or you propose a grouping: "these 5 atoms cluster around X, want me to compile them into `wiki/<branch>/<slug>.md`?"
2. **Confirm slug naming.** Filename pattern: `wiki/<branch>/<topic-slug>.md`, all lowercase, hyphens only. The folder carries the branch name — **do not repeat the branch in the slug** (`wiki/mcp/auth.md`, not `wiki/mcp/mcp-auth.md`).
3. **Synthesize.** Don't dump atoms one per section. Group by what a reader wants to understand. Write coherent prose. Preserve the original voice — wiki is opinionated knowledge, not encyclopedia.
4. **Cross-reference.** First mention of a related concept links to its page: `[[branch/slug]]`. The path must equal an existing wiki page (relative to `wiki/`, no `.md`). Subsequent mentions in the same page don't repeat the link.
5. **Use temporal markers correctly.** Specific dates (`as of 2026-04`) or version numbers (`v3.5`). Avoid bare `currently` / `latest` / `now` in time-sensitive contexts.
6. **Footer source list.** End with `*Compiled from atoms: branch/atom-a, branch/atom-b, ...*` so the page is traceable.

## Wiki page structure

```markdown
# Page Title

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
*Compiled from atoms: branch/atom-slug-1, branch/atom-slug-2, ...*
```

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
- First line must be `# title`.
- Use `[[branch/slug]]` for cross-references. The path inside `[[ ]]` must equal an existing wiki page.
- Footer lists source atoms by id.

## After compile

After writing or updating wiki pages, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gen-index.sh"
```

This regenerates `index.md` (belt-and-suspenders — the **atomic-wiki plugin** also ships a `PostToolUse` hook that rebuilds `index.md` when you write a `wiki/` file, and a `Stop` hook that runs the lint). Commit when ready.

If a wiki page is wrong because the underlying atom is wrong, fix the atom and recompile — never patch the wiki directly. The atom is truth; the wiki is a derived cache.

See `${CLAUDE_PLUGIN_ROOT}/reference/SCHEMA.md` and `${CLAUDE_PLUGIN_ROOT}/METHODOLOGY.md` (Phase 6) for the full reasoning.
