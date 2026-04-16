# From Scattered Materials to Usable Knowledge: An AI-Assisted Knowledge Compilation Methodology

You have a pile of scattered content — posts, replies, lecture transcripts, notes, screenshots, audio — and you know there's value in it, but every time you need something you can't find it, and when you do find it you have to re-read to remember what it said.

This document records a battle-tested pipeline: **use AI to refine raw material of any format into structured knowledge atoms, then compile those atoms into readable, cross-referenced wiki pages.**

Not RAG. Not re-searching raw sources on every query. A one-time token investment to organize knowledge so that future queries just read the wiki.

---

## The core claim: Compile > RAG (at the personal knowledge base scale)

Andrej Karpathy's LLM Wiki pattern (2026) argues that "compile" beats "retrieval-augmented generation":

**The RAG problem**: every query has to re-search the raw material, re-understand it, re-assemble it. Tokens spent on repeated understanding, and results can vary run to run.

**The compile approach**: spend tokens once to understand the raw material thoroughly, producing structured wiki pages. Subsequent queries just read the wiki, never touching the raw source. Knowledge becomes a "persistent, compounded artifact" rather than something regenerated each time.

### Conditions for this claim to hold

1. **Manageable knowledge volume** — around 100–200 wiki pages. Beyond that, LLMs struggle to use `index.md` effectively and you'll want a hybrid (wiki as primary structure + vector search for locating).
2. **Relatively stable knowledge** — you're building a cognitive map, not a newsfeed. Updates in days or weeks, not minutes.
3. **Single owner with a point of view** — personal knowledge with a consistent stance, not an aggregation of many voices.
4. **Quality over coverage** — 50 pages written tight beat 500 pages written shallow.

### Honest limitations

- No peer-reviewed benchmark comparing Compile vs RAG. Karpathy's evidence is "it feels good to use."
- Past a few hundred pages, pure wiki structure hits navigation bottlenecks. Pair with vector search for locating.
- Compile cost is non-trivial — first Ingest of a large corpus burns significant tokens. But marginal cost decreases after that.
- Knowledge goes stale. Lint is periodic, not one-shot.

---

## Pipeline overview

