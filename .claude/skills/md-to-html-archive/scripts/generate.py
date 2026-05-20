#!/usr/bin/env python3
"""
md-to-html-archive: convert a directory of Notion-style Markdown notes
into a fully-linked, self-contained static HTML knowledge base.

Usage:
    python generate.py <input-path> [--output <dir>] [--force] [--open]

<input-path> can be:
  - An archive root folder (containing Private & Shared-N subfolders)
  - A single topic folder (containing one .md + optional image folder)
  - A single .md file

See SKILL.md and references/ for behavior details.
"""

from __future__ import annotations

import argparse
import base64
import os
import re
import shutil
import sys
import urllib.parse
import webbrowser
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

try:
    import markdown
except ImportError:
    sys.stderr.write(
        "[error] missing dependency 'markdown'. "
        "Run: pip install markdown pygments\n"
    )
    sys.exit(2)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

ILLEGAL_CHARS_RE = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
WHITESPACE_RUN_RE = re.compile(r"\s+")
NUMBERED_HEADING_RE = re.compile(r"^(\d+(?:\.\d+)*)\.?\s+(.+)$")
HEADING_LINE_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
FENCE_LINE_RE = re.compile(r"^\s*(```|~~~)")
NOTION_HASH_SUFFIX_RE = re.compile(r"\s+[0-9a-f]{32}$", re.IGNORECASE)
MD_IMAGE_RE = re.compile(r"!\[([^\]]*)\]\(([^)]+)\)")
HTML_IMAGE_RE = re.compile(
    r'<img\s+[^>]*src=["\']([^"\']+)["\'][^>]*>', re.IGNORECASE
)

MAX_BASENAME_LEN = 200
LARGE_IMAGE_BYTES = 5 * 1024 * 1024  # 5 MB

SUPPORTED_IMG_MIME: Dict[str, str] = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".svg": "image/svg+xml",
}

GITHUB_MD_CSS = r"""
body.markdown-body{box-sizing:border-box;min-width:200px;max-width:980px;margin:0 auto;padding:32px 45px;
  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;
  font-size:16px;line-height:1.5;color:#1f2328;background:#fff;word-wrap:break-word}
.markdown-body h1,.markdown-body h2,.markdown-body h3,.markdown-body h4,.markdown-body h5,.markdown-body h6{
  margin-top:24px;margin-bottom:16px;font-weight:600;line-height:1.25}
.markdown-body h1{font-size:2em;border-bottom:1px solid #d0d7de;padding-bottom:.3em}
.markdown-body h2{font-size:1.5em;border-bottom:1px solid #d0d7de;padding-bottom:.3em}
.markdown-body h3{font-size:1.25em}.markdown-body h4{font-size:1em}
.markdown-body p,.markdown-body ul,.markdown-body ol,.markdown-body table,.markdown-body pre{margin-top:0;margin-bottom:16px}
.markdown-body a{color:#0969da;text-decoration:none}.markdown-body a:hover{text-decoration:underline}
.markdown-body code,.markdown-body kbd{padding:.2em .4em;margin:0;font-size:85%;
  background-color:rgba(175,184,193,.2);border-radius:6px;
  font-family:ui-monospace,SFMono-Regular,"SF Mono",Menlo,Consolas,monospace}
.markdown-body pre{padding:16px;overflow:auto;font-size:85%;line-height:1.45;
  background-color:#f6f8fa;border-radius:6px}
.markdown-body pre code{padding:0;margin:0;font-size:100%;background:transparent;border:0}
.markdown-body blockquote{padding:0 1em;color:#656d76;border-left:.25em solid #d0d7de;margin:0 0 16px 0}
.markdown-body table{border-collapse:collapse;display:block;overflow:auto;max-width:100%}
.markdown-body table th,.markdown-body table td{padding:6px 13px;border:1px solid #d0d7de}
.markdown-body table tr{background-color:#fff;border-top:1px solid #d0d7de}
.markdown-body table tr:nth-child(2n){background-color:#f6f8fa}
.markdown-body img{max-width:100%;box-sizing:content-box;background-color:#fff}
.markdown-body hr{height:.25em;padding:0;margin:24px 0;background-color:#d0d7de;border:0}
.markdown-body ul,.markdown-body ol{padding-left:2em}
nav.breadcrumbs{font-size:14px;color:#656d76;padding:8px 0 16px 0;
  border-bottom:1px solid #eaeef2;margin-bottom:24px}
nav.breadcrumbs a{color:#0969da;text-decoration:none}
nav.breadcrumbs a:hover{text-decoration:underline}
ul.toc{list-style:none;padding:0}
ul.toc li{padding:8px 0;border-bottom:1px solid #eaeef2}
ul.toc li a{font-size:1.05em}
.badge{font-size:11px;color:#656d76;background:#eaeef2;padding:2px 6px;border-radius:10px;
  margin-left:8px;vertical-align:middle}
.missing-image{display:inline-block;padding:4px 8px;background:#fff8c5;border:1px dashed #d4a72c;
  border-radius:4px;color:#7d4e00;font-size:90%}
"""

