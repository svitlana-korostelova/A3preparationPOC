# Folder Structure Rules

## Top-level layout

Given an input archive root containing `Private & Shared-N/` subfolders, each holding one `.md` file
(and optionally a sibling image folder), the output is:

```
<output-root>/
├── index.html                              ← flat list of all topics
├── <topic-A>/
│   ├── index.html                          ← TOC of topic A's sections
│   ├── <section>.html                      ← leaf
│   └── <section>/
│       ├── index.html
│       └── <subsection>.html
├── <topic-B>/
│   └── ...
└── ...
```

The `Private & Shared-N` wrappers are dropped. Each `.md` file becomes one top-level topic folder,
named after the file's H1 heading (or the file stem with the Notion hash stripped if no H1 exists).

## Heading levels and their roles

| Markdown level | Role                              | Filesystem result                          |
|----------------|-----------------------------------|--------------------------------------------|
| `#` (H1)       | Topic root title                  | Topic folder name                          |
| `##` (H2)      | Top-level section                 | Folder OR leaf `.html` (decision below)    |
| `###` (H3)     | Subsection                        | Folder OR leaf `.html`                     |
| `####` (H4+)   | Deeper subsection                 | Same rule applied recursively              |

## Leaf-vs-parent decision rule

A heading becomes a **folder** if it has at least one child heading of strictly deeper level appearing
in the Markdown before the next heading of the same-or-shallower level. Otherwise it becomes a
**leaf HTML file**.

This means: folders down to depth N, HTML files only at the deepest level present in each branch.
Branches may have different depths — e.g., `3.1` may be a leaf `.html` while sibling `3.2` is a
folder containing `3.2.1.html` and `3.2.2.html`.

## Numbering extraction

A heading is "numbered" if its text starts with a dotted number sequence. Use this regex:

```python
NUMBERED_HEADING_RE = re.compile(r'^(\d+(?:\.\d+)*)\.?\s+(.+)$')
```

Matches:
- `1. View Controllers` → number `1`, name `View Controllers`
- `1.1 Lifecycle` → number `1.1`, name `Lifecycle`
- `4.5.1. Example:` → number `4.5.1`, name `Example:`
- `2.2 UIKit` → number `2.2`, name `UIKit`

The captured number becomes the **filename/folder prefix**; the remainder is the **display name**.
Full basename format: `<number> <display-name>`.

## Topic folder naming

For each `.md` file:

1. Locate the first H1 heading.
2. Apply numbering extraction. The full heading text (number + name) becomes the topic folder name after sanitization.
   - `# 2.2 UIKit` → folder `2.2 UIKit`
   - `# 4. Concurrency & Multithreading` → folder `4 Concurrency & Multithreading`
3. If no H1, use the file stem with the trailing 32-char hex Notion hash stripped:
   - `Storage & Persistence 435725c254344ab58e27290d8dbc727c.md` → `Storage & Persistence`

## Name sanitization order

Apply in this exact order:

1. **Strip** leading/trailing whitespace.
2. **Omit** illegal filesystem characters: `< > : " / \ | ? *` and ASCII control chars.
3. **Collapse** internal whitespace runs to a single space.
4. **Truncate** to 200 characters.
5. **Deduplicate**: if a sibling with the same basename already exists, append ` (2)`, ` (3)`, etc.

The `.html` extension is appended to leaf files after sanitization. Folder names get no extension.

## Output directory naming

Default: `<archive-root>/knowledge-base/` (or `<md-file-parent>/knowledge-base/` for single-file mode).
Overridable via `--output` CLI flag.