# Knowledge Base HTML ↔ Markdown Sync

**Purpose**: Rule for editing Knowledge Base content. The KB stores the *same*
content in two parallel, **non-linked** trees. Any content change to one MUST be
mirrored into the other in the **same task**, or the two trees drift apart.

> **ALWAYS read this guide before editing ANY file under `Knowledge Base/`.**

---

## 🚨 The Core Rule (Acceptance Criteria)

> The user points to a **`.html`** file (one Q&A point).
> You change **both** the `.html` file **and** its matching section in the `.md`
> file — as one seamless edit. Never touch only one side.

The reverse also holds: if the user points to a `.md` section, mirror the change
into the matching `.html` point.

---

## The Two Trees

| Tree | Location | Granularity | Role |
|------|----------|-------------|------|
| **HTML** | `Knowledge Base/knowledge-base/<Section>/<Subsection>/<N.M Title>.html` | **One file per Q&A point** | Rendered site |
| **Markdown** | `Knowledge Base/Private & Shared-<k>/<Topic> <hash>.md` | **One file per top-level topic** (all its points concatenated) | Notion export / source-like |

They are **not** symlinked, `#include`d, or generated from each other at edit
time. They are two independent copies. Keeping them in sync is a **manual** step
that this rule enforces.

### How a point maps between trees
- Each HTML point file has a single `<h1>` inside `<main>`, e.g.
  `1.2. Why do we need viewDidLoad if initial setup methods can be done in init() ?`
- In the Markdown file, the same point is a heading:
  `### 1.2. Why do we need viewDidLoad if initial setup methods can be done in init() ?`
- The `<h1>` text and the `### ` heading text are **identical** — this is the
  join key. Section/topic folder names differ between trees (e.g. HTML
  `2.2 UIKit` ↔ MD `Private & Shared-3/2 2 UIKit …`), so **do not** map by folder
  name. Map by heading text.

---

## Procedure (HTML path → sync both)

1. **Read the HTML point file.** Extract the exact text of the `<h1>` inside
   `<main>`. Call it `HEADING`.

2. **Locate the Markdown owner.** Search the whole KB for the heading:
   ```bash
   grep -rln "### ${HEADING}" --include=*.md "Knowledge Base"
   ```
   This returns exactly one `.md` file (the heading text is unique). If it
   returns **zero** or **more than one**, STOP and ask the user — do not guess.

3. **Find the Markdown section bounds.** The point's content starts at the
   `### ${HEADING}` line and ends **just before the next `### ` heading** (or EOF).
   Everything between is the mirror of the HTML `<main>` body.

4. **Apply the equivalent edit to BOTH sides:**
   - **HTML**: edit only the content inside `<main>` (below the `<h1>`). Leave the
     `<head>`, `<style>`, `<nav class="breadcrumbs">`, and closing tags untouched.
   - **Markdown**: edit the matching lines inside the `### ` section only. Leave
     other sections of the topic file untouched.
   - Keep the two sides **semantically identical**. Remember the format
     difference: MD uses fenced ``` code blocks and `-`/indented bullets; HTML
     uses `<div class="codehilite"><pre><code>…</code></pre></div>`, `<ul><li>`,
     `<p>`, and HTML-escaped entities (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`).
     Translate content between these representations; do not copy raw MD into HTML
     or vice versa.

5. **Verify** both files were changed and still parse (valid HTML tags balanced;
   MD heading structure intact). Report both changed paths to the user.

---

## Title / rename changes (extra references)

If the edit **changes a point's title** (not just its body), the title also
appears as a *reference* in other files. Update all of them:

- **HTML point file**: `<title>` (in `<head>`), the `<h1>`, and — if the title is
  part of the requirement — the **file name** itself.
- **Parent `index.html`** (same folder): the `<li><a href="…">Title</a></li>` TOC
  entry, including the URL-encoded `href` if the file was renamed.
- **Markdown**: the `### ` heading text.

When renaming the HTML file, keep the `href` in the parent `index.html` correct
(URL-encode spaces as `%20`, `(`→`%28`, `)`→`%29`, `+`→`%2B`, `,`→`%2C`).

---

## Do / Don't

- ✅ Map points by **heading text**, never by folder name.
- ✅ Edit `<main>`/`### ` **content only**; preserve surrounding scaffolding.
- ✅ Change **both** trees in the same task; report both paths.
- ❌ Don't edit only the `.html` (or only the `.md`) — that is the exact drift
  this rule prevents.
- ❌ Don't paste Markdown syntax into HTML (or HTML tags into Markdown).
- ❌ Don't guess the `.md` owner if the heading grep is not a unique single hit —
  ask the user.