PYGMENTS_CSS = r"""
.codehilite{background:#f6f8fa;border-radius:6px;padding:16px;overflow:auto;margin-bottom:16px}
.codehilite .hll{background-color:#ffffcc}
.codehilite .c,.codehilite .ch,.codehilite .cm,.codehilite .cp,.codehilite .c1,.codehilite .cs{color:#6a737d;font-style:italic}
.codehilite .err{color:#a61717;background-color:#e3d2d2}
.codehilite .k,.codehilite .kc,.codehilite .kd,.codehilite .kn,.codehilite .kr,.codehilite .kt{color:#d73a49;font-weight:bold}
.codehilite .kp{color:#d73a49}
.codehilite .o,.codehilite .ow{color:#005cc5}
.codehilite .nb{color:#005cc5}
.codehilite .nc,.codehilite .nn{color:#6f42c1;font-weight:bold}
.codehilite .nf{color:#6f42c1}
.codehilite .s,.codehilite .s1,.codehilite .s2,.codehilite .sb,.codehilite .sc,.codehilite .sd,.codehilite .se,.codehilite .sh,.codehilite .si,.codehilite .sx,.codehilite .sr,.codehilite .ss{color:#032f62}
.codehilite .m,.codehilite .mb,.codehilite .mf,.codehilite .mh,.codehilite .mi,.codehilite .mo,.codehilite .il{color:#005cc5}
.codehilite .na{color:#22863a}
.codehilite .nt{color:#22863a}
.codehilite .nv{color:#e36209}
"""

INLINE_CSS = GITHUB_MD_CSS + PYGMENTS_CSS


# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

def info(msg: str) -> None:
    sys.stdout.write(f"[info] {msg}\n")
    sys.stdout.flush()


def ok(msg: str) -> None:
    sys.stdout.write(f"[ok]   {msg}\n")
    sys.stdout.flush()


def warn(msg: str) -> None:
    sys.stderr.write(f"[warn] {msg}\n")
    sys.stderr.flush()


def err(msg: str) -> None:
    sys.stderr.write(f"[error] {msg}\n")
    sys.stderr.flush()


# ---------------------------------------------------------------------------
# HTML escaping
# ---------------------------------------------------------------------------

