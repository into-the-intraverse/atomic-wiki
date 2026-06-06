---
name: lint
description: Run the two-layer wiki health check (programmatic + LLM semantic). Use when the user runs /lint, periodically (quarterly), or after a large compile pass.
---

# Lint

Two layers, run in order:

1. **Programmatic Lint** (`scripts/lint.sh`) — fast deterministic checks.
2. **LLM Lint** — semantic checks that need reading and reasoning.

## When to use

- User runs `/lint`.
- After a large compile pass (many new wiki pages).
- Periodic audit — quarterly is a reasonable cadence for stable knowledge.
- Whenever the user wants confidence that the wiki is internally consistent.

## Procedure

### 1. Programmatic Lint

Run the script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh"
```

It writes findings to `lint-report.md` at the repo root. Checks:

- **Ghost links** — `[[branch/slug]]` pointing to non-existent wiki pages (error).
- **Orphan pages** — wiki pages with zero incoming `[[ ]]` links (warning).
- **Format violations** — first line not `# title`, path with uppercase or underscore, page not under a branch subfolder (error).
- **Outdated markers** — temporal patterns that need verification (warning).

If `lint.sh` reports errors (not just warnings), surface them and fix before moving to the LLM layer. If only warnings, continue.

### 2. LLM Lint

Read `index.md` + all wiki pages (NOT atoms — Lint is wiki-layer quality). Check:

- **Contradictions** — page A says "X is best practice", page B says "X is deprecated". Flag both with paths and quoted segments.
- **Concept gaps** — multiple pages reference a concept that has no dedicated page. Propose as a candidate new page.
- **Expired claims** — version numbers, dates, temporal markers in time-sensitive contexts. Verify (WebSearch if needed) or flag.
- **Weak orphans** — pages with weak conceptual link to the rest, even if technically linked.

Append findings to `lint-report.md` under an `## LLM Lint` section, sorted by severity:
1. Contradictions
2. Concept gaps
3. Expired claims
4. Weak orphans

For each finding, include: page path(s), quoted segment(s), proposed action.

### 3. In-session version-bump check

Before surfacing findings, scan every atom file that was written or edited during this session. For each, compare the current body to `HEAD` (ignoring pure whitespace and blank lines). If the body changed substantively and `version:` is not strictly greater than the committed value, flag it:

> Atom `atoms/<branch>/<slug>.md`: body changed since HEAD but `version:` was not bumped. Bump `version:` before committing.

This mirrors what `${CLAUDE_PLUGIN_ROOT}/scripts/check-version-bump.sh` enforces at commit time, but catches the problem earlier. Report only — do not auto-bump.

### 4. Surface to the user

Summarize: counts per category, top 3 most-important findings, suggested fixes. The user decides which to act on.

### 5. Acting on findings

If the user asks you to fix issues:
- Page contradictions → trace back to the atoms, fix the atom (bump `version:`), recompile the affected wiki pages.
- Concept gaps → propose a new wiki page; if approved, run `/compile`.
- Expired claims → update the atom, bump `version:`, recompile.
- Weak orphans → either add links from related pages, merge into a parent page, or accept and move on.

Never patch a wiki page to hide an atom-layer problem. The atom is truth.

## Constraints

- Programmatic before LLM. Format errors flood the LLM's attention.
- Lint reads wiki, not atoms. Atom-layer audit is a separate, less-frequent operation.
- `lint-report.md` is auto-generated and gitignored — don't commit it.

See `${CLAUDE_PLUGIN_ROOT}/reference/SCHEMA.md` and `${CLAUDE_PLUGIN_ROOT}/METHODOLOGY.md` for the full reasoning.