```
Raw material (text in any format)
    ↓ Phase 1: design the classification structure
    ↓ Phase 2: segment classification (extract / skip)
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

### Input
- Your intuitive sense of your own knowledge landscape
- (Optional) your teaching products, content roadmap, or professional domain

### Operation
1. List the topics your knowledge covers (doesn't need to be perfect — iterate)
2. Create one folder per topic ("branch") under `atoms/` (e.g. `atoms/ai-agent/`, `atoms/mcp/`)
3. Write a short note describing each branch's definition and boundary (in `STORY.md` or your own notes)

### Branch design principles

A good branch satisfies:
- **Independence** — can't fit cleanly into any existing branch
- **Scale** — expected to hold 5+ knowledge points
- **Clear boundaries** — you can articulate "what belongs, what doesn't"
- **Teaching independence** — can anchor at least 30 minutes of instruction on its own

Common mistakes:
- Branches too fine (each holds only 2–3 atoms) → use tags instead
- Branches too coarse (50+ atoms spanning three unrelated topics) → split
- Boundaries blurry (>50% of atoms also tagged with another branch) → merge or redefine

### AI's role

Let AI review your material list and propose a branch structure. But the final call is yours — AI doesn't know your teaching positioning or differentiation.

---

## Phase 2: Segment classification

**Goal**: scan raw material and mark each segment "extract" / "skip" / "deferred".

This is the quality gatekeeper. Skipping classification and extracting everything produces a flood of low-quality atoms, and cleanup costs more than prevention. Real data: social media replies filter at ~87% — most replies are noise (emojis, greetings, "+1"). Classify first, only extract the segments worth extracting.

### Classification criteria

Per segment, mark:

- **Extract** — contains a knowledge point, view, experience, or method that stands alone. Even out of original context, this segment has teaching or reference value.
- **Skip** — pure social interaction, restating others' views, filler agreement, action items ("tomorrow do X"), pure emotion.
- **Deferred** — potentially valuable but uncertain, or requires surrounding context to understand. Skip in the first pass; revisit after the full batch is classified.

### Extraction rate expectations by source type

| Source | Expected extract rate | Classification focus |
|--------|----------------------|---------------------|
| Social posts | 70–90% | Author-curated, most worth extracting |
| Social replies | 10–15% | Mostly noise, only deep-explanation replies |
| Transcripts | 40–60% | Skip greetings, repetition, tangents |
| Articles / papers | 80–95% | Mostly valuable; main filter is topic relevance |
| Notes / memos | 20–40% | Heavy in action items and fragments |
| Conversation logs | 15–30% | Extract conclusions and decisions only |

---

## Phase 3: Extract into atoms

**Goal**: turn "extract"-marked segments into standard-format knowledge atoms.

### What is a knowledge atom

A `.md` file with YAML frontmatter (metadata) and a body containing one core claim. Academic framing: Atomic Fact Decomposition — decomposing composite information into the smallest independently verifiable units.

**Atoms are immutable.** Once created, don't edit. If knowledge evolves (view changes, technology updates), create a new atom replacing the old one, and move the old one to `_archive/`. Then recompile affected wiki pages. This mirrors Karpathy's "raw/ is read-only" principle — atoms are our raw layer; wiki is always rebuildable from atoms.

```yaml
---
id: branch/descriptive-slug
type: explanation | opinion | tutorial | myth-busting | case-study | comparison
depth: beginner | intermediate | advanced
source_type: post | transcript | article | note | screenshot | audio
source_ids: []
reuse_score: high | medium | low
tags: []
created: YYYY-MM-DD
---
```

### Extraction principles

1. **Extract, don't copy** — store refined knowledge, not original pasted
2. **One atom, one claim** — a post with three independent views becomes three atoms
3. **Preserve the author's voice** — personal knowledge differentiation comes from perspective; don't flatten into neutral encyclopedia prose
4. **Tag sources** — every atom traces back to its raw source
5. **One atom belongs to one branch** — use tags for related topics

### Judging "extract" vs "copy"

The same raw text, handled two ways:

**Raw** (social post):
> Yesterday I spent three hours debugging an agent and realized the system prompt was too long — the model was ignoring the second half. Splitting the prompt into three layers — role definition, task rules, current context — fixed it instantly. Don't cram everything into one prompt.

**Bad atom (copying)**:
```markdown
# Debug agent experience
Yesterday I spent three hours debugging an agent and realized the system
prompt was too long — the model was ignoring the second half. Splitting
the prompt into three layers — role definition, task rules, current
context — fixed it instantly. Don't cram everything into one prompt.
```
→ This just adds a title to the original. No refinement.

**Good atom (extraction)**:
```markdown
# System Prompt Layered Architecture

Long system prompts cause models to ignore later instructions. The fix is
to split the prompt into three layers:

1. **Role definition** — who you are, core responsibilities
2. **Task rules** — operational constraints, quality bar
3. **Current context** — task-specific information

