# Atomic Wiki Plugin — Design Spec

> Status: approved design, pre-implementation.
> Date: 2026-06-06.
> Converts the `llm-atomic-wiki` repo from a single working-project into an installable
> Claude Code **plugin** that provides the atomic-wiki pipeline to any project.

---

## 1. Goal & mental model

Today `llm-atomic-wiki` is both the *machinery* (skills, scripts, hooks, schema, templates)
and a *working project* (its own `atoms/`, `wiki/`, `raw/`). We want to split those:

- **Machinery → a plugin** named `atomic-wiki`, installed once and available in every project.
- **Content → each consuming project**, stored at that project's git root (`atoms/`, `wiki/`,
  `raw/`, `index.md`).

The 547 atoms previously generated have already been moved out to `D:\code\_atoms` (a separate,
currently-unversioned content collection) and are **out of scope** for this plugin work.

### Layering

| Layer | Lives in | Examples |
|---|---|---|
| Machinery (shared, updatable) | the plugin | skills, `scripts/*.sh`, `hooks.json`, `reference/SCHEMA.md`, `templates/` |
| Content (per-project) | the consumer's git root | `atoms/<branch>/`, `wiki/<branch>/`, `raw/`, `index.md`, `lint-report.md` |
| Per-project install state | the consumer's repo | vendored `.wiki/check-version-bump.sh`, git hook registration |

---

## 2. Decisions locked

| # | Decision | Choice |
|---|---|---|
| Name | Plugin name | `atomic-wiki` (commands namespace as `/atomic-wiki:<skill>`) |
| Dist | Distribution | Local/GitHub **marketplace** (`.claude-plugin/marketplace.json`); dev via `--plugin-dir` |
| Content | Atoms/wiki content | Moved out to `D:\code\_atoms`; machinery repo holds no content |
| Scripts | Data-root resolution | Scripts resolve the **consumer's git root**, self-guard to no-op outside wiki projects |
| Auto | Automation | **Model A — layered**: fast checks on hooks (default-on, guarded); semantic lint on a schedule |
| Hooks | Git enforcement | **Git 2.54 config-based hooks** for the version-bump pre-commit, with file-based fallback for git < 2.54 |
| Schema | Spec location | `CLAUDE.md` → `reference/SCHEMA.md`; operational rules inlined into each `SKILL.md` |

---

## 3. Target repo layout (this repo becomes the plugin)

```
atomic-wiki/                       (repo root = plugin root)
├── .claude-plugin/
│   ├── plugin.json                manifest (name, version, hooks pointer)
│   └── marketplace.json           single-plugin marketplace entry
├── skills/                        (moved from .claude/skills/)
│   ├── ingest/SKILL.md
│   ├── compile/SKILL.md
│   ├── lint/SKILL.md
│   ├── query/SKILL.md
│   └── init/SKILL.md              NEW — /wiki-init scaffolder
├── hooks/
│   └── hooks.json                 gen-index (PostToolUse, wiki writes) + lint.sh (Stop)
├── scripts/
│   ├── gen-index.sh               (git-root resolution + guard)
│   ├── lint.sh                    (git-root resolution + guard)
│   ├── check-version-bump.sh      (git-relative; vendored into consumers by /wiki-init)
│   └── hooks/pre-commit           (file-based fallback, vendored by /wiki-init)
├── templates/
│   ├── atom.md                    (was atoms/_template.md)
│   └── wiki-page.md               (was wiki/_template.md)
├── reference/
│   └── SCHEMA.md                  the spec (was CLAUDE.md)
├── README.md                      plugin doc / marketplace listing
├── METHODOLOGY.md                 the "why" (plugin doc)
├── CLAUDE.md                      thin — "this is the plugin source; dev via --plugin-dir ."
└── .gitignore
```

Removed from the machinery repo: `atoms/`, `wiki/`, `raw/`, `_inbox/` (content scaffolding;
`/wiki-init` recreates these in consumers). `scripts/install-hooks.sh` is superseded by
`/wiki-init`'s hook-registration logic (may be retained as an internal helper invoked by the skill).

---

## 4. Components

### 4.1 `plugin.json`

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

### 4.2 `marketplace.json`

A single-plugin marketplace whose source is this repo root. Install flow:

```
/plugin marketplace add <path-or-github-repo>
/plugin install atomic-wiki@<marketplace-name>
```

Exact `source` field shape to be confirmed in implementation (see §10).

### 4.3 Scripts — resolve the consumer's git root

`gen-index.sh` and `lint.sh` replace their self-locating `WIKI_DIR="$(dirname "$0")/../wiki"`
with consumer-root resolution + guard:

```bash
ROOT="$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -d "$ROOT/wiki" ] || exit 0      # not a wiki project -> no-op silently
WIKI_DIR="$ROOT/wiki"
```

