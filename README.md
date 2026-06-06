# atomic-wiki

atomic-wiki is a Claude Code plugin that runs a structured knowledge pipeline: raw sources drop in, an LLM extracts single-claim notes called atoms, atoms get compiled into coherent wiki pages, and a query skill answers questions against the result. The plugin is pure machinery — skills, scripts, hooks, schema, and templates. Each project that uses it holds its own content (`atoms/`, `wiki/`, `raw/`, `index.md`) at its git root; the plugin never touches that content tree directly except through the skills you invoke.

---

## Install

```
/plugin marketplace add D:/code/llm-atomic-wiki   # local path, or the GitHub URL once pushed
/plugin install atomic-wiki@atomic-wiki
```

During development, load the plugin without installing it by pointing Claude Code at the plugin directory:

```
claude --plugin-dir D:/code/llm-atomic-wiki
```

---

## Set up a project

Run once in the target repository:

```
/atomic-wiki:init
```

This scaffolds `atoms/`, `wiki/`, `raw/`, copies the atom and wiki templates, writes `.gitignore` entries for the generated files (`index.md`, `lint-report.md`), and installs the version-bump pre-commit hook (see below).

After that, the four pipeline skills are available in any Claude Code session opened in that repo:

| Skill | What it does |
|---|---|
| `/atomic-wiki:ingest` | Classify segments of a raw source and extract atoms into the matching branch |
| `/atomic-wiki:compile` | Group atoms from a branch into a coherent wiki page |
| `/atomic-wiki:lint` | Programmatic checks + LLM semantic review of atoms and wiki pages |
| `/atomic-wiki:query` | Read `index.md`, load relevant pages, answer a question from the wiki |

---

## Automation

Two plugin hooks run automatically in any wiki project:

- **PostToolUse on `wiki/**/*.md` writes** — reruns `scripts/gen-index.sh` to keep `index.md` fresh.
- **Stop (end of turn)** — reruns `scripts/lint.sh` for the fast programmatic lint pass.

Both hooks no-op when the current working directory is not a wiki project (i.e., when `atoms/` does not exist at the repo root).

The LLM semantic lint inside `/atomic-wiki:lint` is intentionally not run on every Stop — it is slow and expensive. Schedule it instead:

```
/schedule
```

Point the scheduled agent at `/atomic-wiki:lint` with whatever cadence fits your workflow.

---

## Version-bump enforcement

`/atomic-wiki:init` installs a pre-commit hook that rejects any commit where an atom's body changed beyond whitespace without a corresponding `version:` increment in its frontmatter. Git is the audit trail; there is no archive folder.

The hook uses git ≥ 2.54 config-based installation if available, and falls back to writing `.git/hooks/pre-commit` directly. The hook is per-clone — re-run `/atomic-wiki:init` after cloning a wiki project to a new machine.

Pure formatting commits (whitespace cleanup, blank-line normalization) pass without a bump.

---

## Learn more

- **[METHODOLOGY.md](METHODOLOGY.md)** — the reasoning behind the pipeline: why atoms are mutable rather than append-only, why git is the version store, why the wiki is a derived cache and not the source of truth.
- **[reference/SCHEMA.md](reference/SCHEMA.md)** — the full formal spec: atom frontmatter fields, filename rules, wiki page format, branch design criteria, and what the pre-commit hook enforces.
