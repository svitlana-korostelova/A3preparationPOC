# Cross-Document Links

## Scope

Notion exports may contain Markdown links between sibling files, e.g.:

```markdown
[See Memory Management](../Private%20%26%20Shared-4/3%20Memory%20Management%20%26%20Runtime%20a70ddc86024e4385b06138b537618792.md)
```

Inspection of the provided sample files shows **no cross-document links present**, so this rule
is preventive — ensuring that if any are encountered, they resolve correctly rather than 404.

## Detection

In each Markdown link `[text](href)`, classify `href` as an internal reference if:

1. Not an absolute URL (does not start with `http://`, `https://`, `mailto:`, `data:`, `#`).
2. After URL-decoding, the path ends in `.md` (case-insensitive).
3. After resolving relative to the source `.md` file's directory, it lies within the archive root
   and points to a `.md` file the skill is processing.

## Rewriting

For each detected internal reference:

1. Identify the target topic folder (the output folder for the referenced `.md` file).
2. If the link has no `#fragment` → target is `<topic>/index.html`.
3. If the link has a `#fragment` → attempt slug-matching against headings in that file.
   If matched, target the specific `.html` file. Otherwise fall back to `<topic>/index.html`
   and log a warning.
4. Compute a relative path from the source HTML file to the target.
5. Rewrite the link's href.

Rewriting happens during a second pass after the full tree structure is known.

## Anchor links within the same document

Notion sometimes emits `[Section 4.5](#4-5-actor-isolation)`. Because each heading is split into
its own file, same-document anchors must also be resolved to inter-file links.

Algorithm:
1. Slugify all heading texts (lowercase, whitespace → `-`, strip illegal chars).
2. Find the heading whose slug matches the fragment.
3. Compute relative href from source page to that heading's generated file.
4. If no match, leave unchanged and log: `[warn] unresolved anchor: #<fragment>`.

## External links

Links to `http://`, `https://`, `mailto:` etc. pass through unchanged.

## Implementation note

Because the sample files contain no such links, the v1 implementation keeps this logic simple
but must not crash. Unresolvable links are left as-is with a stderr warning.