def html_escape_text(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def html_escape_attr(s: str) -> str:
    return html_escape_text(s).replace('"', "&quot;").replace("'", "&#39;")


# ---------------------------------------------------------------------------
# Sanitization
# ---------------------------------------------------------------------------

def sanitize_basename(name: str) -> str:
    """Apply name sanitization per folder-structure-rules.md."""
    s = name.strip()
    s = ILLEGAL_CHARS_RE.sub("", s)
    s = WHITESPACE_RUN_RE.sub(" ", s).strip()
    if len(s) > MAX_BASENAME_LEN:
        s = s[:MAX_BASENAME_LEN].rstrip()
    if not s:
        s = "untitled"
    return s


def dedupe(name: str, taken: Set[str]) -> str:
    """Append ' (2)', ' (3)', ... if name already taken in this scope."""
    lower = name.lower()
    if lower not in taken:
        taken.add(lower)
        return name
    i = 2
    while True:
        candidate = f"{name} ({i})"
        if candidate.lower() not in taken:
            taken.add(candidate.lower())
            return candidate
        i += 1


def strip_notion_hash(stem: str) -> str:
    """Remove trailing 32-char hex Notion ID from a file stem."""
    return NOTION_HASH_SUFFIX_RE.sub("", stem).strip()


# ---------------------------------------------------------------------------
# Image embedding (pre-pass before splitting)
# ---------------------------------------------------------------------------

def embed_images(md_text: str, md_file: Path, archive_root: Path) -> Tuple[str, int]:
    """Replace ![alt](src) and <img src=...> with base64 data URIs in-place."""
    count = [0]

    def replace_md_img(m: re.Match) -> str:
        alt = m.group(1)
        src = m.group(2).strip()
        replaced = _embed_one(src, alt, md_file, archive_root)
        if replaced is not None:
            count[0] += 1
            return replaced
        return m.group(0)

    def replace_html_img(m: re.Match) -> str:
        src = m.group(1).strip()
        replaced = _embed_one(src, "", md_file, archive_root)
        if replaced is not None:
            count[0] += 1
            return replaced
        return m.group(0)

    md_text = MD_IMAGE_RE.sub(replace_md_img, md_text)
    md_text = HTML_IMAGE_RE.sub(replace_html_img, md_text)
    return md_text, count[0]


def _embed_one(
    src: str, alt: str, md_file: Path, archive_root: Path
) -> Optional[str]:
    """Embed one image as base64. Return HTML string or None to keep original."""
    if src.startswith(("http://", "https://", "data:", "mailto:")):
        return None

    decoded = urllib.parse.unquote(src)
    decoded = decoded.split("#", 1)[0].split("?", 1)[0]

    target = (md_file.parent / decoded).resolve()

    # Security: must stay within archive root
    try:
        target.relative_to(archive_root.resolve())
    except ValueError:
        warn(f"image path escapes archive root, skipping: {src} (in {md_file.name})")
        return _missing_image_html(src, alt)

    if not target.is_file():
        warn(f"image not found: {target} (referenced from {md_file.name})")
        return _missing_image_html(src, alt)

    ext = target.suffix.lower()
    mime = SUPPORTED_IMG_MIME.get(ext)
    if mime is None:
        warn(f"unsupported image format, skipping: {target}")
        return None

    size = target.stat().st_size
    if size > LARGE_IMAGE_BYTES:
        warn(
            f"embedding large image ({size / 1024 / 1024:.1f} MB): {target} "
            f"— output HTML may load slowly"
        )

    data = target.read_bytes()
    b64 = base64.b64encode(data).decode("ascii")
    alt_attr = html_escape_attr(alt)
    return f'<img src="data:{mime};base64,{b64}" alt="{alt_attr}">'


def _missing_image_html(src: str, alt: str) -> str:
    safe_src = html_escape_attr(src)
    safe_alt = html_escape_text(alt) or "image"
    return (
        f"<!-- missing image: {safe_src} -->"
        f'<span class="missing-image">[missing image: {safe_alt}]</span>'
    )


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class HeadingNode:
    """One heading and its body in the Markdown document tree."""

    level: int  # normalized depth (1-based, contiguous)
    raw_hashes: int  # original `#` count from source
    number: Optional[str]  # e.g., "1.2.1" or None for non-numbered
    auto_number: Optional[str]  # assigned for non-numbered headings
    display_text: str  # original heading text, verbatim
    body_md: str  # body content (markdown) under this heading
    children: List["HeadingNode"] = field(default_factory=list)
    parent: Optional["HeadingNode"] = field(default=None, repr=False)

    @property
    def effective_number(self) -> str:
        return self.number or self.auto_number or ""

    def basename(self) -> str:
        """Sanitized filesystem basename (no extension, no dedup counter)."""
        prefix = self.effective_number
        name = self.display_text
        # Strip number prefix from display_text if it's redundant
        m = NUMBERED_HEADING_RE.match(name)
        if m and m.group(1) == prefix:
            name = m.group(2)
        full = f"{prefix} {name}".strip() if prefix else name
        return sanitize_basename(full)


@dataclass
class TopicTree:
    """One generated topic — corresponds to one input .md file."""

    md_path: Path
    topic_basename: str  # sanitized topic folder name
    topic_display: str  # human-readable name (for top index)
    root_h1_text: str  # first H1 text or fallback
    children: List[HeadingNode]  # top-level headings after H1
    image_count: int = 0


# ---------------------------------------------------------------------------
# Markdown parsing → heading tree
# ---------------------------------------------------------------------------

def parse_headings(md_text: str) -> Tuple[str, List[HeadingNode]]:
    """
    Walk markdown line by line, ignoring fenced code blocks.
    Returns (h1_text_or_empty, list_of_top_level_heading_nodes).

    Multiple H1s: first is topic root; subsequent demoted to H2.
    Skipped levels: depth normalized via stack.
    """
    lines = md_text.splitlines()
    in_fence = False
    fence_marker: Optional[str] = None

    # Collect raw heading info: (raw_hashes, text, line_index)
    raw_headings: List[Tuple[int, str, int]] = []

    for i, line in enumerate(lines):
        fm = FENCE_LINE_RE.match(line)
        if fm:
            marker = fm.group(1)
            if not in_fence:
                in_fence = True
                fence_marker = marker
            elif marker == fence_marker:
                in_fence = False
                fence_marker = None
            continue
        if in_fence:
            continue
        hm = HEADING_LINE_RE.match(line)
        if hm:
            raw_headings.append((len(hm.group(1)), hm.group(2).strip(), i))

    # Compute body for each heading
    bodies: List[str] = []
    for idx, (_, _, line_idx) in enumerate(raw_headings):
        end = (
            raw_headings[idx + 1][2]
            if idx + 1 < len(raw_headings)
            else len(lines)
        )
        body = "\n".join(lines[line_idx + 1 : end]).strip("\n")
        bodies.append(body)

    # Identify the topic H1 (first heading with raw_hashes == 1)
    h1_text = ""
    h1_idx = -1
    for idx, (h, t, _) in enumerate(raw_headings):
        if h == 1:
            h1_text = t
            h1_idx = idx
            break

    # Build processed list: demote subsequent H1s, exclude the root H1
    processed: List[Tuple[int, str, str]] = []  # (raw_hashes, text, body)
    for idx, (h, t, _) in enumerate(raw_headings):
        if idx == h1_idx:
            continue  # root H1 is the topic itself, not a child
        if h == 1 and h1_idx >= 0:
            h = 2  # demote subsequent H1s to H2
        processed.append((h, t, bodies[idx]))

    # Normalize depth using a stack (handles skipped levels)
    nodes: List[HeadingNode] = []
    parent_stack: List[HeadingNode] = []
    raw_stack: List[int] = []  # parallel stack of raw_hashes

    for raw_h, text, body in processed:
        # Pop deeper or same-level entries from the stack
        while raw_stack and raw_stack[-1] >= raw_h:
            raw_stack.pop()
            parent_stack.pop()

        norm_level = len(parent_stack) + 1
        m = NUMBERED_HEADING_RE.match(text)
        number = m.group(1) if m else None

        node = HeadingNode(
            level=norm_level,
            raw_hashes=raw_h,
            number=number,
            auto_number=None,
            display_text=text,
            body_md=body,
            parent=parent_stack[-1] if parent_stack else None,
        )

        if parent_stack:
            parent_stack[-1].children.append(node)
        else:
            nodes.append(node)

        parent_stack.append(node)
        raw_stack.append(raw_h)

    # Auto-number non-numbered headings
    _autonumber_siblings(nodes)
    return h1_text, nodes


def _autonumber_siblings(nodes: List[HeadingNode]) -> None:
    """
    Recursively auto-number non-numbered headings.
    Non-numbered headings become children of the preceding numbered sibling.
    """
    # First pass: reparent non-numbered headings
    reparented_indices: Set[int] = set()
    for i, node in enumerate(nodes):
        if node.number is not None:
            continue
        # Find preceding ORIGINALLY-numbered sibling (auto_number does not qualify).
        # This prevents non-numbered headings from chaining into each other and
        # creating arbitrarily deep nesting from a flat list of un-numbered entries.
        prev_numbered: Optional[HeadingNode] = None
        for j in range(i - 1, -1, -1):
            if nodes[j].number is not None:
                prev_numbered = nodes[j]
                break
        if prev_numbered is not None:
            # Auto-number as child of prev_numbered
            base = prev_numbered.effective_number
            used = {
                c.effective_number
                for c in prev_numbered.children
                if c.effective_number
            }
            k = 1
            while f"{base}.{k}" in used:
                k += 1
            node.auto_number = f"{base}.{k}"
            node.parent = prev_numbered
            prev_numbered.children.append(node)
            reparented_indices.add(i)
        else:
            # No preceding numbered sibling — assign top-level auto number
            used_top = {
                n.effective_number for n in nodes if n.effective_number
            }
            k = 1
            while str(k) in used_top:
                k += 1
            node.auto_number = str(k)

    # Remove reparented nodes from top-level list
    if reparented_indices:
        nodes[:] = [n for i, n in enumerate(nodes) if i not in reparented_indices]

    # Recurse into children of all nodes
    for node in nodes:
        if node.children:
            _autonumber_siblings(node.children)


# ---------------------------------------------------------------------------
# Topic discovery & tree building
# ---------------------------------------------------------------------------

def discover_md_files_for_mode(
    root: Path, mode: str, single_file: Optional[Path] = None
) -> List[Path]:
    """Find .md files based on detected input mode."""
    if mode == "file" and single_file is not None:
        return [single_file]
    if mode == "single":
        return sorted(
            p for p in root.iterdir() if p.is_file() and p.suffix.lower() == ".md"
        )
    # full mode: scan immediate subdirs
    md_files: List[Path] = []
    for sub in sorted(root.iterdir()):
        if sub.is_dir():
            for q in sorted(sub.iterdir()):
                if q.is_file() and q.suffix.lower() == ".md":
                    md_files.append(q)
        elif sub.is_file() and sub.suffix.lower() == ".md":
            md_files.append(sub)
    return md_files


def build_topic(md_file: Path, archive_root: Path) -> TopicTree:
    """Parse one .md file into a TopicTree."""
    info(f"processing: {md_file.name}")
    md_text = md_file.read_text(encoding="utf-8")

    # Pre-pass: embed images as base64
    md_text, img_count = embed_images(md_text, md_file, archive_root)
    if img_count:
        info(f"  embedded {img_count} image(s)")

    # Parse heading hierarchy
    h1_text, nodes = parse_headings(md_text)

    # Determine topic display name
    if h1_text:
        topic_display = h1_text
    else:
        topic_display = strip_notion_hash(md_file.stem)

    topic_basename = sanitize_basename(topic_display)

    leaves, folders = _count_tree(nodes)
    info(f"  built tree: {len(nodes)} sections, {leaves} leaves, {folders} nested folders")

    return TopicTree(
        md_path=md_file,
        topic_basename=topic_basename,
        topic_display=topic_display,
        root_h1_text=h1_text,
        children=nodes,
        image_count=img_count,
    )


def _count_tree(nodes: List[HeadingNode]) -> Tuple[int, int]:
    """Count (leaves, folder-nodes) recursively."""
    leaves = 0
    folders = 0
    for n in nodes:
        if n.children:
            folders += 1
            sub_l, sub_f = _count_tree(n.children)
            leaves += sub_l
            folders += sub_f
        else:
            leaves += 1
    return leaves, folders


# ---------------------------------------------------------------------------
# Filesystem layout planning
# ---------------------------------------------------------------------------

@dataclass
class PlannedNode:
    """A heading node with its final filesystem path resolved."""

    node: HeadingNode
    is_folder: bool  # True → folder with index.html; False → leaf .html
    fs_name: str  # final deduplicated basename (folder name or file.html)
    children: List["PlannedNode"] = field(default_factory=list)


@dataclass
class PlannedTopic:
    topic: TopicTree
    fs_name: str  # deduplicated topic folder name
    children: List[PlannedNode] = field(default_factory=list)


def plan_topic(topic: TopicTree, taken_topic_names: Set[str]) -> PlannedTopic:
    """Assign deduplicated filesystem names to a topic and all its children."""
    topic_dir = dedupe(topic.topic_basename, taken_topic_names)
    planned = PlannedTopic(topic=topic, fs_name=topic_dir)
    sibling_taken: Set[str] = set()
    for child in topic.children:
        planned.children.append(_plan_node(child, sibling_taken))
    return planned


def _plan_node(node: HeadingNode, sibling_taken: Set[str]) -> PlannedNode:
    """Recursively plan a heading node."""
    base = node.basename()
    is_folder = bool(node.children)

    if is_folder:
        unique = dedupe(base, sibling_taken)
        pn = PlannedNode(node=node, is_folder=True, fs_name=unique)
        child_taken: Set[str] = set()
        for c in node.children:
            pn.children.append(_plan_node(c, child_taken))
        return pn
    else:
        unique = dedupe(base, sibling_taken)
        return PlannedNode(node=node, is_folder=False, fs_name=f"{unique}.html")


# ---------------------------------------------------------------------------
# Markdown rendering
# ---------------------------------------------------------------------------

def make_md_renderer() -> markdown.Markdown:
    return markdown.Markdown(
        extensions=["fenced_code", "codehilite", "tables", "sane_lists"],
        extension_configs={
            "codehilite": {
                "guess_lang": False,
                "css_class": "codehilite",
                "noclasses": False,
            }
        },
    )


# ---------------------------------------------------------------------------
# HTML page rendering
# ---------------------------------------------------------------------------

def url_encode_segment(segment: str) -> str:
    """URL-encode a single path segment."""
    return urllib.parse.quote(segment, safe="")


def relpath_posix(target: Path, current_dir: Path) -> str:
    """Compute a URL-encoded relative posix path from current_dir to target."""
    rel = os.path.relpath(str(target), str(current_dir))
    parts = rel.replace(os.sep, "/").split("/")
    return "/".join(url_encode_segment(p) if p != ".." else p for p in parts)


def build_breadcrumbs_html(
    file_dir: Path,
    output_root: Path,
    ancestors: List[Tuple[str, Path]],
) -> str:
    """Build breadcrumb nav HTML. ancestors: [(display_name, abs_path_to_index_html)]."""
    parts: List[str] = []
    kb_index = output_root / "index.html"
    href = relpath_posix(kb_index, file_dir)
    parts.append(f'<a href="{href}">⌂ Knowledge Base</a>')
    for name, index_path in ancestors:
        href = relpath_posix(index_path, file_dir)
        parts.append(f'<a href="{href}">{html_escape_text(name)}</a>')
    return " › ".join(parts)


def render_leaf_page(
    pn: PlannedNode,
    abs_file: Path,
    output_root: Path,
    ancestors: List[Tuple[str, Path]],
    md_renderer: markdown.Markdown,
) -> str:
    """Render a leaf heading's HTML page."""
    md_renderer.reset()
    body_html = md_renderer.convert(pn.node.body_md)
    title = pn.node.display_text
    breadcrumbs = build_breadcrumbs_html(abs_file.parent, output_root, ancestors)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html_escape_text(title)}</title>
