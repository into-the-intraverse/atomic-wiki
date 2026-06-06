# Atomic Wiki Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the `llm-atomic-wiki` repo into an installable Claude Code plugin named `atomic-wiki` whose machinery (skills, scripts, hooks, schema, templates) applies to any project, with content living in each consumer's git root.

**Architecture:** The repo root becomes the plugin root (`.claude-plugin/plugin.json`). Skills move to `skills/`. Bundled bash scripts resolve the *consumer's* git root (`git rev-parse --show-toplevel`) and no-op outside wiki projects. Hooks (`hooks/hooks.json`) regenerate the index on wiki edits and run the fast lint on Stop (Model A); the expensive semantic lint is left to a scheduled routine. A new `/wiki-init` skill scaffolds a project and registers the version-bump pre-commit using Git 2.54 config-based hooks (file-based fallback for older git).

**Tech Stack:** Bash scripts (run via git-bash on Windows), JSON config (plugin/marketplace/hooks), Markdown skills. Tests are plain-bash harnesses using `mktemp -d` scratch git repos (no bats dependency). Skills are authored/edited with the `superpowers:writing-skills` skill.

**Reference spec:** `docs/superpowers/specs/2026-06-06-atomic-wiki-plugin-design.md`

---

## File Structure

**Create:**
- `.claude-plugin/plugin.json` — plugin manifest (name, version, hooks pointer)
- `.claude-plugin/marketplace.json` — single-plugin marketplace entry
- `hooks/hooks.json` — PostToolUse(gen-index) + Stop(lint)
- `reference/SCHEMA.md` — the spec (moved from `CLAUDE.md`)
- `templates/atom.md` — moved from `atoms/_template.md`
- `templates/wiki-page.md` — moved from `wiki/_template.md`
- `skills/init/SKILL.md` — the `/wiki-init` scaffolder (authored via writing-skills)
- `scripts/install-versionbump-hook.sh` — registers the pre-commit hook (config-based or fallback)
- `tests/test-gen-index.sh`, `tests/test-lint.sh`, `tests/test-versionbump-install.sh` — bash test harnesses

**Modify:**
- `scripts/gen-index.sh` — resolve consumer git root + guard
- `scripts/lint.sh` — resolve consumer git root + guard
- `.claude/settings.json` — remove the hooks (plugin provides them now)
- `CLAUDE.md` — replace spec content with a thin "this is the plugin source" dev note
- `skills/ingest|compile|lint|query/SKILL.md` — inline needed schema rules; fix script refs to `${CLAUDE_PLUGIN_ROOT}`
- `README.md` — plugin install + usage

**Move (git mv):**
- `.claude/skills/{ingest,compile,lint,query}/` → `skills/{...}/`

**Delete:**
- `scripts/install-hooks.sh` and `scripts/hooks/pre-commit` — superseded by `install-versionbump-hook.sh` (which generates the fallback hook inline)
- `atoms/`, `wiki/`, `raw/`, `_inbox/` (content scaffolding) and `atoms/README.md` — recreated in consumers by `/wiki-init`

**Unchanged:**
- `scripts/check-version-bump.sh` — already git-relative (`git rev-parse --show-toplevel`); works as a vendored copy
- `METHODOLOGY.md` — stays as the "why" doc

---

## Task 1: Relocate schema and templates

**Files:**
- Move: `CLAUDE.md` → `reference/SCHEMA.md`
- Create: `CLAUDE.md` (new thin dev note)
- Move: `atoms/_template.md` → `templates/atom.md`
- Move: `wiki/_template.md` → `templates/wiki-page.md`

- [ ] **Step 1: Move the spec and templates with git**

```bash
cd "D:/code/llm-atomic-wiki"
mkdir -p reference templates
git mv CLAUDE.md reference/SCHEMA.md
git mv atoms/_template.md templates/atom.md
git mv wiki/_template.md templates/wiki-page.md
```

- [ ] **Step 2: Write the thin dev CLAUDE.md**

Create `CLAUDE.md` with exactly:

