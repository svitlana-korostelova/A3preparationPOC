# Edge Cases

## Special characters in heading names

Illegal filesystem characters (`< > : " / \ | ? *` and ASCII control chars) are **omitted**.
Not replaced with `_` — simply removed.

Real example from sample: `### // TODO: Sveta What's wrong with this code?`
- Filesystem name: `TODO Sveta Whats wrong with this code`
- Displayed `<h1>` inside HTML: `// TODO: Sveta What's wrong with this code?` (verbatim)

## Duplicate sibling names

Append ` (2)`, ` (3)`, … to second and subsequent occurrences within the same parent folder.
Append before `.html` extension on leaf files.

Counters are scoped per-parent: collisions across different parents do not conflict.

## Empty / TODO sections

Sections containing only `TODO`, whitespace, or no body are still rendered as valid HTML files.
The page contains the `<h1>` heading and an empty `<main>`. Do not skip them.

Real examples from sample:
- `### 1.4. How do you implement custom transitions between view controllers?\nTODO: Ira - move to Animations`
- `### 2.1. UIView lifecycle\n// TODO: Sveta`
- Multiple `notes:` only sections

All produce valid (mostly-empty) HTML pages.

## Non-numbered headings

Headings not starting with a dotted number sequence are treated as **children of the previous
numbered sibling** at the same Markdown level, auto-assigned the next free child index.

Real examples from the UIKit file:
```
## 2. Views
### 2.1. UIView lifecycle
### 2.2. CA Layer vs UIView TODO: Ira
…
### 2.8. How will you implement collection view…
### How do you choose between UITableView and UICollectionView…   ← non-numbered
### What are the advantages of using Auto Layout…                 ← non-numbered
```

These become:
- `2.8 How will you implement collection view…` (leaf or folder)
- `2.8.1 How do you choose between UITableView and UICollectionView…` (auto-numbered child of 2.8)
- `2.8.2 What are the advantages of using Auto Layout…`

The displayed heading text inside each HTML remains the **original verbatim text** (no synthetic
prefix). Only the **filesystem name** gets the auto-generated number prefix.

## Headings that skip a level

The Concurrency file has `## 4.5` (H2) followed by `#### 4.5.1` (H4, skipping H3).
Also: the entire file starts with `### 4.1` (H3) directly after `# 4.` (H1, skipping H2).

Normalize depth by stack: push each new deeper level regardless of `#` count. This produces
contiguous parent-child relationships.

Algorithm: maintain a stack of open raw-hash levels.
- If incoming `#` count > top of stack → push (new child level).
- If incoming `#` count == top of stack → same level (sibling).
- If incoming `#` count < top of stack → pop back to matching level.

This means `### 4.1` directly under `# 4.` is treated as level-2 (the first child), not level-3.

## Multiple H1 headings in a single file

The Concurrency file contains `# 4. Concurrency & Multithreading` at the top and
`# Sendable & swift6` mid-document.

Rule:
- First H1 → topic root title (the topic folder name).
- Subsequent H1s → demoted to H2 for structural purposes.

So `# Sendable & swift6` becomes a top-level section of the `4 Concurrency & Multithreading`
topic, alongside `## 4.4`, `## 4.5`, etc.

## Code fences containing `#` characters

Many Swift examples contain `// MARK: -` or shell-like `#` comments. When parsing headings,
**ignore all lines inside fenced code blocks** (between matching ` ``` ` or ` ~~~ ` markers).

Track fence state with a toggle: encountering ` ``` ` at line start flips the flag.
Heading detection only fires when the flag is False.

## Notion hash stripping

Every filename ends with a 32-char hex hash, e.g.:
`4 Concurrency & Multithreading c85870ac06b04be6a1b97fa2a9c95401.md`

When deriving a fallback topic name from the file stem (only used if no H1 exists):
- Strip trailing ` <32 hex chars>`: `re.sub(r'\s+[0-9a-f]{32}$', '', stem)`

This rule applies only to the file-stem fallback. Image folder resolution works via relative
paths in the Markdown source and doesn't depend on this stripping.

## Existing output directory

If output exists:
- Without `--force`: print error, exit code 1, never delete or merge.
- With `--force`: safety-check depth (≥4 path components, not home dir), then `shutil.rmtree`.

## Standalone `-` lines (Notion toggle markers)

The sample files use isolated `-` lines for Notion toggle blocks:
```
### 1.1 View controller lifecycle

-

    The **sequence of methods**...
```

Pass through to the Markdown renderer literally. The `sane_lists` extension handles them
as list items with indented content — readable enough. Do not strip or preprocess.

## Inconsistent indentation

Notion exports mix 4-space and 2-space indentation. The `markdown` library is generally
tolerant. Accept as-is in v1.

## Headings with trailing periods after the number

Example: `### 4.5.1.` — the regex `r'^(\d+(?:\.\d+)*)\.?\s+(.+)$'` handles the optional
trailing period. Filesystem uses `4.5.1` (no trailing period).

## Numbered headings at unexpected depth relative to their number

The Concurrency file has H2 sections numbered `## 4.4`, `## 4.5` but also sub-headings like
`#### 4.3.2`, `#### 4.3.3` (which are H4 but numbered as children of 4.3).

The script uses **structural depth from Markdown heading levels** (normalized via stack) to
determine parent-child relationships, NOT the numbers themselves. The number is used only as a
filesystem prefix. So `#### 4.3.2` under `## 4.5` becomes a child of `4.5` in the output tree,
with filesystem name `4.3.2 BlockOperation` — the number may look odd relative to the parent
folder, but it preserves the author's original numbering for reference.

## Single-folder and single-file invocation

To eliminate manual file copying for testing:

| Input shape                                           | Behavior                           |
|-------------------------------------------------------|------------------------------------|
| Directory with `Private & Shared-N` subfolders        | Full archive (multi-topic)         |
| Directory with one `.md` (+ optional image folder)    | Single-topic mini-archive          |
| A `.md` file path directly                            | Single-topic (parent = its folder) |

Detection is automatic. No user intervention needed.

## --force overwrite mode

Safety guards before deletion:
- Path must have ≥ 4 components (not `/`, `/tmp`, `/Users/foo`).
- Path must not equal `Path.home()`.
- Then `shutil.rmtree` followed by normal generation.

## --open browser launch

Calls `webbrowser.open()` with the `file://` URL of the top-level `index.html`.
If in a non-graphical environment, logs a message and exits cleanly.