<style>{INLINE_CSS}</style>
</head>
<body class="markdown-body">
<nav class="breadcrumbs">{breadcrumbs}</nav>
<main>
<h1>{html_escape_text(title)}</h1>
{body_html}
</main>
</body>
</html>
"""


def render_index_page(
    folder_title: str,
    abs_index_file: Path,
    output_root: Path,
    ancestors: List[Tuple[str, Path]],
    children: List[PlannedNode],
) -> str:
    """Render an index.html (table of contents) for a folder."""
    breadcrumbs = build_breadcrumbs_html(
        abs_index_file.parent, output_root, ancestors
    )
    items: List[str] = []
    for c in children:
        if c.is_folder:
            href = url_encode_segment(c.fs_name) + "/index.html"
            badge = '<span class="badge">section</span>'
        else:
            href = url_encode_segment(c.fs_name)
            badge = ""
        display = html_escape_text(c.node.display_text)
        items.append(f'<li><a href="{href}">{display}</a>{badge}</li>')

    toc_html = '<ul class="toc">' + "".join(items) + "</ul>"
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html_escape_text(folder_title)}</title>
<style>{INLINE_CSS}</style>
</head>
<body class="markdown-body">
<nav class="breadcrumbs">{breadcrumbs}</nav>
<main>
<h1>{html_escape_text(folder_title)}</h1>
{toc_html}
</main>
</body>
</html>
"""


