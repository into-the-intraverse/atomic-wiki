---
name: ingest
description: Extract knowledge atoms from raw source material. Use when the user runs /ingest, or when new files appear in raw/ and the user asks you to process them.
---

# Ingest

Read raw material from `raw/` (or any path the user names), classify each segment as `extract` / `skip` / `deferred`, and write the `extract` segments as atoms under `atoms/<branch>/`.

## When to use

- User runs `/ingest <file-or-folder>`.
- User drops new material into `raw/` and asks you to process it.
- During the lifecycle of any operation that produces new knowledge worth retaining (e.g., a Query that surfaces a synthesis the user wants captured).

## Procedure

1. **Read the source.** Treat `raw/` as read-only. Never write back into it.
2. **Classify each segment.** Per segment, mark:
   - **extract** — contains a knowledge point, view, experience, or method that stands alone. Even out of original context, this segment has teaching or reference value.
   - **skip** — pure social interaction, restating others' views, filler agreement, action items, pure emotion.
   - **deferred** — potentially valuable but uncertain, or requires surrounding context to understand. Skip in the first pass; revisit after the full batch.
3. **Extract atoms.** For each `extract` segment:
   - One atom equals one claim. If a passage contains two views, and removing one leaves the other intact, split into two atoms.
   - Refine, don't copy. Strip filler from the source; preserve the author's voice and stance.
   - Place atoms under the matching `atoms/<branch>/` folder.
   - If no branch fits, list the segment as a deferred candidate and surface it to the user. **Do not invent branches without user approval.**
4. **Write the atom file.** Use the frontmatter format below. New atoms get `version: 1`.

## Atom frontmatter

```yaml
---
id: <branch>/<descriptive-slug>
type: explanation | opinion | tutorial | myth-busting | case-study | comparison
depth: beginner | intermediate | advanced
source_type: post | reply | thread | transcript | article | note | screenshot | audio
source_ids: ["<stable-id-or-url>"]
reuse_score: high | medium | low
tags: []
version: 1
---
```

## Filename

`atoms/<branch>/<slug>.md` — all lowercase, hyphens only, 3–6 words. No date prefix. Slug must be unique within the branch and must match the `id:` field.

## Constraints

- One atom equals one claim.
- Use the frontmatter format above. Do not invent fields.
- Preserve the author's voice. Personal knowledge base, not neutral encyclopedia.
- Tag sources via `source_ids` — atoms without source attribution are not auditable.
- If a passage doesn't pass the "extract" bar (pure action items, unannotated news restatement, time-sensitive ephemera, pure emotion), skip it.

## After ingest

- Surface to the user: how many atoms extracted, which branches received them, any deferred candidates, any segments that didn't fit existing branches.
- The user decides whether deferred candidates get extracted later or whether new branches should be approved.
- Commit when the user is satisfied. The pre-commit hook will enforce `version: 1` on new atoms.

See `CLAUDE.md` and `METHODOLOGY.md` (Phase 2 + Phase 3) for the full reasoning.
