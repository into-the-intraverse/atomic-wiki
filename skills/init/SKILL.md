---
name: init
description: Use when a repository needs the atomic-wiki pipeline set up — before first running /atomic-wiki:ingest or /atomic-wiki:compile in a repo that has no atoms/ or wiki/ yet, or after cloning an existing atomic-wiki repo to restore its local version-bump git hook.
---

# atomic-wiki: init

Scaffold the atomic-wiki pipeline in the current repository: create the storage folders, drop in the atom/wiki templates, ignore generated files, and register the version-bump pre-commit hook. Idempotent — safe to re-run.

## When to use

- A repo will use the atomic-wiki pipeline but has no `atoms/` / `wiki/` yet.
- You just cloned an atomic-wiki repo. Git-hook registration is per-clone (local git config is not cloned), so re-run this to restore version-bump enforcement.

Do **not** use this to create knowledge — that is `/atomic-wiki:ingest`. This only scaffolds structure.

## Procedure

Run from anywhere inside the target git repo. Everything resolves to the repo's git root; bundled assets come from the plugin via `${CLAUDE_PLUGIN_ROOT}`. Run this block with bash (git-bash on Windows):

```bash
ROOT="$(git rev-parse --show-toplevel)" || { echo "atomic-wiki: not inside a git repo"; exit 1; }
cd "$ROOT"

# 1. Storage folders (kept in git even when empty)
for d in atoms wiki raw; do mkdir -p "$d"; [ -e "$d/.gitkeep" ] || : > "$d/.gitkeep"; done

# 2. Templates — copied as local starters; never overwrite a customized one
[ -e atoms/_template.md ] || cp "${CLAUDE_PLUGIN_ROOT}/templates/atom.md"      atoms/_template.md
[ -e wiki/_template.md ]  || cp "${CLAUDE_PLUGIN_ROOT}/templates/wiki-page.md" wiki/_template.md

# 3. Ignore generated files (append once, no duplicates)
touch .gitignore
grep -qxF 'index.md' .gitignore       || echo 'index.md'       >> .gitignore
grep -qxF 'lint-report.md' .gitignore || echo 'lint-report.md' >> .gitignore

# 4. Register the version-bump pre-commit hook
#    (config-based on git >= 2.54, file-based fallback otherwise)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-versionbump-hook.sh"
```

## Optional: point the project's CLAUDE.md at the pipeline

Ask the user before editing their `CLAUDE.md`. If they agree, append:

> This repo uses the **atomic-wiki** plugin. Operate it with `/atomic-wiki:ingest`, `/atomic-wiki:compile`, `/atomic-wiki:lint`, `/atomic-wiki:query`. The pipeline spec is the plugin's `reference/SCHEMA.md`.

## After running

- Tell the user exactly what was created and which hook path (config-based vs file-based) was registered — `install-versionbump-hook.sh` prints this.
- Remind them: the git-hook registration lives in **local git config**, so **re-run `/atomic-wiki:init` after a fresh clone** to restore enforcement. The vendored `.wiki/check-version-bump.sh` *is* committed; only the registration repeats.

## Common mistakes

- Running outside a git repo — step 1 aborts with a clear message; `cd` into the repo first.
- Expecting the hook to survive a clone — it does not; re-run init.
- Overwriting a customized `atoms/_template.md` — the copy is guarded with `[ -e ... ]`; it will not clobber.
