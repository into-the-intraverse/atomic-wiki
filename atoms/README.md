# atoms/

Knowledge atoms, organized by topic-branch. **Source of truth.**

## Layout

```
atoms/
├── README.md                ← you are here
├── _template.md             ← copy this when creating a new atom
│
├── <branch-1>/              ← one folder per topic-branch
│   ├── some-claim.md
│   ├── another-claim.md
│   └── ...
│
├── <branch-2>/
│   └── ...
│
└── ...
```

One folder per topic-branch. One file per atom. One claim per file.

See `_template.md` for the frontmatter and body format. See `CLAUDE.md` at the repo root for the full spec.

## Why atoms exist

The atom layer sits between raw material and the compiled wiki. It solves three problems:

1. **Loss of information.** Wiki compilation is lossy. Without atoms, you can't recover what got dropped without re-reading raw.
2. **False sense of source of truth.** Wiki looks authoritative, but it's a derived artifact. Atoms are the truth; wiki is a cache.
3. **Provenance.** Every wiki claim should be traceable to atoms, and every atom traceable to raw. Without an atom layer, the chain breaks at the wiki.

When a wiki page is wrong, you fix the underlying atom and recompile. You never patch the wiki directly.

## Atom history is in git

Atoms are mutable. When knowledge evolves, you edit the atom in place and bump the `version:` integer in frontmatter. Git keeps the previous text — `git log` and `git show` are the audit trail. There is no `_archive/` folder and no `superseded_by` field.

The `scripts/hooks/pre-commit` hook (auto-installed by the `SessionStart` hook in `.claude/settings.json`, or manually via `scripts/install-hooks.sh`) refuses any commit where an atom's body changed beyond whitespace without `version:` being bumped. New atoms must declare `version: 1`.

## Why no dates anywhere

No date prefix in filenames. No `created:` or `updated:` in frontmatter. Git tracks both for free (`git log --diff-filter=A --follow` for created, `git log -1` for last-modified), and Obsidian Dataview can query `file.ctime` / `file.mtime` directly. Dates in files always drift.