def render_root_index(output_root: Path, planned_topics: List[PlannedTopic]) -> str:
    """Render the top-level knowledge base index.html."""

    def sort_key(pt: PlannedTopic):
        m = NUMBERED_HEADING_RE.match(pt.topic.topic_display)
        if m:
            nums = tuple(int(x) for x in m.group(1).split("."))
            return (0, nums, pt.topic.topic_display.lower())
        return (1, (), pt.topic.topic_display.lower())

    sorted_topics = sorted(planned_topics, key=sort_key)
    items: List[str] = []
    for pt in sorted_topics:
        href = url_encode_segment(pt.fs_name) + "/index.html"
        display = html_escape_text(pt.topic.topic_display)
        items.append(f'<li><a href="{href}">{display}</a></li>')

    toc_html = '<ul class="toc">' + "".join(items) + "</ul>"
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    count = len(sorted_topics)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Knowledge Base</title>
<style>{INLINE_CSS}</style>
</head>
<body class="markdown-body">
<main>
<h1>Knowledge Base</h1>
<p>{count} topics · generated {timestamp}</p>
{toc_html}
</main>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# Writing the planned tree to disk
# ---------------------------------------------------------------------------

def write_topic(
    pt: PlannedTopic,
    output_root: Path,
    md_renderer: markdown.Markdown,
    counts: Dict[str, int],
) -> None:
    """Write one topic's entire folder tree."""
    topic_abs = output_root / pt.fs_name
    topic_abs.mkdir(parents=True)
    counts["folders"] += 1

    # Topic-level index.html
    topic_index = topic_abs / "index.html"
    ancestors: List[Tuple[str, Path]] = []
    html = render_index_page(
        folder_title=pt.topic.topic_display,
        abs_index_file=topic_index,
        output_root=output_root,
        ancestors=ancestors,
        children=pt.children,
    )
    topic_index.write_text(html, encoding="utf-8")
    counts["files"] += 1

    # Recurse into children
    for child in pt.children:
        _write_node(
            pn=child,
            parent_abs=topic_abs,
            output_root=output_root,
            ancestors=[(pt.topic.topic_display, topic_index)],
            md_renderer=md_renderer,
            counts=counts,
        )


