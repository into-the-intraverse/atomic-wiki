# scripts/

Maintenance scripts. All shell, no dependencies beyond `bash`, `grep`, `sed`, `awk`, `sort`, `find`, `git`.

---

## `gen-index.sh`

Rebuilds `index.md` at the repo root from `wiki/<branch>/<page>.md` filenames and first-line titles.

**Usage:**
```bash
./scripts/gen-index.sh
```

**What it does:**
1. Walks each `wiki/<branch>/` subfolder
2. Reads the first line of each page (must be `# Title`) for display
3. Writes the grouped, alphabetically-sorted index to `index.md`

**Configuration:**

By default, branches are auto-discovered from the subfolders of `wiki/` and display names are capitalized automatically. To control order and display names (e.g., custom capitalization like "MCP" instead of "Mcp"), edit the `BRANCHES` override array at the top of the script:

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

Programmatic health check — four deterministic checks, no LLM needed.

**Usage:**
```bash
./scripts/lint.sh
```

**Checks:**

1. **Ghost links** — `[[branch/slug]]` pointing to non-existent wiki pages (→ error)
2. **Orphan pages** — wiki pages with zero incoming `[[ ]]` links (→ warning)
3. **Format violations** — first line not `# title`, path contains uppercase or underscore, page not under a branch subfolder (→ error)
4. **Outdated markers** — temporal patterns that need verification (→ warning)

**Output:** `lint-report.md` at the repo root, with counts summary and per-page findings.

**Tuning the outdated-marker regex:**

The default pattern is intentionally tight:

```
currently v[0-9]|latest v[0-9]|just released|recently released|brand new|newly released
```

Loose patterns (`currently|now|today`) flood the report with false positives from rhetorical use. Tight patterns catch actual version/release-event claims.

If your knowledge base uses different temporal conventions, edit the `PATTERNS` variable in `lint.sh`.

**After programmatic lint passes:** run an LLM Lint pass for semantic checks (contradictions, concept gaps, expired claims). The LLM reads `index.md` + all wiki pages, then appends findings to `lint-report.md`. See `METHODOLOGY.md` for the LLM Lint procedure.

---

## `check-version-bump.sh`

Verifies that staged atom files include a `version:` bump whenever the body changed beyond whitespace.

**Usage:**

Direct (rare — usually run via the pre-commit hook):
```bash
./scripts/check-version-bump.sh
```

**What it checks:**
- New atoms must declare `version: 1` in frontmatter.
- For modified atoms, compares the staged file against `HEAD` ignoring whitespace and blank lines. If anything substantive changed, the integer in `version:` must be strictly greater than the previous value.
- Pure formatting commits (reflow, blank-line fixes) pass without a bump.

Exit 0 = clean. Exit 1 = one or more violations.

---

## `hooks/pre-commit` and `install-hooks.sh`

The pre-commit hook calls `check-version-bump.sh` so a forgotten version bump is caught before the commit lands. Install once per clone:

```bash
./scripts/install-hooks.sh
```

This copies `scripts/hooks/pre-commit` into `.git/hooks/pre-commit` and makes it executable. From then on, every `git commit` runs the check.

The `SessionStart` hook in `.claude/settings.json` runs this automatically when Claude Code opens the repo, so you usually don't need to invoke it by hand.

---

## Run order after any change

If you're driving the repo with Claude Code, two hooks in `.claude/settings.json` handle this:

- `PostToolUse` on Write/Edit of `wiki/**/*.md` → `gen-index.sh`
- `Stop` at end of turn → `lint.sh`

If you're driving it manually:

```bash
./scripts/gen-index.sh    # rebuild index
./scripts/lint.sh         # programmatic health check
git commit ...            # pre-commit hook enforces atom version bumps
```

If `lint.sh` reports errors, fix them before committing. Warnings can be deferred to an LLM Lint pass. Change history lives in `git log` — there is no separate change-log file.

---

## Making scripts executable

On first clone:

```bash
chmod +x scripts/*.sh scripts/hooks/*
./scripts/install-hooks.sh
```

Windows users: run under Git Bash, WSL, or adapt the scripts to PowerShell.