- `gen-index.sh` writes `$ROOT/index.md`.
- `lint.sh` writes `$ROOT/lint-report.md`.
- The scripts ship in the plugin (`${CLAUDE_PLUGIN_ROOT}/scripts/`) but operate on the consumer's
  root. The two guard lines double as the "stay silent in non-wiki repos" safety.
- `check-version-bump.sh` is unchanged in logic (already uses `git rev-parse --show-toplevel`),
  so a vendored copy works in the consumer repo as-is.

### 4.4 `hooks/hooks.json` — Model A fast layer

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

- Exec-form (`command` + `args`) so Windows paths need no shell quoting.
- `gen-index` is `if`-scoped to wiki-path edits, so it only fires when a wiki page changes.
- `Stop`→`lint.sh` cannot be path-filtered by `if` (Stop has no tool args); it relies on the
  script's git-root guard to no-op outside wiki projects.
- On by default; safe everywhere because of the guards.

### 4.5 Schema relocation

`CLAUDE.md` (the full spec) moves to `reference/SCHEMA.md`. Because plugin content does not
auto-load ambiently, each `SKILL.md` **inlines the rules it needs** (e.g. branch-design criteria
in `ingest`; version/lifecycle rules in `compile` and `lint`) and points to
`${CLAUDE_PLUGIN_ROOT}/reference/SCHEMA.md` for the full spec. No reliance on an ambient project
`CLAUDE.md`. `/wiki-init` may optionally append a 2-line pointer to the consumer's own `CLAUDE.md`.

### 4.6 Templates

`atoms/_template.md` → `templates/atom.md`; `wiki/_template.md` → `templates/wiki-page.md`.
Skills reference them via `${CLAUDE_PLUGIN_ROOT}/templates/`; `/wiki-init` copies them into the
consumer as local starters.

---

## 5. Automation — Model A (layered)

| Check | Cadence | Mechanism |
|---|---|---|
| `gen-index` (rebuild `index.md`) | on wiki edit | `PostToolUse` hook, `if`-scoped to `wiki/**` |
| programmatic `lint.sh` (ghost links, orphans, format, temporal markers) | end of turn | `Stop` hook, git-root-guarded |
| **LLM semantic lint** (the expensive layer) | periodic (e.g. weekly/monthly) | a **scheduled routine** (`/schedule`) targeting a concrete wiki path |

The fast/deterministic layer is live and effectively free via hooks. The expensive semantic audit
runs on a cadence because it is too costly to run every turn. Schedules run detached and therefore
need a concrete target wiki path, so the scheduled semantic lint is configured **per wiki**
(documented in README; optionally a helper command). The central KB at `D:\code\_atoms` is the
first candidate for such a schedule once it has a compiled `wiki/`.

---

## 6. `/wiki-init` (one-time per project)

Scaffolds a wiki project at the consumer's git root:

1. Create `atoms/`, `wiki/`, `raw/` (with `.gitkeep`).
2. Copy `templates/atom.md` → `atoms/_template.md`, `templates/wiki-page.md` → `wiki/_template.md`.
3. Add `index.md` and `lint-report.md` to the project's `.gitignore`.
4. Install version-bump enforcement:
   - Vendor `check-version-bump.sh` → committed `./.wiki/check-version-bump.sh` (stable across
     plugin updates; pointing a hook at the volatile `${CLAUDE_PLUGIN_ROOT}` would go stale on
     every plugin update).
   - Register it as a git hook based on git version:
     - **git ≥ 2.54 → config-based** (preferred):
       ```
       git config --local hook.atomic-wiki-versionbump.event   pre-commit
       git config --local hook.atomic-wiki-versionbump.command "<repo>/.wiki/check-version-bump.sh"
       ```
       Coexists with any existing `.git/hooks/pre-commit` (legacy hooks still run), so no clobber
       guard is needed. Inspect with `git hook list pre-commit`; disable with
       `git config hook.atomic-wiki-versionbump.enabled false`.
     - **git < 2.54 → file-based fallback**: copy `pre-commit` into `.git/hooks/` (guarding an
       existing `pre-commit`).
5. Optionally append a short pointer to the consumer's `CLAUDE.md`.

**Per-clone caveat:** Git deliberately refuses to auto-run hook configuration from a cloned repo
(arbitrary-code-execution risk), so the registration lives in local `.git/config` and is **not**
committed. A fresh clone re-runs `/wiki-init` (or a documented one-liner). The vendored
`.wiki/check-version-bump.sh` *is* committed, so only the registration step repeats.

---

## 7. Version-bump enforcement — two validators, no double-bump

Two checks guard the rule "atom body changed ⇒ `version:` strictly increased":

