# HTML Template

## Style choice

Use a **GitHub-flavored markdown style**. The CSS is bundled inline in every generated HTML file —
no external stylesheet, no CDN dependency, no JavaScript. Output is fully portable.

## Inline CSS bundle

Two CSS strings concatenated and inlined into every page:

1. **GITHUB_MD_CSS** — body typography, headings, lists, tables, blockquotes, code blocks, links,
   images, breadcrumbs, TOC styling. Light mode only.
2. **PYGMENTS_CSS** — syntax highlighting classes from Pygments (default style, GitHub-tinted).

Both defined as Python constants in `generate.py`. Together ~6 KB per file — acceptable for portability.

## Leaf HTML page template

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ page_title }}</title>
  <style>{{ inline_css }}</style>
</head>
<body class="markdown-body">
  <nav class="breadcrumbs">
    <a href="{{ rel_to_kb_root }}/index.html">⌂ Knowledge Base</a>
    {% for crumb in breadcrumbs %}
      › <a href="{{ crumb.href }}">{{ crumb.name }}</a>
    {% endfor %}
  </nav>
  <main>
    <h1>{{ heading_display_text }}</h1>
    {{ rendered_html_body }}
  </main>
</body>
</html>
```

- `heading_display_text`: original Markdown heading text, preserved verbatim.
- `rendered_html_body`: HTML from rendering the section's body Markdown.
- Breadcrumb `href` values are relative paths from the leaf file to each ancestor `index.html`.

## Index (table of contents) page template

Every parent folder receives an `index.html` listing its direct children only.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ folder_title }}</title>
  <style>{{ inline_css }}</style>
</head>
<body class="markdown-body">
  <nav class="breadcrumbs">...</nav>
  <main>
    <h1>{{ folder_title }}</h1>
    <ul class="toc">
      {% for child in children %}
        <li>
          <a href="{{ child.href }}">{{ child.display_name }}</a>
          {% if child.is_folder %}<span class="badge">section</span>{% endif %}
        </li>
      {% endfor %}
    </ul>
  </main>
</body>
</html>
```

`child.href`:
- For a child folder: `<child-folder>/index.html`
- For a child leaf: `<child-file>.html`

## Top-level knowledge base index

The root `index.html` is a flat list of all topics, sorted by numeric prefix first then alphabetically.
It includes a topic count and generation timestamp.

No breadcrumb on this page — it's the root.

## Breadcrumb construction

For a page at `<output-root>/<topic>/<sec>/<subsec>/file.html`:

- Crumb 0: `⌂ Knowledge Base` → `<output-root>/index.html`
- Crumb 1: topic folder → `<topic>/index.html`
- Crumb 2+: each ancestor folder → its `index.html`
- The page's own heading is NOT in the breadcrumb (it's the `<h1>`).

All href values are relative paths using `os.path.relpath`. Backslashes converted to `/`.
Each path segment URL-encoded with `urllib.parse.quote(segment, safe='')`.

## Code block highlighting

Use the `markdown` library with `fenced_code`, `codehilite`, `tables`, and `sane_lists` extensions.
Pygments produces static HTML classes — no JavaScript needed.

```python
md = markdown.Markdown(
    extensions=['fenced_code', 'codehilite', 'tables', 'sane_lists'],
    extension_configs={
        'codehilite': {'guess_lang': False, 'css_class': 'codehilite', 'noclasses': False}
    },
)
```

Reset with `md.reset()` between sections.

## Self-containment guarantees

- ✅ No `<script>` tags
- ✅ No `<link rel="stylesheet">` — all CSS inline
- ✅ No external `<img>` URLs — only `data:` URIs (base64)
- ✅ No CDN fonts — system font stack only
- ✅ No absolute `file://` paths — all links relative