```markdown
# CLAUDE.md — atomic-wiki plugin source

This repo is the source of the **atomic-wiki** Claude Code plugin (machinery only — no wiki content).

- The operating spec for the pipeline lives in [reference/SCHEMA.md](reference/SCHEMA.md).
- To develop/test the plugin locally: `claude --plugin-dir .`
- Skills are in `skills/`, bundled scripts in `scripts/`, hooks in `hooks/hooks.json`.
- Consumer projects get their own `atoms/`, `wiki/`, `raw/` via the `/atomic-wiki:init` skill.

When editing a `SKILL.md`, use the `superpowers:writing-skills` skill.
```

- [ ] **Step 3: Verify the moves**

Run:
```bash
ls reference/SCHEMA.md templates/atom.md templates/wiki-page.md && head -1 CLAUDE.md
```
Expected: all three paths listed, and `# CLAUDE.md — atomic-wiki plugin source`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move spec to reference/SCHEMA.md and templates/ for plugin layout"
```

---

## Task 2: Add plugin manifest and marketplace

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "atomic-wiki",
  "displayName": "Atomic Wiki",
  "version": "0.1.0",
  "description": "Ingest -> atoms -> compile -> wiki -> query pipeline with automated lint maintenance",
  "author": { "name": "aleksej pawlowskij", "email": "1394349+into-the-intraverse@users.noreply.github.com" },
  "hooks": "./hooks/hooks.json"
}
```

- [ ] **Step 2: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "atomic-wiki",
  "owner": { "name": "aleksej pawlowskij" },
  "plugins": [
    {
      "name": "atomic-wiki",
      "source": ".",
      "description": "Ingest -> atoms -> compile -> wiki -> query pipeline with automated lint maintenance"
    }
  ]
}
```

- [ ] **Step 3: Validate JSON parses**

Run:
```bash
node -e "JSON.parse(require('fs').readFileSync('.claude-plugin/plugin.json')); JSON.parse(require('fs').readFileSync('.claude-plugin/marketplace.json')); console.log('json ok')"
```
Expected: `json ok`

- [ ] **Step 4: Validate the plugin (if the CLI subcommand exists)**

Run:
```bash
claude plugin validate . || echo "validate-unavailable"
```
Expected: a success message, or `validate-unavailable` (older CLI). Note: `hooks/hooks.json` does not exist yet, so a validator may warn about the missing path — that is expected and resolved in Task 6.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat: add atomic-wiki plugin manifest and marketplace"
```

---

## Task 3: Move skills into the plugin layout

**Files:**
- Move: `.claude/skills/{ingest,compile,lint,query}/` → `skills/{ingest,compile,lint,query}/`

- [ ] **Step 1: Move the four skill folders**

```bash
mkdir -p skills
git mv .claude/skills/ingest  skills/ingest
git mv .claude/skills/compile skills/compile
git mv .claude/skills/lint    skills/lint
git mv .claude/skills/query   skills/query
```

- [ ] **Step 2: Verify**

Run:
```bash
ls skills/ingest/SKILL.md skills/compile/SKILL.md skills/lint/SKILL.md skills/query/SKILL.md
```
Expected: all four paths listed.

- [ ] **Step 3: Confirm the plugin exposes the commands**

Run:
```bash
claude --plugin-dir . --help >/dev/null 2>&1 && echo "loaded"
```
Expected: `loaded`. (Manual confirmation: in an interactive `claude --plugin-dir .` session, `/atomic-wiki:ingest`, `/atomic-wiki:compile`, `/atomic-wiki:lint`, `/atomic-wiki:query` appear.)

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: move skills to skills/ for plugin packaging"
```

---

## Task 4: Rewrite `gen-index.sh` to resolve the consumer git root (TDD)

**Files:**
- Test: `tests/test-gen-index.sh`
- Modify: `scripts/gen-index.sh:8-9`

- [ ] **Step 1: Write the failing test**

Create `tests/test-gen-index.sh`:

```bash
#!/bin/bash
# Verifies gen-index.sh resolves the CONSUMER git root and no-ops outside wiki projects.
set -u
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$PLUGIN_DIR/scripts/gen-index.sh"
fail=0