The benefit isn't just avoiding omission — each layer can be updated
independently. Role definition rarely changes; task rules adjust occasionally;
context changes every time. Mixed together, any edit forces re-reviewing
the whole prompt.
```
→ Extracted the core knowledge (layered architecture), added an implicit insight (independent update), structured it.

### When to split one segment into multiple atoms

**Test**: if a passage contains two views, and removing one leaves the other intact — split.

**Split example**:

Raw: "Vibe Coding isn't not writing code — it's moving effort from syntax to architecture. Also, after using AI to write code, code review becomes more important than before, because you're not reviewing your own logic anymore."

→ Two atoms:
1. **What Vibe Coding really is** — effort shifts from syntax to architecture (type: explanation)
2. **Code Review in the AI era** — reviewing AI's logic, not your own (type: opinion)

**Don't split example**:

Raw: "The three-layer Harness architecture is Persona, Rules, Context. Persona defines the role, Rules define constraints, Context provides current info."

→ Don't split. The three layers are one concept — each is incomplete alone.

### What should not become an atom

These should be caught at classification, but if they slip through, block them at extraction:

- **Pure action items**: "Tomorrow update landing page" → todo, not knowledge
- **Unannotated restatement**: "OpenAI released GPT-5" → news, unless paired with your analysis
- **Over-time-sensitive content**: "Claude 3.5 Sonnet is currently strongest" → stale in three months, unless discussing evaluation methodology itself
- **Pure emotion**: "Exhausting day but satisfying" → journal, not knowledge

### Quality judgment

How to set `reuse_score`:
- **high** — standalone-usable in a lecture or article, with clear view + support
- **medium** — valuable perspective but needs companion atoms for complete content
- **low** — informational, niche use cases

### Batching order

If you have multiple source types, process in this order:

1. **Published content first** — already self-filtered, baseline quality high
2. **Deep materials next** — supplement published content with technical detail
3. **Private notes last** — highest judgment cost, prone to low-quality atoms

Build the skeleton first (from public content), add muscle (from depth materials), finish with details (notes). Starting with notes means drowning in details without structure.

### First-batch calibration

After the first batch (~10–20 segments), **human-review**. Check two things:
1. Did classification miss anything worth extracting?
2. Is the extraction quality what you want — is voice preserved, is structure good enough?

Calibrate, then let subsequent batches run unattended. Skipping calibration and running large batches = gambling on quality.

---

## Phase 4: Quality pass

**Goal**: clean up the unavoidable issues from extraction.

### Checklist

- [ ] **Dedupe**: the same claim extracted from multiple sources → keep the most complete, archive the rest
- [ ] **Reclassify**: atom in wrong branch → move, update frontmatter `id`
- [ ] **Handle bloated branches**: single branch over 30 atoms and naturally splittable → split
- [ ] **Depth/reuse_score calibration**: batch-extracted atoms often inconsistent on these → normalize
- [ ] **Gap analysis**: subtopic distribution and depth distribution within each branch

### Three-layer gap analysis

1. **Topic completeness** — what subtopics does each branch cover, what's visibly missing
2. **Depth gradient** — is beginner/intermediate/advanced distribution reasonable
3. **Use-case alignment** — does the branch structure cover what your teaching products / content plans need

Not all gaps need filling. Some gaps are real — you genuinely have nothing to say on that subtopic. That's a knowledge boundary, not a task to fill.

### AI's role

Gap analysis is a great AI job — it's good at distribution stats, pattern-finding, cross-comparison. But "is this gap important?" is your call.

---

## Phase 5: External verification + summaries

**Goal**: confirm factual accuracy, produce readable branch summaries.

### External verification

Use WebSearch (or similar) to verify:
- Are technical claims correct / current
- Are numeric data points fresh
- Are you missing important counterpoints

**Principle**: external verification is corroboration and supplement, not replacement. Other people's views are reference; yours is the knowledge base's core value.

### Branch summaries

Each branch produces a `SUMMARY.md`:
- **Core narrative line** — what this branch is "about"
- **Atom list** — organized by subtopic × depth
- **Teaching path suggestions** — which atoms fit which formats
- **Known gaps** — what still needs filling

This step needs a strong model. Cheap models handle extraction and formatting fine, but "distill a teaching narrative from 60 atoms" needs deeper comprehension.

---

## Phase 6: Wiki compilation

**Goal**: compile scattered atoms into readable wiki pages.

This is the payoff phase. Atoms are parts; wiki pages are products.

### Compilation logic

Not one-atom-per-page. Group by "what a reader wants to understand", combining related atoms into one coherent article.

Example: you have 5 atoms — "What is Harness", "Why Harness matters", "Three challenges of AI collaboration", "Harness vs Agent", "Harness public announcement" — compile into one page: "What is Harness Engineering".

### Format conventions (preconditions for automation)

These conventions make `lint.sh` and `gen-index.sh` work:

1. **Filename rule** — `<branch>-<topic-slug>.md`, all lowercase, hyphens only. Example: `harness-engineering-what-is-harness.md`.
2. **`[[wiki-link]]` = filename without `.md`** — `[[harness-engineering-what-is-harness]]` maps to `wiki/harness-engineering-what-is-harness.md`. Scripts use this to find ghost links and orphans.
3. **First line must be `# title`** — `gen-index.sh` reads this for page titles.
4. **`[[link]]` can appear anywhere in-body** — not restricted to a "see also" section. First mention of a related concept links; subsequent mentions in the same page don't.
5. **Temporal markers in uniform format** — version as `v3.5`, date as `2025-04`, avoid "current" / "latest" / "now" in time-sensitive contexts, use specific dates (`as of 2025-04`). `lint.sh` regex-checks these.

