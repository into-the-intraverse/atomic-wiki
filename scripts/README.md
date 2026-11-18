# scripts/

Maintenance scripts used by the **atomic-wiki plugin**. All shell, no dependencies beyond `bash`, `grep`, `sed`, `awk`, `sort`, `find`, `git`.

Scripts are invoked via `${CLAUDE_PLUGIN_ROOT}/scripts/...` and are not meant to be run repo-relative.

---

## `gen-index.sh`

Rebuilds `index.md` at the consumer's git root from `wiki/<branch>/<page>.md` filenames, first-line titles, and summary lines.

**What it does:**
1. Resolves the consumer git root (no-ops if not inside a wiki project).
2. Walks each `wiki/<branch>/` subfolder.
3. Reads the first line of each page (must be `# Title`) and the `> summary` line under it (empty cell if missing).
4. Writes the grouped, alphabetically-sorted index to `index.md`.

**Invoked by:** the atomic-wiki plugin's `PostToolUse` hook (on any Write/Edit to `wiki/**/*.md`) and by `/atomic-wiki:compile`.

**Configuration:**

To control branch display order and names (e.g., "MCP" instead of "Mcp"), edit the `BRANCHES` override array at the top of the script:

```bash
declare -a BRANCHES=(
  "mcp|MCP"
  "llm-ops|LLM Ops"
  "knowledge-base|Knowledge Base"
)
```

Leave empty (`declare -a BRANCHES=()`) for auto-discovery.

---

## `lint.sh`

Programmatic wiki health checks — deterministic, no LLM needed. Writes `lint-report.md` at the consumer's git root.

**What it does:**
1. Resolves the consumer git root (no-ops if not inside a wiki project).
2. Checks:
   - **Ghost links** — `[[branch/slug]]` pointing to non-existent wiki pages (error).
   - **Orphan pages** — wiki pages with zero incoming `[[ ]]` links (warning).
   - **Format violations** — first line not `# title`, path contains uppercase or underscore, page not under a branch subfolder (error).
   - **Outdated markers** — temporal patterns that need verification (warning).
   - **Missing summaries** — no `> summary` line under the title (warning).
   - **Compile debt** — the output of `debt.sh` (warning).

**Invoked by:** `stop-hook.sh` (end of every turn) and by `/atomic-wiki:lint`.

**Tuning the outdated-marker regex:**

The default pattern is intentionally tight:

```
currently v[0-9]|latest v[0-9]|just released|recently released|brand new|newly released
```

Loose patterns (`currently|now|today`) flood the report with false positives. If your knowledge base uses different temporal conventions, edit the `PATTERNS` variable in `lint.sh`.

---

## `debt.sh`

Lists the compile debt: what the atoms say that the wiki pages do not yet. One line per item:

- `uncompiled <atom id>` — no page footer names the atom.
- `stale <atom id> <page slug>` — the footer names an older `version:` of the atom.
- `gone <atom id> <page slug>` — the footer names an atom that no longer exists.

It reads each page's `*Compiled from atoms: id@version, ...*` footer; an entry without `@version` counts as version 1. `--count` prints only the number of lines.

**Invoked by:** `lint.sh`, `stop-hook.sh` and `/atomic-wiki:compile pending`.

---

## `stop-hook.sh`

The plugin's `Stop` hook. It runs `lint.sh`, then counts the compile debt:

- under 8 lines: nothing more happens;
- 8 to 40: Claude does not stop; it is told to run `/atomic-wiki:compile pending` and report;
- over 40: you get a one-line message instead, and run the compile when you choose.

It asks once per debt state (the last one is kept in the git directory, outside the work tree), so a list that a compile pass could not clear does not bring Claude back every turn. To change the two limits, edit `THRESHOLD` and `BULK` at the top of the script.

---

## `check-version-bump.sh`

Validates that a staged atom whose body changed beyond whitespace has a bumped `version:` integer in its frontmatter.

**What it checks:**
- New atoms must declare `version: 1`.
- For modified atoms, compares the staged file against `HEAD` ignoring whitespace and blank lines. If anything substantive changed, `version:` must be strictly greater than the previous value.
- Pure formatting commits (reflow, blank-line fixes) pass without a bump.

Exit 0 = clean. Exit 1 = one or more violations.

**Usage:** Vendored into a consumer's committed `.wiki/` directory by `/atomic-wiki:init` and registered as a git pre-commit hook by `install-versionbump-hook.sh`.

---

## `install-versionbump-hook.sh`

Registers `check-version-bump.sh` as a git pre-commit hook in the consumer's repository. For git ≥ 2.54, uses the config-based hook mechanism; otherwise falls back to writing `.git/hooks/pre-commit` directly.

**Invoked by:** `/atomic-wiki:init` during project setup. This is a per-clone operation — re-run `/atomic-wiki:init` after cloning a consumer repository to re-register the hook.

---

## Run order after any change

The atomic-wiki plugin handles this automatically via its hooks:

- `PostToolUse` on Write/Edit of `wiki/**/*.md` → `gen-index.sh`
- `Stop` at end of turn → `stop-hook.sh` (`lint.sh`, then the compile-debt check)
- git pre-commit (installed by `/atomic-wiki:init`) → `check-version-bump.sh`

If driving the repo manually:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/gen-index.sh"    # rebuild index
bash "${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh"          # programmatic health check
git commit ...                                         # pre-commit hook enforces atom version bumps
```

If `lint.sh` reports errors, fix them before committing. Warnings can be deferred to an LLM Lint pass. Change history lives in `git log` — there is no separate change-log file.