def _write_node(
    pn: PlannedNode,
    parent_abs: Path,
    output_root: Path,
    ancestors: List[Tuple[str, Path]],
    md_renderer: markdown.Markdown,
    counts: Dict[str, int],
) -> None:
    """Recursively write a PlannedNode (folder or leaf)."""
    if pn.is_folder:
        folder_abs = parent_abs / pn.fs_name
        folder_abs.mkdir(parents=True)
        counts["folders"] += 1

        index_abs = folder_abs / "index.html"
        html = render_index_page(
            folder_title=pn.node.display_text,
            abs_index_file=index_abs,
            output_root=output_root,
            ancestors=ancestors,
            children=pn.children,
        )
        index_abs.write_text(html, encoding="utf-8")
        counts["files"] += 1

        new_ancestors = ancestors + [(pn.node.display_text, index_abs)]
        for c in pn.children:
            _write_node(c, folder_abs, output_root, new_ancestors, md_renderer, counts)
    else:
        leaf_abs = parent_abs / pn.fs_name
        html = render_leaf_page(
            pn=pn,
            abs_file=leaf_abs,
            output_root=output_root,
            ancestors=ancestors,
            md_renderer=md_renderer,
        )
        leaf_abs.write_text(html, encoding="utf-8")
        counts["files"] += 1