### Compilation principles

1. **Group by topic, not one-to-one with atoms** — typical wiki page = 3–8 atoms
2. **Preserve voice** — wiki is opinionated knowledge, not encyclopedia
3. **Add cross-references** — use `[[wiki-link]]` to build a network
4. **Tag sources** — footer lists source atoms for traceability
5. **Length control** — 1500–2500 words per page. Split if longer.

### Wiki page structure

```markdown
# Page Title

Opening paragraph (why this matters, common misconception)

## Section one
[Integrated content from multiple atoms, teaching tone, coherent prose]

## Section two
[Continuation, natural transition]

---

**See also**
- [[related-page-one]] — one-line description
- [[related-page-two]] — one-line description

---
*Compiled from N atoms: atom-a, atom-b, atom-c*
```

### Global index

Build `index.md` at the repo root (auto-generated by `scripts/gen-index.sh`). Lists all wiki pages, organized by branch, one-line summary each. This is the LLM's entry point for Query — it doesn't read every page, it scans the index to decide which pages to load.

### Change log

`log.md`, append-only. Every Ingest or page update logs an entry. Use `scripts/log-append.sh`.

### AI's role

Compilation is where AI shines. It's good at "synthesize 5 scattered pieces into one structured article". What to give it:
- Clear voice instructions (teaching style vs reference doc style)
- Example pages (show what a good wiki page looks like)
- The branch `SUMMARY.md` (so it understands the narrative line)

---

## Continuous maintenance: three core operations

Wiki isn't done after the first build. Karpathy defined three continuous operations:

### Ingest (new material)

1. New material into `raw/` (or wherever your sources live)
2. AI reads new material, extracts atoms
3. Update affected wiki pages (or create new ones)
4. Run `gen-index.sh` and `log-append.sh`

### Query (knowledge use)

1. Read `index.md` to locate relevant pages
2. Read pages, synthesize answer
3. If the answer produces a new worth-keeping synthesis, write it back as an atom

### Lint (periodic audit)

Two layers, run in order.

**Programmatic Lint** (`scripts/lint.sh`): checks ghost links, orphan pages, format violations, outdated markers. Seconds to run. Deterministic. Output: `lint-report.md`.

**LLM Lint**: the AI audits wiki health.

1. **Scope**: LLM reads `index.md` + all wiki pages (not atoms — Lint checks wiki-layer quality)
2. **Checks**:
   - **Contradictions** — page A says "X is best practice", page B says "X is deprecated" → flag both, list paths and conflicting segments
   - **Orphan pages** — no other page `[[wiki-link]]`s to it → add links or merge
   - **Ghost links** — `[[wiki-link]]` to non-existent page → create page or remove link
   - **Concept gaps** — multiple pages reference a concept with no dedicated page → flag as candidate new page
   - **Expired claims** — version numbers, dates, temporal markers in time-sensitive contexts → verify
3. **Output**: append to `lint-report.md`, sorted by severity (contradictions > ghost links > orphans > concept gaps > expired)
4. **Action**: decide which to fix, do the edits, run `log-append.sh`

---

## Advanced: graphify and knowledge graphs

If your needs exceed wiki's flat structure, [graphify](https://github.com/safishamsi/graphify) (25k+ stars) takes the graph approach.

### What graphify does