# Case 1: a wiki project -> index.md is written at the project root with the page listed.
t1="$(mktemp -d)"; git -C "$t1" init -q
mkdir -p "$t1/wiki/mcp"; printf '# Auth\n\nbody\n' > "$t1/wiki/mcp/auth.md"
( cd "$t1" && CLAUDE_PROJECT_DIR="$t1" bash "$GEN" >/dev/null 2>&1 )
if [ -f "$t1/index.md" ] && grep -q 'mcp/auth' "$t1/index.md"; then echo "PASS case1"; else echo "FAIL case1"; fail=1; fi

# Case 2: a git repo WITHOUT wiki/ -> no-op, no index.md created.
t2="$(mktemp -d)"; git -C "$t2" init -q
( cd "$t2" && CLAUDE_PROJECT_DIR="$t2" bash "$GEN" >/dev/null 2>&1 )
if [ ! -f "$t2/index.md" ]; then echo "PASS case2"; else echo "FAIL case2"; fail=1; fi

# Case 3: a non-git directory -> exit 0, no error, no file.
t3="$(mktemp -d)"
( cd "$t3" && CLAUDE_PROJECT_DIR="$t3" bash "$GEN" >/dev/null 2>&1 ); rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$t3/index.md" ]; then echo "PASS case3"; else echo "FAIL case3 rc=$rc"; fail=1; fi

rm -rf "$t1" "$t2" "$t3"
exit $fail
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
bash tests/test-gen-index.sh
```
Expected: FAIL case1 (the current script computes `WIKI_DIR` relative to its own location in the plugin, so it does not write to the scratch project root), nonzero exit.

- [ ] **Step 3: Edit `scripts/gen-index.sh`**

Replace these two lines (currently lines 8–9):

```bash
WIKI_DIR="$(cd "$(dirname "$0")/../wiki" && pwd)"
INDEX="$WIKI_DIR/../index.md"
```

with:

```bash
ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -d "$ROOT/wiki" ] || exit 0      # not a wiki project -> no-op silently
WIKI_DIR="$ROOT/wiki"
INDEX="$ROOT/index.md"
```

Leave the rest of the script unchanged.

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
bash tests/test-gen-index.sh
```
Expected: `PASS case1`, `PASS case2`, `PASS case3`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/gen-index.sh tests/test-gen-index.sh
git commit -m "feat: gen-index resolves consumer git root and no-ops outside wiki projects"
```

---

## Task 5: Rewrite `lint.sh` to resolve the consumer git root (TDD)

**Files:**
- Test: `tests/test-lint.sh`
- Modify: `scripts/lint.sh:6-7`

- [ ] **Step 1: Write the failing test**

Create `tests/test-lint.sh`:

```bash
#!/bin/bash
# Verifies lint.sh resolves the CONSUMER git root and no-ops outside wiki projects.
set -u
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LINT="$PLUGIN_DIR/scripts/lint.sh"
fail=0

# Case 1: a wiki project -> lint-report.md is written at the project root.
t1="$(mktemp -d)"; git -C "$t1" init -q
mkdir -p "$t1/wiki/mcp"; printf '# Auth\n\nbody\n' > "$t1/wiki/mcp/auth.md"
( cd "$t1" && CLAUDE_PROJECT_DIR="$t1" bash "$LINT" >/dev/null 2>&1 )
if [ -f "$t1/lint-report.md" ]; then echo "PASS case1"; else echo "FAIL case1"; fail=1; fi

# Case 2: a git repo WITHOUT wiki/ -> no-op, no report.
t2="$(mktemp -d)"; git -C "$t2" init -q
( cd "$t2" && CLAUDE_PROJECT_DIR="$t2" bash "$LINT" >/dev/null 2>&1 )
if [ ! -f "$t2/lint-report.md" ]; then echo "PASS case2"; else echo "FAIL case2"; fail=1; fi

