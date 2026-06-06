# Methodology: Scattered Materials → Usable Knowledge

You have a pile of scattered content — posts, replies, lecture transcripts, notes, screenshots, audio — and you know there's value in it, but every time you need something you can't find it, and when you do find it you have to re-read to remember what it said.

This document records a battle-tested pipeline: **use AI to refine raw material of any format into structured knowledge atoms, then compile those atoms into readable, cross-referenced wiki pages.**

Not RAG. Not re-searching raw sources on every query. A one-time token investment to organize knowledge so future queries just read the wiki.

---

## The core claim: Compile > RAG (at personal-KB scale)

**The RAG problem**: every query has to re-search the raw material, re-understand it, re-assemble it. Tokens spent on repeated understanding, and results vary run to run.

**The compile approach**: spend tokens once to understand the raw material thoroughly, producing structured wiki pages. Subsequent queries just read the wiki, never touching the raw source. Knowledge becomes a persistent, compounded artifact rather than something regenerated each time.

### Conditions for this claim to hold

1. **Manageable knowledge volume** — around 100–200 wiki pages. Beyond that, LLMs struggle to use `index.md` effectively and you'll want a hybrid (wiki as primary structure + vector search for locating).
2. **Relatively stable knowledge** — you're building a cognitive map, not a newsfeed. Updates in days or weeks, not minutes.
3. **Single owner with a point of view** — personal knowledge with a consistent stance, not an aggregation of many voices.
4. **Quality over coverage** — 50 pages written tight beat 500 pages written shallow.

### Honest limitations

- No peer-reviewed benchmark comparing compile vs RAG. The evidence is "it feels good to use".
- Past a few hundred pages, pure wiki structure hits navigation bottlenecks. Pair with vector search for locating.
- Compile cost is non-trivial — first Ingest of a large corpus burns significant tokens. Marginal cost decreases after that.
- Knowledge goes stale. Lint is periodic, not one-shot.

---

## Why this fork diverges from upstream

Three deliberate simplifications, all leaning on git or the filesystem instead of duplicating that info inside files:

- **No date prefix in filenames.** Git tracks creation date better than a frozen prefix that drifts on rename (`git log --diff-filter=A --follow -- <file>`).
- **No `created:` / `updated:` frontmatter.** Obsidian Dataview can query `file.ctime` / `file.mtime` directly; git is authoritative for history. Frontmatter dates always drift.
- **Operations are provided by the atomic-wiki plugin as skills.** `/atomic-wiki:ingest`, `/atomic-wiki:compile`, `/atomic-wiki:lint`, `/atomic-wiki:query` are plugin skills; `gen-index.sh` and `lint.sh` run automatically via the plugin's hooks. The shell scripts remain the canonical implementation — skills/hooks are thin orchestration.

The `version:` integer and its pre-commit hook stay. The hook compares the staged file against `HEAD` ignoring whitespace and flips you off if the body changed without `version:` being bumped — this catches intent, not just diff. Git can't tell "I revised this view" from "I fixed a typo" on its own.

---

## Pipeline overview

```
Raw material (text in any format)
    ↓ Phase 1: design the classification structure
    ↓ Phase 2: segment classification (extract / skip / deferred)
    ↓ Phase 3: extract into knowledge atoms (one claim per atom)
Structured knowledge atoms
    ↓ Phase 4: quality pass (dedupe, reclassify, gap analysis)
    ↓ Phase 5: external verification + branch summaries
Verified atoms + branch summaries
    ↓ Phase 6: compile into wiki pages
Wiki pages (readable, cross-referenced)
    ↓ Continuous maintenance
Ingest new material / Query back-writes / Lint checks
```

Each phase can run independently. You can stop at atoms, or skip atoms and go straight to wiki. But going through the full pipeline produces the best result.

---

## Phase 1: Skeleton design

**Goal**: decide the topic tree — how your knowledge should be classified.

### Operation

