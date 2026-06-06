---
name: query
description: Answer a question by reading the wiki. Use when the user runs /atomic-wiki:query, or asks a question that should be answered from compiled knowledge rather than from raw or from the model's own priors.
---

# Query

Answer the user's question by reading `index.md`, loading only the relevant wiki pages, and synthesizing. Do not read the whole wiki by default. Do not touch `raw/` unless explicitly asked.

## When to use

- User runs `/atomic-wiki:query <question>`.
- User asks any question that could plausibly be answered from the wiki (the compiled knowledge base is the first place to look, not the last).

## Procedure

1. **Read `index.md`.** This is the navigation layer — branch headers + page slugs + one-line titles. It is small; reading it costs little.
2. **Locate relevant pages.** Pick 1–5 pages from the index that look like they cover the topic. Err on the side of fewer pages — you can always load more.
3. **Read the selected pages.** Follow `[[branch/slug]]` cross-references when one page points to another that's clearly relevant.
4. **Synthesize the answer.** Cite which pages you drew from. Distinguish:
   - **"This is in the wiki"** — direct quote or close paraphrase from a page.
   - **"This is my synthesis on top of the wiki"** — connecting points across pages, or inferring beyond what's written.
5. **Offer to write back.** If the synthesis produced a new claim worth retaining, propose:
   - Writing it as a new atom (and recompiling the affected wiki page), OR
   - Editing an existing atom and bumping `version:`.

   Don't write back without confirmation — the user owns the editorial voice.

## Constraints

- **Do not load the entire wiki by default.** The whole point of `index.md` is to scope the read.
- **Do not search `raw/`.** Raw is for `/atomic-wiki:ingest`, not for `/atomic-wiki:query`. If a page is missing knowledge that exists in raw, the answer is to run `/atomic-wiki:ingest`, not to bypass the wiki.
- **Cite pages.** Every claim in the answer traces to a page slug, or is explicitly marked as synthesis.
- **Respect the wiki's stance.** If two pages disagree, surface the disagreement (and flag it as a candidate Lint finding) rather than picking one silently.

## After the query

If the user accepts a write-back:
- New atom → `version: 1`, place under the right branch.
- Edited atom → bump `version:`, the pre-commit hook will enforce it.
- Recompile any affected wiki page.

The **atomic-wiki plugin** ships a `PostToolUse` hook that auto-rebuilds the index and a `Stop` hook that auto-lints.

See `${CLAUDE_PLUGIN_ROOT}/reference/SCHEMA.md` for the full spec.