rm -rf "$t1" "$t2"
exit $fail
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
bash tests/test-lint.sh
```
Expected: FAIL case1, nonzero exit (current script writes the report next to the plugin's own `wiki/`, not the scratch root).

- [ ] **Step 3: Edit `scripts/lint.sh`**

Replace these two lines (currently lines 6–7):

```bash
WIKI_DIR="$(cd "$(dirname "$0")/../wiki" && pwd)"
REPORT="$WIKI_DIR/../lint-report.md"
```

with:

```bash
ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -d "$ROOT/wiki" ] || exit 0      # not a wiki project -> no-op silently
WIKI_DIR="$ROOT/wiki"
REPORT="$ROOT/lint-report.md"
```

Leave the rest of the script unchanged.

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
bash tests/test-lint.sh
```
Expected: `PASS case1`, `PASS case2`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/lint.sh tests/test-lint.sh
git commit -m "feat: lint resolves consumer git root and no-ops outside wiki projects"
```

---

## Task 6: Add plugin hooks and remove the repo's own hooks

**Files:**
- Create: `hooks/hooks.json`
- Modify: `.claude/settings.json`

- [ ] **Step 1: Write `hooks/hooks.json`**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash",
            "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/gen-index.sh"],
            "if": "Write(**/wiki/**)|Edit(**/wiki/**)"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash",
            "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh"]
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Strip the hooks from `.claude/settings.json`**

Replace the entire file contents with:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json"
}
```

(The SessionStart/PostToolUse/Stop hooks were repo-local; the plugin now owns PostToolUse + Stop, and the git-hook install moves into `/wiki-init`. Removing them prevents double-firing when dev-loading via `--plugin-dir`.)

- [ ] **Step 3: Validate JSON + plugin**

Run:
```bash
node -e "JSON.parse(require('fs').readFileSync('hooks/hooks.json')); JSON.parse(require('fs').readFileSync('.claude/settings.json')); console.log('json ok')"
claude plugin validate . || echo "validate-unavailable"
```
Expected: `json ok`, then a success message or `validate-unavailable`.

- [ ] **Step 4: Manual hook smoke check**

In an interactive `claude --plugin-dir .` session opened inside a scratch wiki repo (one with a `wiki/` folder under a git root), edit a file under `wiki/` and confirm `index.md` is regenerated. Editing a non-wiki file must NOT regenerate it. (Documented here; not scriptable in the harness because hooks fire inside a Claude session.)

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json .claude/settings.json
git commit -m "feat: ship gen-index/lint as plugin hooks; drop repo-local hooks"
```

---

## Task 7: Version-bump hook installer (config-based + fallback) (TDD)

**Files:**
- Create: `scripts/install-versionbump-hook.sh`
- Test: `tests/test-versionbump-install.sh`
- Delete: `scripts/install-hooks.sh`, `scripts/hooks/pre-commit`

- [ ] **Step 1: Write the failing test**

Create `tests/test-versionbump-install.sh`:

```bash
#!/bin/bash
# Verifies the installer vendors the check script and registers a working pre-commit hook
# (config-based on git >= 2.54, else file-based), and that the hook rejects an unbumped body change.
set -u
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$PLUGIN_DIR/scripts/install-versionbump-hook.sh"
fail=0

t="$(mktemp -d)"; git -C "$t" init -q
git -C "$t" config user.email t@t.t; git -C "$t" config user.name t

# Run the installer from inside the scratch repo (as /wiki-init would).
( cd "$t" && bash "$INSTALLER" >/dev/null 2>&1 )

# Vendored script must exist.
if [ -f "$t/.wiki/check-version-bump.sh" ]; then echo "PASS vendored"; else echo "FAIL vendored"; fail=1; fi

# A new atom with version: 1 commits fine.
mkdir -p "$t/atoms/x"
printf -- '---\nid: x/a\nversion: 1\n---\n\nbody one\n' > "$t/atoms/x/a.md"
git -C "$t" add atoms/x/a.md
if git -C "$t" commit -q -m "add atom"; then echo "PASS commit-new"; else echo "FAIL commit-new"; fail=1; fi

# Editing the body without bumping version must be REJECTED.
printf -- '---\nid: x/a\nversion: 1\n---\n\nbody two changed\n' > "$t/atoms/x/a.md"
git -C "$t" add atoms/x/a.md
if git -C "$t" commit -q -m "change body no bump"; then echo "FAIL reject"; fail=1; else echo "PASS reject"; fi

rm -rf "$t"
exit $fail
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
bash tests/test-versionbump-install.sh
```
Expected: FAIL vendored (installer does not exist yet), nonzero exit.

- [ ] **Step 3: Write `scripts/install-versionbump-hook.sh`**

```bash
#!/bin/bash
# Register the atom version-bump check as a pre-commit hook in the CURRENT git repo.
# Uses Git 2.54+ config-based hooks when available, else falls back to a .git/hooks/pre-commit file.
# Idempotent. Safe to re-run (e.g. after a fresh clone).
set -e