Solves the same problem Karpathy's wiki does — "pile of raw material, structure it" — but with knowledge graphs instead of wiki pages.

Technical highlights:
- **Three-stage pipeline**: AST parsing → transcription extraction → LLM semantic analysis. Claims 71.5× token savings over direct-to-LLM.
- **Multimodal**: code, images, video, audio
- **Topological clustering**: Leiden community detection, not embedding similarity — captures structural relationships, not surface semantic proximity
- **Three-tier confidence**: EXTRACTED, INFERRED, AMBIGUOUS

### When to use graphify vs wiki

| Scenario | Wiki | graphify |
|---------|------|----------|
| Personal knowledge (<200 pages) | ideal | overkill |
| Large codebase understanding | poor fit | strong fit |
| Multimodal material (code + docs + video) | need format unification | native support |
| Interactive visualization | not provided | built-in |
| Human-readable pages | core value | not the point |
| Cross-domain link discovery | manual `[[link]]` | automatic |

### Hybrid

Not mutually exclusive. A viable combination:
1. Use this methodology's Phase 1–5 to build atoms and branch structure
2. Use Phase 6 to compile human-readable wiki
3. Feed the same atoms to graphify for a knowledge graph

Wiki answers "what is X"; graph answers "what is X connected to, and what might it be connected to".

---

## Tooling

### Minimum

- An AI coding agent (Claude Code, Cursor, equivalent)
- A filesystem (atoms and wiki are just `.md` files)
- That's it

### Advanced

| Tool | Use | Necessity |
|------|-----|-----------|
| Obsidian | Browse wiki, graph view for connections | Recommended |
| MCPVault | Let AI agents read/write Obsidian vault | Recommended with Obsidian |
| Vector DB | Assist location (past 200 pages) | Large-scale only |
| graphify | Knowledge graph visualization | Optional, for large-scale or multimodal |

---

## FAQ

### "Is my material volume worth this?"

Depends on how you define "worth". If you have 10 notes, just put them in a folder. If you have 50+ materials and will keep producing, spending an afternoon on structure pays off every time you use the knowledge base afterward. Knowledge bases compound — the earlier you build, the more returns.

### "Must I use YAML frontmatter?"

No. YAML is for batch-processing and statistical analysis by AI. Small knowledge bases don't need it. But at minimum, mark `type` and `tags` — future-you will thank past-you.

### "Is AI-extracted quality good enough?"

Depends on the rules and examples you give. AI extraction without rules = random quality. Rules + 2–3 examples + human-reviewed first few batches = stable acceptable quality. The bottleneck isn't AI intelligence; it's whether you articulated your standards clearly.

### "Compile vs RAG — exclusive choice?"

No. Small-scale use Compile (wiki). Large-scale use hybrid. Compile for core stable high-value knowledge; RAG for one-off long-tail queries.

### "What if knowledge goes stale?"

Lint periodically. Technical knowledge: quarterly Lint. Check:
- Tool version numbers still correct
- Technical trends still valid
- Your own views still hold

View evolution is not a bug. Mark old views as "evolved", preserve context, don't delete. Knowing how you changed is also knowledge.

---

## Reference implementation data

See the `README.md` of this repo for data from the reference implementation (584 posts + 8,668 replies → 630 atoms → 83 wiki pages across 11 branches).

### Lessons from the reference run

- **Reply value is underrated.** Social replies often contain deeper technical detail than posts — because replies happen in concrete problem contexts. But filtering cost is high (87% noise).
- **Model choice varies by phase.** Extraction (Phase 2–3) fits mid-tier models. Summary (Phase 5) and Compile (Phase 6) need stronger models — synthesizing a narrative from 60 atoms requires depth.
- **Branch design evolves.** Don't expect v1 to be perfect. Splitting a branch during Phase 4 is normal.
- **Not all gaps need filling.** Gap analysis will list "theoretically should exist but missing" knowledge points. Some are real gaps; some are just "you have nothing to say here". Don't fill the latter.

---

*This methodology is distilled from a real-world implementation. See the main README for metrics and outcomes.*
