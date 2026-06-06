# CLAUDE.md — atomic-wiki plugin source

This repo is the source of the **atomic-wiki** Claude Code plugin (machinery only — no wiki content).

- The operating spec for the pipeline lives in [reference/SCHEMA.md](reference/SCHEMA.md).
- To develop/test the plugin locally: `claude --plugin-dir .`
- Skills are in `skills/`, bundled scripts in `scripts/`, hooks in `hooks/hooks.json`.
- Consumer projects get their own `atoms/`, `wiki/`, `raw/` via the `/atomic-wiki:init` skill.

When editing a `SKILL.md`, use the `superpowers:writing-skills` skill.