ROOT="$(git rev-parse --show-toplevel)"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Vendor the (git-relative) check script into the repo so it survives plugin updates and is committed.
mkdir -p "$ROOT/.wiki"
cp "$HERE/check-version-bump.sh" "$ROOT/.wiki/check-version-bump.sh"
chmod +x "$ROOT/.wiki/check-version-bump.sh"

# Parse git version major.minor.
gv="$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)"
gmaj="${gv%%.*}"; gmin="${gv#*.}"

if [ "$gmaj" -gt 2 ] || { [ "$gmaj" -eq 2 ] && [ "$gmin" -ge 54 ]; }; then
  # Config-based hook (coexists with any existing .git/hooks/pre-commit).
  git config --local hook.atomic-wiki-versionbump.event pre-commit
  git config --local hook.atomic-wiki-versionbump.command "$ROOT/.wiki/check-version-bump.sh"
  echo "atomic-wiki: registered config-based pre-commit hook (git $gv)."
else
  # File-based fallback. Generate a pre-commit that calls the vendored script.
  HOOK="$ROOT/.git/hooks/pre-commit"
  if [ -e "$HOOK" ] && ! grep -q 'atomic-wiki' "$HOOK" 2>/dev/null; then
    echo "atomic-wiki: WARNING existing $HOOK left untouched; add a call to .wiki/check-version-bump.sh manually." >&2
  else
    printf '#!/bin/bash\n# atomic-wiki version-bump check\nexec "$(git rev-parse --show-toplevel)/.wiki/check-version-bump.sh"\n' > "$HOOK"
    chmod +x "$HOOK"
    echo "atomic-wiki: installed file-based pre-commit hook (git $gv)."
  fi
fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
bash tests/test-versionbump-install.sh
```
Expected: `PASS vendored`, `PASS commit-new`, `PASS reject`, exit 0.

- [ ] **Step 5: Remove the superseded hook installer and static hook**

```bash
git rm scripts/install-hooks.sh scripts/hooks/pre-commit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/install-versionbump-hook.sh tests/test-versionbump-install.sh
git commit -m "feat: version-bump hook installer (git 2.54 config-based + file fallback)"
```

---

## Task 8: Author the `/wiki-init` skill

**Files:**
- Create: `skills/init/SKILL.md`

- [ ] **Step 1: Author the skill with `superpowers:writing-skills`**

Invoke the `superpowers:writing-skills` skill to create `skills/init/SKILL.md`. The skill must instruct Claude to perform, at the consumer's git root (`git rev-parse --show-toplevel`):

1. Create `atoms/`, `wiki/`, `raw/` each with a `.gitkeep`.
2. Copy `${CLAUDE_PLUGIN_ROOT}/templates/atom.md` → `atoms/_template.md` and `${CLAUDE_PLUGIN_ROOT}/templates/wiki-page.md` → `wiki/_template.md`.
3. Ensure `.gitignore` contains `index.md` and `lint-report.md` (append if missing; do not duplicate).
4. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-versionbump-hook.sh"` to register the pre-commit hook.
5. Optionally append a 2-line pointer to the consumer's `CLAUDE.md` noting the project uses atomic-wiki (`/atomic-wiki:ingest`, `compile`, `lint`, `query`) — only if the user confirms.

Frontmatter `description` must make it auto-discoverable, e.g.: "Scaffold an atomic-wiki project (atoms/, wiki/, templates, .gitignore, version-bump git hook) in the current repo. Use when the user runs /wiki-init or wants to set up the atomic-wiki pipeline in a project."

The body must reference bundled assets via `${CLAUDE_PLUGIN_ROOT}` (never repo-relative `./scripts`), and target data paths via the git root. Include a note that step 4 is re-run after a fresh clone (git hook config is per-clone).

- [ ] **Step 2: Verify the skill loads and is well-formed**

Run:
```bash
test -f skills/init/SKILL.md && head -3 skills/init/SKILL.md
claude --plugin-dir . --help >/dev/null 2>&1 && echo "loaded"
```
Expected: frontmatter visible, `loaded`.