1. List the topics your knowledge covers (doesn't need to be perfect — iterate).
2. Create one folder per topic ("branch") under `atoms/`.
3. Mirror with `wiki/<branch>/` so wiki pages have a home from day one.
4. Write a short note describing each branch's definition and boundary.

### Branch design principles

A good branch satisfies:
- **Independence** — can't fit cleanly into any existing branch.
- **Scale** — expected to hold 5+ knowledge points.
- **Clear boundaries** — you can articulate "what belongs, what doesn't".
- **Teaching independence** — could anchor at least 30 minutes of instruction on its own.

Common mistakes:
- Branches too fine (each holds only 2–3 atoms) → use tags instead.
- Branches too coarse (50+ atoms spanning three unrelated topics) → split.
- Boundaries blurry (>50% of atoms also tagged with another branch) → merge or redefine.

---

## Phase 2: Segment classification

**Goal**: scan raw material and mark each segment "extract" / "skip" / "deferred".

This is the quality gatekeeper. Skipping classification and extracting everything produces a flood of low-quality atoms, and cleanup costs more than prevention. Classify first, only extract what's worth extracting.

### Classification criteria

- **Extract** — contains a knowledge point, view, experience, or method that stands alone. Even out of original context, this segment has teaching or reference value.
- **Skip** — pure social interaction, restating others' views, filler agreement, action items ("tomorrow do X"), pure emotion.
- **Deferred** — potentially valuable but uncertain, or requires surrounding context to understand. Skip in the first pass; revisit after the full batch is classified.

Extraction rate varies wildly by source: published articles often filter 80–95%, social replies often filter 10–15% (most are noise). Calibrate against your own first batch — don't trust a generic table.

---

## Phase 3: Extract into atoms

**Goal**: turn "extract"-marked segments into standard-format knowledge atoms.

### What is a knowledge atom

A `.md` file with YAML frontmatter and a body containing one core claim. Academic framing: Atomic Fact Decomposition — decomposing composite information into the smallest independently verifiable units.

**Atoms are mutable but versioned.** When knowledge evolves (view changes, technology updates), edit the atom in place and bump the integer in `version:`. Git keeps the prior text — `git log -p atoms/<branch>/<file>.md` retrieves any earlier version. The pre-commit hook refuses commits where the body changed beyond whitespace without a version bump. There is no `_archive/` folder; that role is git's.

```yaml
---
id: branch/descriptive-slug
type: explanation | opinion | tutorial | myth-busting | case-study | comparison
depth: beginner | intermediate | advanced
source_type: post | transcript | article | note | screenshot | audio
source_ids: []
reuse_score: high | medium | low
tags: []
version: 1
---
```

### Extraction principles

1. **Extract, don't copy** — store refined knowledge, not pasted original.
2. **One atom, one claim** — a post with three independent views becomes three atoms.
3. **Preserve the author's voice** — personal knowledge differentiation comes from perspective; don't flatten into neutral encyclopedia prose.
4. **Tag sources** — every atom traces back to its raw source via `source_ids`.
5. **One atom belongs to one branch** — use tags for related topics.

### Judging "extract" vs "copy"

Same raw text, handled two ways:

**Raw** (note):
> Spent three hours debugging an agent and realized the system prompt was too long — the model was ignoring the second half. Splitting the prompt into three layers — role, task rules, current context — fixed it.

**Bad atom (copying)**:
```markdown
# Debug agent experience
Spent three hours debugging an agent and realized the system prompt was
too long — the model was ignoring the second half. Splitting into three
layers fixed it.
```
→ This just adds a title to the original. No refinement.

**Good atom (extraction)**:
```markdown
# Layered system prompts

Long system prompts cause models to ignore later instructions. The fix:
split the prompt into three layers.

1. **Role definition** — who you are, core responsibilities.
2. **Task rules** — operational constraints, quality bar.
3. **Current context** — task-specific information.

The benefit isn't just avoiding omission — each layer can be updated
independently. Role rarely changes; rules adjust occasionally; context
changes every time. Mixed together, any edit forces re-reviewing the whole
prompt.
```
→ Extracted the core knowledge, added an implicit insight (independent update), structured it.

### When to split one segment into multiple atoms

**Test**: if a passage contains two views, and removing one leaves the other intact — split. If the parts are incomplete alone (e.g. "the three layers are X, Y, Z"), don't split.

### What should not become an atom

- **Pure action items**: "Tomorrow update landing page" → todo, not knowledge.
- **Unannotated restatement**: "OpenAI released GPT-5" → news, unless paired with your analysis.
- **Over-time-sensitive content**: "Model X is currently strongest" → stale in three months, unless discussing evaluation methodology itself.
- **Pure emotion**: "Exhausting day but satisfying" → journal, not knowledge.

### Quality judgment

How to set `reuse_score`:
- **high** — standalone-usable in a lecture or article, with clear view + support.
- **medium** — valuable perspective but needs companion atoms for complete content.
- **low** — informational, niche use cases.

### Batching order

If you have multiple source types, process in this order:

1. **Published content first** — already self-filtered, baseline quality high.
2. **Deep materials next** — supplement with technical detail.
3. **Private notes last** — highest judgment cost, prone to low-quality atoms.

Build the skeleton first, add muscle, finish with details. Starting with notes means drowning in details without structure.

### First-batch calibration

After the first batch (~10–20 segments), **human-review**. Check:
1. Did classification miss anything worth extracting?
2. Is the extraction quality what you want — is voice preserved, is structure good enough?

Calibrate, then let subsequent batches run unattended. Skipping calibration and running large batches = gambling on quality.

---

## Phase 4: Quality pass

**Goal**: clean up the unavoidable issues from extraction.

### Checklist

- [ ] **Dedupe**: the same claim extracted from multiple sources → keep the most complete, absorb the others (bump `version`), delete the duplicates.
- [ ] **Reclassify**: atom in wrong branch → move, update frontmatter `id`, bump `version`.
- [ ] **Handle bloated branches**: a branch over 30 atoms that naturally splits → split.
- [ ] **Depth/reuse_score calibration**: batch-extracted atoms often inconsistent on these → normalize.
- [ ] **Gap analysis**: subtopic distribution and depth distribution within each branch.

### Three-layer gap analysis

1. **Topic completeness** — what subtopics does each branch cover, what's visibly missing.
2. **Depth gradient** — is beginner/intermediate/advanced distribution reasonable.
3. **Use-case alignment** — does the branch structure cover what you actually use the KB for.

Not all gaps need filling. Some gaps are real — you genuinely have nothing to say on that subtopic. That's a knowledge boundary, not a task. Branch design also evolves; don't expect v1 to be perfect.

---

## Phase 5: External verification + summaries

**Goal**: confirm factual accuracy, produce readable branch summaries.

### External verification

Use WebSearch (or similar) to verify:
- Are technical claims correct / current?
- Are numeric data points fresh?
- Are you missing important counterpoints?

**Principle**: external verification is corroboration and supplement, not replacement. Other people's views are reference; yours is the knowledge base's core value.

### Branch summaries

Each branch produces a `SUMMARY.md`:
- **Core narrative line** — what this branch is "about".
- **Atom list** — organized by subtopic × depth.
- **Use-case suggestions** — which atoms fit which output formats.
- **Known gaps** — what still needs filling.

This step needs a strong model. Cheap models handle extraction and formatting fine, but "distill a narrative from 60 atoms" needs deeper comprehension.

---

## Phase 6: Wiki compilation

**Goal**: compile scattered atoms into readable wiki pages.

This is the payoff phase. Atoms are parts; wiki pages are products.

### Compilation logic

Not one-atom-per-page. Group by "what a reader wants to understand", combining related atoms into one coherent article. Typical wiki page = 3–8 atoms.

### Format conventions (preconditions for automation)

These conventions make `lint.sh` and `gen-index.sh` work:

1. **Filename rule** — `wiki/<branch>/<topic-slug>.md`, all lowercase, hyphens only. The folder carries the branch name; the slug must not repeat it.
2. **`[[branch/slug]]` = relative path under `wiki/` without `.md`.** Scripts use this to find ghost links and orphans.
3. **First line must be `# title`** — `gen-index.sh` reads this for page titles.
4. **`[[link]]` can appear anywhere in-body** — not restricted to a "see also" section. First mention links; subsequent mentions in the same page don't.
5. **Temporal markers in uniform format** — version as `v3.5`, date as `2026-04`. Avoid "current" / "latest" / "now" in time-sensitive contexts. `lint.sh` regex-checks these.

### Compilation principles

1. **Group by topic, not one-to-one with atoms.**
2. **Preserve voice** — wiki is opinionated knowledge, not encyclopedia.
3. **Add cross-references** — use `[[branch/slug]]` to build a network.
4. **Tag sources** — footer lists source atoms for traceability.
5. **Length control** — 1500–2500 words per page. Split if longer.

### Wiki page structure

```markdown
# Page Title

Opening paragraph (why this matters, common misconception).

## Section one
[Integrated content from multiple atoms, coherent prose]

## Section two
[Continuation, natural transition]

---

**See also**
- [[other-branch/related-page-one]] — one-line description
- [[same-branch/related-page-two]] — one-line description

---
*Compiled from N atoms: branch/atom-a, branch/atom-b, branch/atom-c*
```

### Global index

`index.md` at the repo root is auto-generated by `gen-index.sh` (and re-run automatically by the atomic-wiki plugin's `PostToolUse` hook after any wiki edit). Lists all wiki pages, grouped by branch, one-line each. This is the LLM's entry point for Query — it scans the index to decide which pages to load, not the whole wiki.

### Change history

Git is the change log. Every Ingest, edit, or compile lands as a commit. There is no separate `log.md`. Use clear commit messages — `git log` is what you read when you want to know what changed and why. The pre-commit hook enforces the atom version-bump rule so substantive edits are always reflected in the `version:` field.

---

## Continuous maintenance: the four operations

Wiki isn't done after the first build. Four continuous operations, each provided by the atomic-wiki plugin as a skill:

| Skill | Trigger | What it does |
|---|---|---|
| `/atomic-wiki:ingest` | new material in `raw/` | Read it, classify segments, extract atoms into the matching branch. |
| `/atomic-wiki:compile` | new or changed atoms | Group atoms into a wiki page (or update one). Parallel-compile uses a slug-lock to avoid filename collisions. |
| `/atomic-wiki:lint` | periodic, or after large changes | Programmatic check (`lint.sh`) for ghost links, orphans, format violations; LLM check for contradictions, concept gaps, expired claims, weak orphans. Appends findings to `lint-report.md`. |
| `/atomic-wiki:query` | answering a question | Read `index.md`, load relevant pages only, answer. Optionally write back the synthesis as a new atom or version bump. |

The atomic-wiki plugin's hooks keep the housekeeping invisible: `gen-index.sh` runs after every wiki edit, `lint.sh` runs at the end of every turn. The git pre-commit hook is installed per-clone by `/atomic-wiki:init` — re-run init after cloning.

---

## Tooling

- **AI coding agent** — Claude Code with the atomic-wiki plugin. The pipeline spec lives in `reference/SCHEMA.md`; the root `CLAUDE.md` is a thin developer note. Other agents can use the plugin if they support the Claude Code plugin model.
- **Filesystem** — atoms and wiki are just `.md` files.
- **Git** — for version history; the pre-commit hook needs it.
- **Obsidian (optional)** — opens the repo as a vault. Dataview can query atoms via `file.ctime` / `file.mtime` and any frontmatter field; the graph view shows `[[ ]]` connections.

---

## FAQ

### "Is my material volume worth this?"

Depends on how you define "worth". If you have 10 notes, just put them in a folder. If you have 50+ materials and will keep producing, spending an afternoon on structure pays off every time you use the knowledge base afterward. Knowledge bases compound — the earlier you build, the more returns.

### "Must I use YAML frontmatter?"

Yes for `version:` (the pre-commit hook needs it). The rest is for batch-processing and statistical analysis. At minimum, mark `type` and `tags` — future-you will thank past-you.

### "Is AI-extracted quality good enough?"

Depends on the rules and examples you give. AI extraction without rules = random quality. Rules + 2–3 examples + human-reviewed first few batches = stable acceptable quality. The bottleneck isn't AI intelligence; it's whether you articulated your standards clearly.

### "Compile vs RAG — exclusive choice?"

No. Small-scale use compile (wiki). Large-scale use hybrid. Compile for core stable high-value knowledge; RAG for one-off long-tail queries.

### "What if knowledge goes stale?"

Lint periodically. Technical knowledge: quarterly Lint. Check:
- Tool version numbers still correct.
- Technical trends still valid.
- Your own views still hold.

View evolution is not a bug. Edit the atom, bump `version:`, commit. The previous version stays in `git log` so you can see how you changed your mind. Knowing how you changed is also knowledge.
