# Worked End-to-End Example

## Input

The full Notion export archive:

```
Archive/
├── Private & Shared-2/
│   ├── 2 1 SwiftUI/
│   │   ├── image 1.png
│   │   └── image.png
│   └── 2 1 SwiftUI 32e225aa4424806e8222e4d85c913162.md
├── Private & Shared-3/
│   ├── 2 2 UIKit/
│   │   └── image.png
│   └── 2 2 UIKit 0eb88896025d4a20a8e503f3aa53b137.md
├── Private & Shared-5/
│   ├── 4 Concurrency & Multithreading/
│   │   ├── image 1.png
│   │   └── image.png
│   └── 4 Concurrency & Multithreading c85870ac06b04be6a1b97fa2a9c95401.md
├── Private & Shared-10/
│   └── Storage & Persistence 435725c254344ab58e27290d8dbc727c.md
... (20 total topics)
```

## Invocation

```
/md-to-html-archive ~/Archive
```

Claude runs:
```bash
pip install --quiet markdown pygments
python .claude/skills/md-to-html-archive/scripts/generate.py ~/Archive --open
```

## Generated output (abbreviated)

```
~/Archive/knowledge-base/
├── index.html                                    ← entry point: flat list of all 20 topics
│
├── 2.1 SwiftUI/
│   ├── index.html
│   └── ... (sections from the SwiftUI .md)
│
├── 2.2 UIKit/
│   ├── index.html                                ← TOC: 1, 2, 3, 4, 5, 6, 7, 8
│   ├── 1 View Controllers and Navigation/
│   │   ├── index.html                            ← TOC: 1.1, 1.2, 1.3, …, 1.8
│   │   ├── 1.1 View controller lifecycle.html
│   │   ├── 1.2 Why do we need viewDidLoad if initial setup methods can be done in init().html
│   │   ├── 1.3 AppDelegate vs SceneDelegate.html
│   │   ├── 1.4 How do you implement custom transitions between view controllers.html  ← TODO content
│   │   ├── 1.5 What are the differences between modal and push navigation….html
│   │   ├── 1.6 How do you manage child view controllers….html
│   │   ├── 1.7 TabViewController example.html
│   │   └── 1.8 UIViewControllerTopViewController - why its exist on almost every project.html
│   ├── 2 Views/
│   │   ├── index.html
│   │   ├── 2.1 UIView lifecycle.html
│   │   ├── 2.2 CA Layer vs UIView TODO Ira.html
│   │   ├── ...
│   │   ├── 2.8 How will you implement collection view with different size of cells.html
│   │   ├── 2.8.1 How do you choose between UITableView and UICollectionView….html    ← auto-numbered
│   │   ├── 2.8.2 What are the advantages of using Auto Layout….html                  ← auto-numbered
│   │   ├── 2.8.3 How do you handle dynamic layouts….html                             ← auto-numbered
│   │   └── 2.8.4 When would you use UIStackView….html                                ← auto-numbered
│   ├── 3 Layout/
│   │   ├── index.html
│   │   ├── 3.1 What is Auto Layout.html
│   │   ├── 3.2 Difference between frame and bounds in UIView.html    ← image.png embedded as base64
│   │   ├── 3.3 What is IBInspectable  IBDesignable opinion.html
│   │   └── 3.3.1 TODO Sveta Whats wrong with extension for UIImageView….html         ← auto-numbered; `/` `:` `?` `'` omitted from filename
│   ├── 4 User Interaction & Animations/
│   │   ├── index.html
│   │   └── ... (leaf pages for each ### heading)
│   ├── 5 Customization & Appearance/
│   │   └── ...
│   ├── 6 Advanced topics/
│   │   └── ...
│   ├── 7 How to implement/
│   │   ├── index.html
│   │   ├── 7.1 How to implement pull to refresh.html
│   │   ├── 7.1.1 How will you implement custom animation….html                       ← auto-numbered
│   │   ├── 7.1.2 How to round only two angles in view.html                           ← auto-numbered
│   │   └── 7.1.3 How to implement zoom with 2 fingers.html                           ← auto-numbered
│   └── 8 Accessibility.html                      ← leaf (no children)
│
├── 4 Concurrency & Multithreading/
│   ├── index.html                                ← TOC: 4.1, 4.2, 4.3, 4.4, 4.5, Thread safe array, …, Sendable & swift6
│   ├── 4.1 Concept of multithreading vs concurrency vs parallelism.html
│   ├── 4.2 Why multithreading purpose.html
│   ├── 4.3 iOS multithreading options.html
│   ├── 4.4 Grand Central Dispatch/
│   │   ├── index.html
│   │   ├── 4.4.1 QualityOfService.html
│   │   └── 4.4.2 How to make task 3 waiting completes tasks 1 and 2.html
│   ├── 4.5 OperationQueue/
│   │   ├── index.html
│   │   ├── 4.5.1 Example.html
│   │   ├── 4.3.2 Operation.html                 ← original number preserved (structural child of 4.5)
│   │   └── 4.3.3 BlockOperation.html            ← same: original number preserved
│   ├── 4.5.1 Thread safe array.html             ← non-numbered "## Thread safe array" auto-numbered
│   ├── ... (many leaf pages for notes-only headings)
│   └── Sendable & swift6/                       ← stray H1 demoted to H2; becomes a folder
│       ├── index.html
│       ├── 11.1 What is Sendable and why does it exist.html
│       ├── 11.2 Sendable vs Codable — when to use each.html    ← image.png embedded
│       ├── 11.3 How does Swift 6 enforce Sendable….html
│       ├── 11.4 Making classes Sendable — the challenge.html
│       ├── 11.5 Sendable + Actor isolation + Structured Concurrency.html
│       ├── 11.6 Property wrappers closures and generics.html
│       ├── 11.7 Real-world bug Sendable prevents.html
│       └── 11.8 Does Sendable applicable to UIKit.html          ← image 1.png embedded
│
├── Storage & Persistence/                        ← no H1 number; uses stripped file stem
│   └── ...
├── AI/
├── App Extensions/
├── ... (remaining topics)
└── Testing/
```

## Key behaviors demonstrated

1. ✅ `Private & Shared-N` wrappers dropped — topics named after H1 headings.
2. ✅ Mixed-depth branches: `4.1` is a leaf, `4.4` and `4.5` are folders with children.
3. ✅ Non-numbered headings auto-numbered as children of preceding numbered sibling.
4. ✅ Illegal chars (`/`, `:`, `?`, `'`) omitted from filenames but preserved in `<h1>`.
5. ✅ Skipped heading levels normalized (H3 `### 4.1` directly under H1 treated as depth-2).
6. ✅ Stray second H1 (`# Sendable & swift6`) demoted to H2 — becomes a section folder.
7. ✅ Images embedded as base64 — no binary files in output.
8. ✅ Notion hashes stripped from fallback topic names.
9. ✅ TODO/empty sections produce valid (mostly-empty) HTML pages.
10. ✅ Every parent folder has `index.html` with breadcrumb up-navigation.
11. ✅ Script auto-detects input type (full archive, single folder, single file).
12. ✅ Browser opens automatically with `--open`.

## Verification checklist

After running:

- [ ] No `.png`, `.jpg`, or binary files under `knowledge-base/`
- [ ] No `<script>` or `<link>` tags in any HTML file
- [ ] Opening `knowledge-base/index.html` shows ~20 topic links
- [ ] Clicking through 3 levels deep loads without 404s
- [ ] Code blocks render monospaced with tinted background
- [ ] Swift code not HTML-escape-mangled (no visible `&lt;`)
- [ ] Breadcrumbs link upward correctly
- [ ] Empty/TODO pages are valid HTML
- [ ] Auto-numbered headings appear in parent index.html
- [ ] The `--open` flag launched the browser

## Sample console output

```
$ python .claude/skills/md-to-html-archive/scripts/generate.py ~/Archive --open
[info] input mode: full
[info] archive root: /Users/svitlana/Archive
[info] found 20 markdown file(s)
[info] processing: 2 1 SwiftUI 32e225aa4424806e8222e4d85c913162.md
[info]   embedded 2 image(s)
[info]   built tree: 5 sections, 12 leaves, 3 nested folders
[info] processing: 2 2 UIKit 0eb88896025d4a20a8e503f3aa53b137.md
[info]   embedded 1 image(s)
[info]   built tree: 8 sections, 42 leaves, 7 nested folders
[info] processing: 4 Concurrency & Multithreading c85870ac06b04be6a1b97fa2a9c95401.md
[info]   embedded 2 image(s)
[info]   built tree: 6 sections, 35 leaves, 4 nested folders
[info] processing: Storage & Persistence 435725c254344ab58e27290d8dbc727c.md
[info]   embedded 0 image(s)
[info]   built tree: 4 sections, 18 leaves, 2 nested folders
...
[info] writing knowledge base: /Users/svitlana/Archive/knowledge-base/
[ok]   wrote 312 HTML files in 78 folders across 20 topic(s)
[ok]   open: /Users/svitlana/Archive/knowledge-base/index.html
[info] opening in browser...
```