- [ ] **Step 3: Manual end-to-end check**

In `claude --plugin-dir .` opened in a fresh scratch git repo, run `/atomic-wiki:init` and confirm: `atoms/ wiki/ raw/` created with `.gitkeep`, both `_template.md` copied, `.gitignore` updated, `.wiki/check-version-bump.sh` present, and `git hook list pre-commit` (git ≥ 2.54) shows `atomic-wiki-versionbump`.

- [ ] **Step 4: Commit**

```bash
git add skills/init/SKILL.md
git commit -m "feat: add /wiki-init scaffolder skill"
```

---

## Task 9: Inline schema rules and fix script references in the four skills

**Files:**
- Modify: `skills/ingest/SKILL.md`, `skills/compile/SKILL.md`, `skills/lint/SKILL.md`, `skills/query/SKILL.md`

- [ ] **Step 1: Edit each skill with `superpowers:writing-skills`**

For each of the four skills, invoke `superpowers:writing-skills` to:

1. Replace any reference to the old ambient `CLAUDE.md` spec with a pointer to `${CLAUDE_PLUGIN_ROOT}/reference/SCHEMA.md`.
2. Inline the specific rules that skill needs so it works without an ambient spec:
   - `ingest`: the atom frontmatter format, the one-claim rule, and the branch-design criteria (independence / scale / clear boundary / teaching independence; "do not invent branches without user approval").
   - `compile`: the wiki page format (first line `# Title`, `[[branch/slug]]` links, length targets) and the rule "fix the atom, never patch the wiki"; add a final step that runs `bash "${CLAUDE_PLUGIN_ROOT}/scripts/gen-index.sh"`.
   - `lint`: that the programmatic layer is `${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh`, plus the in-session version-bump validation (flag atoms whose body changed vs `HEAD` without a `version:` increase) and the LLM semantic checks.
   - `query`: keep behavior; ensure it reads the consumer's `index.md` at the git root (no path change needed, but remove any CLAUDE.md reference).
3. Change any `bash ./scripts/...` invocation to `bash "${CLAUDE_PLUGIN_ROOT}/scripts/..."`.
4. Reference templates as `${CLAUDE_PLUGIN_ROOT}/templates/atom.md` / `templates/wiki-page.md` where a template is mentioned.

- [ ] **Step 2: Verify no stale references remain**

Run:
```bash
grep -rn "CLAUDE.md\|\./scripts\|\.\./wiki" skills/ || echo "no stale refs"
```
Expected: `no stale refs` (any remaining hit must be intentional and explained; otherwise fix it).

- [ ] **Step 3: Commit**

```bash
git add skills/
git commit -m "refactor: inline schema rules and use CLAUDE_PLUGIN_ROOT in skills"
```

---

## Task 10: Update README and remove content scaffolding

**Files:**
- Modify: `README.md`
- Delete: `atoms/` (incl. `atoms/README.md`), `wiki/`, `raw/`, `_inbox/` if present

- [ ] **Step 1: Rewrite `README.md`** as the plugin's install + usage doc. It must contain:
  - One-paragraph description of the pipeline (raw → atoms → wiki → query) and the layering (plugin = machinery, consumer = content).
  - Install:
    ```
    /plugin marketplace add D:/code/llm-atomic-wiki     # or the GitHub repo
    /plugin install atomic-wiki@atomic-wiki
    ```
    Dev: `claude --plugin-dir .`
  - Per-project setup: run `/atomic-wiki:init`, then `/atomic-wiki:ingest`, `compile`, `lint`, `query`.
  - The automation model (Model A): index + fast lint run on hooks; the semantic lint runs on a schedule (point to `/schedule`).
  - A note that the version-bump hook is per-clone (re-run `/atomic-wiki:init` after cloning).
  - A pointer to `METHODOLOGY.md` (why) and `reference/SCHEMA.md` (spec).

- [ ] **Step 2: Remove leftover content scaffolding from the machinery repo**

```bash
git rm -r --ignore-unmatch atoms wiki raw _inbox
```
Expected: removes `atoms/README.md` and any empty content dirs still tracked. (Untracked leftovers, if any, remove with `rm -rf atoms wiki raw _inbox`.)

- [ ] **Step 3: Verify the final tree matches the spec layout**