# ---------------------------------------------------------------------------
# Input shape detection
# ---------------------------------------------------------------------------

def detect_input_shape(input_path: Path) -> Tuple[Path, str]:
    """
    Detect what kind of input was provided.
    Returns (effective_archive_root, mode).

    Modes:
      'full'   — multi-topic archive (contains subdirs with .md files)
      'single' — single topic folder (one .md + optional image folder)
      'file'   — single .md file
    """
    if input_path.is_file():
        if input_path.suffix.lower() != ".md":
            raise ValueError(f"file is not a Markdown file: {input_path}")
        return input_path.parent, "file"

    if not input_path.is_dir():
        raise ValueError(f"path does not exist or is not accessible: {input_path}")

    # Check for direct .md files in this directory
    direct_mds = [
        p for p in input_path.iterdir()
        if p.is_file() and p.suffix.lower() == ".md"
    ]
    # Check for .md files one level deep (inside subdirs)
    nested_mds: List[Path] = []
    for sub in input_path.iterdir():
        if sub.is_dir():
            for q in sub.iterdir():
                if q.is_file() and q.suffix.lower() == ".md":
                    nested_mds.append(q)

    if nested_mds and not direct_mds:
        return input_path, "full"
    if direct_mds and not nested_mds:
        return input_path, "single"
    if direct_mds and nested_mds:
        # Mixed — treat as full archive (include both)
        return input_path, "full"

    raise ValueError(
        f"no .md files found in {input_path} (neither directly nor one level deep)"
    )


