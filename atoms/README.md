# atoms/

Knowledge atoms, organized by topic-branch. **Source of truth.**

## Layout

```
atoms/
├── README.md                ← you are here
├── _template.md             ← copy this when creating a new atom
│
├── <branch-1>/              ← one folder per topic-branch
│   ├── 2026-01-15-some-claim.md
│   ├── 2026-02-03-another-claim.md
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

Karpathy's original LLM Wiki goes `raw → wiki` directly. The atom layer is this repo's main addition — it solves three problems:

1. **Loss of information.** Wiki compilation is lossy. Without atoms, you can't recover what got dropped without re-reading raw.
2. **False sense of source of truth.** Wiki looks authoritative, but it's a derived artifact. Atoms are the truth; wiki is a cache.
3. **Provenance.** Every wiki claim should be traceable to atoms, and every atom traceable to raw. Without an atom layer, the chain breaks at the wiki.

When a wiki page is wrong, you fix the underlying atom and recompile. You never patch the wiki directly.

## Atom history is in git

Atoms are mutable. When knowledge evolves, you edit the atom in place and bump the `version:` integer in frontmatter. Git keeps the previous text — `git log` and `git show` are the audit trail. There is no `_archive/` folder and no `superseded_by` field; that role is now git's.

The `scripts/hooks/pre-commit` hook (install with `scripts/install-hooks.sh`) refuses any commit where an atom's body changed beyond whitespace without `version:` being bumped. New atoms must declare `version: 1`.

## What's gitignored in the framework template

In this public framework repo, everything in `atoms/` except `README.md`, `_template.md`, and `.gitkeep` is gitignored — so contributors don't push their personal content here. **In your own fork, remove that gitignore block** so git can record your atom history. The model assumes atoms are tracked.
