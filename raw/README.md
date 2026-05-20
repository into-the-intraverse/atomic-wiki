# raw/

Drop your source materials here.

## What goes in

Anything text-based that you want to extract knowledge from:

- PDFs (after text extraction)
- Markdown notes
- Lecture / podcast transcripts
- Social media post dumps
- Articles, papers
- Screenshots (after OCR)
- Audio (after transcription)
- Email exports
- Slack / Discord history

Format-wise: prefer plain text or markdown. Binary files (raw PDFs, audio) should be converted to text before landing here, so the LLM can actually read them.

## Folder layout (suggested)

```
raw/
├── threads/
│   ├── posts.md
│   └── replies.md
├── lectures/
│   └── skill-design.md
├── articles/
│   └── mcp-deep-dive.md
└── notes/
    └── ...
```

Subfolders by source type help during Ingest — the LLM can target one source at a time.

## Rules

- **Read-only from the LLM's perspective.** The LLM extracts atoms from raw but never writes back. If raw needs correction or redaction, do it manually and re-run Ingest.
- **Stable identifiers.** Each file should have a stable name/path. `source_ids` in atoms reference these.
- **Whole-content gitignored.** Only this README and `.gitkeep` are tracked. Your raw materials never go to the public repo — that's the whole point.

## Why this layer exists

The pipeline is `raw → atoms → wiki`. Raw is where everything starts — the layer the human owns; the LLM just reads from it. Atoms are the intermediate source of truth; wiki is the derived cache.