# ---------------------------------------------------------------------------
# Safety check for --force
# ---------------------------------------------------------------------------

def is_safe_to_delete(path: Path) -> bool:
    """Refuse to delete paths that are too shallow or the home dir."""
    resolved = path.resolve()
    parts = resolved.parts
    if len(parts) < 4:
        return False
    if resolved == Path.home().resolve():
        return False
    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Convert a Notion-style Markdown archive into a self-contained "
            "HTML knowledge base."
        )
    )
    parser.add_argument(
        "input_path",
        type=str,
        help=(
            "Path to: (a) the archive root containing 'Private & Shared-N' "
            "subfolders, (b) a single topic folder with one .md file, "
            "or (c) a single .md file."
        ),
    )
    parser.add_argument(
        "--output",
        "-o",
        type=str,
        default=None,
        help="Output directory. Defaults to <input>/knowledge-base/.",
    )
    parser.add_argument(
        "--force",
        "-f",
        action="store_true",
        help="Delete existing output directory before generating.",
    )
    parser.add_argument(
        "--open",
        dest="open_browser",
        action="store_true",
        help="Open the generated index.html in the default browser.",
    )
    args = parser.parse_args(argv)

    input_path = Path(args.input_path).expanduser().resolve()

    # Detect input shape
    try:
        archive_root, mode = detect_input_shape(input_path)
    except ValueError as e:
        err(str(e))
        return 1

    info(f"input mode: {mode}")
    info(f"archive root: {archive_root}")

    # Determine output location
    if args.output:
        output_root = Path(args.output).expanduser().resolve()
    elif mode == "file":
        output_root = input_path.parent / "knowledge-base"
    else:
        output_root = archive_root / "knowledge-base"

    # Handle existing output
    if output_root.exists():
        if args.force:
            if not is_safe_to_delete(output_root):
                err(
                    f"refusing to delete shallow/dangerous path with --force: "
                    f"{output_root}. Use --output to specify a safer path."
                )
                return 1
            info(f"--force: removing existing {output_root}")
            shutil.rmtree(output_root)
        else:
            err(
                f"output directory already exists: {output_root}. "
                f"Use --force to overwrite, or --output <path> for a different location."
            )
            return 1

    # Discover .md files
    single_file = input_path if mode == "file" else None
    md_files = discover_md_files_for_mode(archive_root, mode, single_file)
    if not md_files:
        err(f"no .md files found under {archive_root}")
        return 1
    info(f"found {len(md_files)} markdown file(s)")

    # Build topic trees
    topics: List[TopicTree] = []
    for md in md_files:
        try:
            topics.append(build_topic(md, archive_root))
        except Exception as e:
            warn(f"failed to process {md.name}: {e}. Skipping.")
            continue

    if not topics:
        err("no topics produced — aborting.")
        return 1

    # Plan filesystem layout (resolves dedup at every level)
    taken_topic_names: Set[str] = set()
    planned: List[PlannedTopic] = [
        plan_topic(t, taken_topic_names) for t in topics
    ]

    # Write everything to disk
    info(f"writing knowledge base: {output_root}")
    output_root.mkdir(parents=True)
    counts: Dict[str, int] = {"files": 0, "folders": 1}  # root counts as 1

    md_renderer = make_md_renderer()
    for pt in planned:
        write_topic(pt, output_root, md_renderer, counts)

    # Top-level index.html
    root_index = output_root / "index.html"
    root_index.write_text(
        render_root_index(output_root, planned), encoding="utf-8"
    )
    counts["files"] += 1

    ok(
        f"wrote {counts['files']} HTML files in {counts['folders']} folders "
        f"across {len(planned)} topic(s)"
    )
    ok(f"open: {root_index}")

    # Open in browser if requested
    if args.open_browser:
        url = root_index.as_uri()
        info("opening in browser...")
        opened = webbrowser.open(url)
        if not opened:
            info(f"no browser available; open manually: {root_index}")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))