- **Commit-time** (tool-agnostic): the config-based (or fallback) git pre-commit running
  `check-version-bump.sh`.
- **In-session**: the `/lint` operation flags atoms whose working-tree body changed vs `HEAD`
  without a bump.

Both only **assert** the invariant; neither writes the version. Bumping stays a deliberate edit.
Two validators of the same invariant cannot double-increment. (Double/multi-bump is only a risk
with an *auto-incrementer*, especially one on `PostToolUse(Edit)` firing per edit — explicitly
avoided.)

---

## 8. Data flow

```
raw/         --/ingest-->   atoms/<branch>/*.md            (version: 1)
atoms/       --/compile-->  wiki/<branch>/*.md  + gen-index -> index.md
wiki write   --PostToolUse hook--> gen-index -> index.md
end of turn  --Stop hook--> lint.sh -> lint-report.md      (programmatic health)
git commit   --pre-commit (config/file)--> check-version-bump.sh (validate bumps)
schedule     --routine--> full /lint (programmatic + LLM semantic) -> report
question     --/query--> read index.md + selected pages -> answer
```

---

## 9. Error handling / edge cases

- **Non-wiki project / non-git dir:** `gen-index.sh` and `lint.sh` exit 0 silently (git-root +
  `wiki/` guards). The global `Stop` hook is therefore safe in every project.
- **Plugin update changes `${CLAUDE_PLUGIN_ROOT}`:** hooks resolve it dynamically, so they keep
  working. The only path that must survive updates — the vendored version-bump script — lives in
  the consumer's `.wiki/`, not the plugin. No staleness.
- **git < 2.54:** config-based hook is silently ignored; `/wiki-init` detects the version and uses
  the file-based fallback so enforcement is never silently lost.
- **Existing consumer `pre-commit`:** config-based hooks coexist (no clobber); the file-based
  fallback guards an existing file.
- **Cross-platform (Windows):** hooks invoke `bash` via exec-form `args`; the consumer needs
  `bash` (git-bash) on PATH — already the case in this environment. Scripts are bash.

---

## 10. Open items to verify during implementation

- Exact `if` glob base for the `PostToolUse` path filter (`Write(**/wiki/**)` vs project-relative)
  — the script's git-root guard is the reliable backstop regardless.
- Working directory of a config-based hook `command` — doesn't affect us (script self-resolves its
  root; we register an absolute path), but worth confirming.
- Exact `marketplace.json` `source` field shape for a plugin at the repo root.
- Skill authoring uses the **`superpowers:writing-skills`** skill for every new/edited `SKILL.md`
  (user-confirmed 2026-06-06). No `/skill-creator` dependency.

---

## 11. Migration steps (this repo → plugin)

1. Move `.claude/skills/*` → `skills/*`.
2. Add `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
3. Add `hooks/hooks.json`; remove the hooks from `.claude/settings.json` (avoid double-fire when
   dev-loading via `--plugin-dir`).
4. Rewrite `gen-index.sh` and `lint.sh` for git-root resolution + guards.
5. Move `CLAUDE.md` → `reference/SCHEMA.md`; inline the needed rules into each `SKILL.md`; add a
   thin dev `CLAUDE.md`.
6. Move `atoms/_template.md` → `templates/atom.md`, `wiki/_template.md` → `templates/wiki-page.md`.
   Remove now-content-only `atoms/`, `wiki/`, `raw/`, `_inbox/` from the machinery repo.
7. Add `skills/init/SKILL.md` (`/wiki-init`) implementing §6.
8. Update `README.md` (install + usage) and keep `METHODOLOGY.md` as the "why".
9. Author/adjust skills using the **`superpowers:writing-skills`** skill.

---

## 12. Testing strategy (scratch git repo)

- `/wiki-init` scaffolds `atoms/ wiki/ raw/`, copies templates, updates `.gitignore`, registers the
  hook (config-based when git ≥ 2.54, else file-based).
- `gen-index.sh` and `lint.sh` resolve the scratch repo's git root and write `index.md` /
  `lint-report.md` there; both **no-op in a non-wiki repo**.
- `PostToolUse` `if`-scoping fires `gen-index` only on `wiki/**` edits, not on other files.
- Version-bump: editing an atom body without a bump → commit rejected; whitespace-only change →
  passes; new atom without `version: 1` → rejected.
- Marketplace install surfaces `/atomic-wiki:ingest|compile|lint|query|init`.
- Scheduled semantic-lint routine dry-runs against a target wiki.

---

## 13. Out of scope

- Compiling the moved content at `D:\code\_atoms` into a wiki (separate, later).
- Versioning `D:\code\_atoms` (offered separately; not part of the plugin).
- The semantic-lint LLM prompt content itself (carried by the `lint` skill; unchanged here).
