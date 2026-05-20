# llm-atomic-wiki

> Fork of [cablate/llm-atomic-wiki](https://github.com/cablate/llm-atomic-wiki), which extends [Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) with an atom layer, topic-branches, two-layer lint, and git-native versioned history. This repo is my personal template — same pattern, my own tweaks.

A knowledge-base pipeline for turning scattered material (notes, posts, transcripts, articles) into a queryable wiki. The LLM does the bookkeeping; you keep the editorial voice.

```
┌─────────┐  Ingest    ┌──────────────┐  Compile   ┌──────────────┐
│  raw/   │ ─────────▶ │ atoms/       │ ─────────▶ │ wiki/        │
│         │  (LLM      │  <branch>/   │  (LLM      │  <branch>/   │
│ sources │  extract)  │   atom.md    │  group)    │   page.md    │
└─────────┘            │   atom.md    │            └──────┬───────┘
                       └──────────────┘                   │
                                ┌─────────────────────────┴─────────────────────────┐
                                ▼                                                   ▼
                          gen-index.sh                                          lint.sh
                              │                                                     │
                              ▼                                                     ▼
                          index.md                                            lint-report.md
```

Atoms are mutable but versioned. Edit in place, bump `version:` in the frontmatter. The pre-commit hook refuses commits where an atom's body changed beyond whitespace without a version bump. Git is the audit trail; there is no `_archive/` folder.

---

## Repo layout

```
.
├── CLAUDE.md              ← formal spec for any LLM operating this repo
├── METHODOLOGY.md         ← the why behind the pipeline (decision track)
├── README.md
│
├── raw/                   ← drop source materials here (gitignored)
│
├── atoms/                 ← knowledge atoms, organized by topic-branch
│   ├── _template.md       ← copy when creating a new atom
│   └── <branch>/<slug>.md
│
├── wiki/                  ← compiled pages, mirrored branch tree
│   ├── _template.md       ← copy when creating a new wiki page
│   └── <branch>/<slug>.md
│
├── index.md               ← auto-generated (gitignored)
├── lint-report.md         ← auto-generated (gitignored)
│
├── scripts/               ← gen-index.sh, lint.sh, check-version-bump.sh, hooks/
└── .claude/
    ├── skills/            ← /ingest, /compile, /lint, /query
    └── settings.json      ← PostToolUse + Stop + SessionStart hooks
```

---

## Quickstart

1. **Install the git pre-commit hook** — `./scripts/install-hooks.sh`. (The `SessionStart` hook in `.claude/settings.json` does this automatically when you open the repo with Claude Code.)
2. **Drop materials into `raw/`** — any text format. PDFs, transcripts, post dumps, articles.
3. **Run an operation** from inside Claude Code:
   - `/ingest <file-or-folder>` — extract atoms from raw
   - `/compile <branch>` — group atoms into a wiki page
   - `/lint` — programmatic + LLM lint pass
   - `/query <question>` — answer from the wiki
4. **Commit.** The `PostToolUse` hook keeps `index.md` fresh; the `Stop` hook re-runs `lint.sh`; the pre-commit hook enforces version bumps.

The loop is `Ingest → Compile → Index/Lint → Commit → Query`.

---

## Deep dives

- **[METHODOLOGY.md](METHODOLOGY.md)** — the six-phase pipeline and the reasoning behind each architectural choice.
- **[CLAUDE.md](CLAUDE.md)** — the formal spec (atom format, wiki format, branch rules, operations, what not to do).
