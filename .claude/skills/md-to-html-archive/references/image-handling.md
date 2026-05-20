# Image Handling

## Strategy: inline base64 embedding

Images are embedded directly into HTML as base64 data URIs:

- No image files copied to output.
- Generated HTML files are fully self-contained and portable.
- Splitting by heading is trivial — embedded images travel with their section.

## Sibling image folder convention (Notion export pattern)

Each `.md` file may have a sibling folder containing its images. The folder name is the `.md`
filename with the trailing 32-char hex hash and `.md` extension stripped:

| Markdown file                                    | Image folder                             |
|--------------------------------------------------|------------------------------------------|
| `2 2 UIKit 0eb88896025d4a20a8e503f3aa53b137.md`  | `2 2 UIKit/`                             |
| `4 Concurrency... c85870ac06b04be6a1b97fa2a9c95401.md` | `4 Concurrency & Multithreading/` |

The script resolves images by relative path from the `.md` file's directory — no need to know
this naming convention explicitly.

## Resolution algorithm

For each Markdown image `![alt](src)` or HTML `<img src="...">`:

1. If `src` starts with `http://`, `https://`, or `data:` → leave untouched.
2. Otherwise, **URL-decode** `src` using `urllib.parse.unquote()`.
   - `2%202%20UIKit/image.png` → `2 2 UIKit/image.png`
   - `4%20Concurrency%20&%20Multithreading/image%201.png` → `4 Concurrency & Multithreading/image 1.png`
3. Resolve relative to the input `.md` file's directory.
4. Security check: verify resolved path stays within the archive root.
5. Read bytes, base64-encode, emit:
   ```html
   <img src="data:<mime>;base64,<encoded>" alt="<alt>">
   ```

## Pre-pass timing: embed before splitting

Order of operations:

1. Read `.md` file as a single string.
2. **Pre-pass**: replace all `![alt](src)` and `<img src="...">` with base64 `<img>` tags.
3. **Then** split into per-heading fragments and render each through Markdown.

Because `<img>` HTML passes through Markdown rendering untouched, no path-rewriting is needed
after splitting.

## Supported formats

| Extension       | MIME type         |
|-----------------|-------------------|
| `.png`          | `image/png`       |
| `.jpg`, `.jpeg` | `image/jpeg`      |
| `.gif`          | `image/gif`       |
| `.webp`         | `image/webp`      |
| `.svg`          | `image/svg+xml`   |

Unknown extensions: skip, leave original syntax, log warning.

## Missing images

If not found on disk:
- Log: `[warn] image not found: <path> (referenced from <file>)`
- Replace with: `<span class="missing-image">[missing image: <alt>]</span>`
- Do NOT abort.

## Large images

For images > 5 MB: log warning but still embed. No resizing (would require Pillow dependency).