Run:
```bash
ls -1 ; echo "---" ; ls .claude-plugin skills scripts hooks templates reference
```
Expected: top level shows `.claude-plugin .gitignore CLAUDE.md METHODOLOGY.md README.md docs hooks reference scripts skills templates` (no `atoms/ wiki/ raw/ _inbox/`); the listed subdirs contain the expected files.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: plugin README; remove content scaffolding from machinery repo"
```

---

## Task 11: End-to-end smoke test (whole pipeline)

**Files:** none (verification only)

- [ ] **Step 1: Run all bash unit tests**

Run:
```bash
for t in tests/test-*.sh; do echo "== $t =="; bash "$t" || echo "FAILED: $t"; done
```
Expected: every case prints `PASS`, no `FAILED:` line.

- [ ] **Step 2: Install via the local marketplace**

Run (interactive Claude):
```
/plugin marketplace add D:/code/llm-atomic-wiki
/plugin install atomic-wiki@atomic-wiki
```
Expected: install succeeds; `/atomic-wiki:init|ingest|compile|lint|query` are listed. If the marketplace `source` is rejected, adjust `.claude-plugin/marketplace.json` `source` (try `"./"` or `{ "source": "local", "path": "." }`) and re-run — this resolves spec §10 open item.

- [ ] **Step 3: Scaffold a fresh consumer project**

In a new scratch git repo opened with the installed plugin, run `/atomic-wiki:init`. Confirm `atoms/ wiki/ raw/` + templates + `.gitignore` + `.wiki/check-version-bump.sh` + the registered git hook.

- [ ] **Step 4: Exercise the pipeline + automation**

- Create an atom under `atoms/<branch>/` (version: 1); run `/atomic-wiki:compile`; confirm a `wiki/<branch>/` page and a regenerated `index.md`.
- Edit the wiki page → confirm the `PostToolUse` hook regenerated `index.md`.
- End a turn → confirm the `Stop` hook wrote `lint-report.md` (and that it does NOT in a non-wiki repo).
- Edit an atom body without bumping `version:` and attempt `git commit` → rejected; bump the version → commit succeeds.

- [ ] **Step 5: Final commit (if any verification fixes were needed)**

```bash
git add -A
git commit -m "test: end-to-end smoke verification for atomic-wiki plugin" --allow-empty
```

---

## Self-Review

**Spec coverage** (against `2026-06-06-atomic-wiki-plugin-design.md`):
- §2 name `atomic-wiki` → Task 2. Marketplace → Task 2, Task 11. Content moved out → already done + Task 10. Git-root scripts → Tasks 4–5. Model A → Task 6 (+ semantic-on-schedule documented in README Task 10). Config-based hooks → Task 7. Schema relocation → Task 1 + Task 9.
- §3 layout → Tasks 1, 2, 3, 6, 10 (verified in Task 10 Step 3).
- §4.1 plugin.json → Task 2. §4.2 marketplace → Task 2/11. §4.3 scripts → Tasks 4–5. §4.4 hooks.json → Task 6. §4.5 schema → Task 1/9. §4.6 templates → Task 1.
- §5 automation → Task 6 (hooks) + README (schedule).
- §6 `/wiki-init` → Task 8 (+ installer Task 7).
- §7 two validators → Task 7 (commit hook) + Task 9 (in-session `/lint` check).
- §8 data flow → exercised in Task 11 Step 4.
- §9 edge cases → covered by tests (Tasks 4,5,7 cases 2/3) + Task 6 Step 4 + Task 11 Step 4.
- §11 migration order → Tasks 1–10. §12 testing → Tasks 4,5,7,11.
- No gaps found.

**Placeholder scan:** All script/JSON/test content is concrete. The only deferred item is the marketplace `source` exact value, which has an explicit fallback procedure in Task 11 Step 2 (not a silent placeholder).

**Type/name consistency:** Hook name `atomic-wiki-versionbump`, vendored path `.wiki/check-version-bump.sh`, and plugin name `atomic-wiki` are used identically across Tasks 7, 8, 11. Script env var `CLAUDE_PROJECT_DIR`/`CLAUDE_PLUGIN_ROOT` usage is consistent across Tasks 4, 5, 6, 8, 9.
