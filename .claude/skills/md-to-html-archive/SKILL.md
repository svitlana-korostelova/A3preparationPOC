---
name: md-to-html-archive
description: |
  Converts a directory of Notion-style Markdown notes (organized as Archive/Private & Shared-N/<file>.md
  plus optional sibling image folders) into a single, fully-linked, self-contained static HTML knowledge base.
  Each Markdown file is split into a hierarchical folder tree based on its numbered headings (1 → 1.1 → 1.1.1),
  with parent folders containing index.html tables of contents and leaf headings rendered as standalone HTML files
  with embedded base64 images and GitHub-markdown styling.
  Use when the user invokes /md-to-html-archive with a path, or asks to "build an HTML knowledge base from
  markdown notes", "convert Notion export to linked HTML", or "split markdown by headings into a browseable archive".
disable-model-invocation: true
---

# Markdown-to-HTML Archive Knowledge Base Generator

Generate a unified, browseable static HTML knowledge base from a directory of Notion-exported Markdown files.

## When to use

The user runs `/md-to-html-archive <path>` or asks to convert Markdown notes into a hierarchical HTML knowledge base.

`<path>` can be:
- The archive root folder (contains `Private & Shared-N` subfolders) — processes all topics
- A single `Private & Shared-N` folder — processes just that topic (useful for testing)
- A single `.md` file — processes just that file

## Workflow

Copy this checklist and check off items as you complete them:

```
Task Progress:
- [ ] Step 1: Determine input scope
- [ ] Step 2: Install Python dependencies
- [ ] Step 3: Run the generator script
- [ ] Step 4: Open the result and report to the user
```

### Step 1: Determine input scope

Confirm the path provided by the user exists. The script auto-detects whether it's:
- A full archive root (multi-topic)
- A single topic folder (one `.md` + optional image folder)
- A single `.md` file

No manual file copying or restructuring is needed. The skill handles everything.

### Step 2: Install dependencies

Do not assume dependencies are pre-installed. Run:

```bash
pip install --quiet markdown pygments
```

If `pip` is unavailable, ask which package manager to use (`pip3`, `uv`, `conda`).

### Step 3: Run the generator

Execute the bundled script:

```bash
python .claude/skills/md-to-html-archive/scripts/generate.py "<user-path>" --open
```

Flags:
- `--open` — automatically opens the result in the default browser
- `--output <path>` — override the default output location
- `--force` — delete existing output directory before generating (with safety guards)

Default output: `<input-parent>/knowledge-base/`

### Step 4: Report results

After the script finishes, report to the user:
- The absolute path of the generated knowledge base root
- The top-level `index.html` location (entry point)
- The number of topics, folders, and HTML files created
- Confirmation that the browser was opened

## Rules and details

Read the relevant reference file when its topic comes up — do not guess or improvise.

- **Heading-to-filesystem mapping**: see [references/folder-structure-rules.md](references/folder-structure-rules.md)
- **HTML output format, CSS, templates**: see [references/html-template.md](references/html-template.md)
- **Image embedding**: see [references/image-handling.md](references/image-handling.md)
- **Cross-document links**: see [references/cross-document-links.md](references/cross-document-links.md)
- **Edge cases**: see [references/edge-cases.md](references/edge-cases.md)
- **Worked example**: see [references/examples.md](references/examples.md)

## Constraints

- This skill is **manual-invocation only**. Do not trigger it implicitly.
- The script must not modify any input file.
- The output must be 100% static — no JavaScript, no external CSS, no external image dependencies.
- All HTML files must open standalone in a browser without a server.