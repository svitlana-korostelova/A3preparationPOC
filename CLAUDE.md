# CLAUDE.md

**Purpose**: AI-optimized execution guide for Claude Code agents working on the **A3 Senior iOS Developer interview-prep PoC**.

This repo is a learning playground used to prepare for a Senior iOS Developer interview / assessment. The Xcode app lives in `A3_poc_ios_only/` and currently demonstrates concurrency primitives, with more iOS topics (architecture, persistence, networking, UIKit interop, testing, etc.) expected to be added over time.

---

## 🚨 CRITICAL RULES (Check Every Task)

| Rule | Trigger | Action |
|------|---------|--------|
| **Check Guides First** | ANY task | Read relevant guides in `.codemie/guides/` BEFORE searching codebase |
| **Testing** | User says "test", "write tests", "run tests" | ONLY then work on tests (no test target exists yet — confirm before scaffolding one) |
| **Git Ops** | User says "commit", "push", "PR", "branch" | ONLY then do git operations |
| **Xcode Project** | Adding/removing/renaming source files | Edit `A3_poc_ios_only/project.yml` if structure changes, then run `xcodegen generate`; never hand-edit `.xcodeproj/project.pbxproj` |
| **Shell** | ANY shell command | Use bash/zsh syntax (macOS) |

**Recovery**: If stuck → check [Troubleshooting](#-troubleshooting).

---

## 📚 GUIDE IMPORTS

| Category | Guide Path | Purpose |
|----------|------------|---------|
| Architecture | `.codemie/guides/architecture/architecture.md` | App layout, demo screen pattern, MVVM-lite, where to add new topics |
| Development Practices | `.codemie/guides/development/concurrency-patterns.md` | GCD, OperationQueue, semaphores, locks, structured concurrency, pthreads, Combine — when to pick which |
| Development Practices | `.codemie/guides/development/swiftui-patterns.md` | State wrappers, demo screen skeleton, auto-scrolling log view, navigation, MVVM |

---

## ⚡ TASK CLASSIFIER

**Analyze request intent → match category → load matching guide(s).**

| Category | User Intent | Example Requests | P0 Guide | P1 Guide |
|----------|-------------|------------------|----------|----------|
| **Architecture** | Where to put new code, app structure, adding a new interview topic screen | "Add a screen for memory management", "How is the project organized?" | `.codemie/guides/architecture/architecture.md` | — |
| **Concurrency** | GCD, async/await, actors, locks, Combine threading | "Show me an actor example", "Explain DispatchGroup", "Fix this race" | `.codemie/guides/development/concurrency-patterns.md` | `.codemie/guides/development/swiftui-patterns.md` |
| **SwiftUI / UI** | Views, state management, navigation, ViewModels | "Add a button row", "Why does my @StateObject reset?" | `.codemie/guides/development/swiftui-patterns.md` | `.codemie/guides/architecture/architecture.md` |
| **Interview Q&A** | Conceptual questions about iOS topics already in the repo | "Why os_unfair_lock vs NSLock?", "When does async let leak?" | Match topic above | — |

### Intent Detection

```
USER REQUEST
    ├─> Primary deliverable? → Primary Category (load P0)
    ├─> Cross-cutting topic? → Secondary Categories (load their P0s)
    └─> Files affected? → 1-2 Simple, 3-5 Medium, 6+ High
```

### Complexity Guide

| Level | Indicators | Action |
|-------|------------|--------|
| **Simple** | 1-2 files | Read P0 guide if unsure |
| **Medium** | 3-5 files | Load P0 guides |
| **High** | New screen + structural change | Load P0+P1, run `xcodegen generate`, validate build |

---

## 🔄 EXECUTION WORKFLOW

```
START
  ├─> STEP 1: Parse Request → match intent → assess complexity
  ├─> STEP 2: Load P0 guide(s); if confidence < 80% load P1 or ask user
  ├─> STEP 3: Execute → apply patterns from guides → follow Critical Rules
  └─> STEP 4: Validate → checklist → deliver
```

### Pre-Delivery Checklist

- [ ] Matches user request?
- [ ] Follows patterns from loaded guides?
- [ ] Critical Rules respected (Xcode project, git, shell)?
- [ ] If new source files added: `xcodegen generate` ran successfully?
- [ ] No hardcoded secrets?

---

## 🛠️ COMMANDS

All commands run from `A3_poc_ios_only/` unless noted.

| Task | Command | Notes |
|------|---------|-------|
| **Setup** | `brew install xcodegen` | One-time; XcodeGen is the only build tool dependency |
| **Generate Xcode project** | `xcodegen generate` | Run after editing `project.yml` or adding/removing source files |
| **Open in Xcode** | `open A3PocIOS.xcodeproj` | |
| **Build (CLI)** | `xcodebuild -project A3PocIOS.xcodeproj -scheme A3PocIOS -destination 'platform=iOS Simulator,name=iPhone 15' build` | Headless build sanity-check |
| **Run** | Use Xcode ▶ on iOS 17+ Simulator | Deployment target is iOS 17.0 |
| **Test** ⚠️ | *No test target yet* | Ask user before scaffolding one |

---

## 🏗️ PROJECT CONTEXT

### Technology Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Language | Swift | 5.9 |
| UI Framework | SwiftUI | iOS 17+ |
| Reactive | Combine | iOS 17+ |
| Project generator | XcodeGen | latest |
| Min iOS | iOS | 17.0 |
| Tests | none | — |

### Project Structure

```
A3preparationPOC/                 # repo root (docs + Claude config)
├── CLAUDE.md                     # this file
├── .codemie/guides/              # AI-optimized topic guides
├── .claude/skills/               # superpowers skills (symlinks)
└── A3_poc_ios_only/              # the actual iOS app
    ├── project.yml               # XcodeGen spec
    ├── A3PocIOS.xcodeproj/       # generated
    └── Sources/
        ├── A3PocIOSApp.swift     # @main
        ├── HomeView.swift        # navigation hub
        └── *View.swift           # one per interview topic
```

### Current Topic Coverage

| Topic | File | Status |
|-------|------|--------|
| GCD | `Sources/GCDView.swift` | ✅ |
| OperationQueue | `Sources/OperationQueueView.swift` | ✅ |
| Semaphores | `Sources/SemaphoreView.swift` | ✅ |
| Locks | `Sources/LocksView.swift` | ✅ |
| Structured Concurrency | `Sources/StructuredConcurrencyView.swift` | ✅ |
| pthreads | `Sources/PThreadsView.swift` | ✅ |
| Combine | `Sources/CombineView.swift` | ✅ |
| Memory management / ARC | — | planned |
| Networking / URLSession | — | planned |
| Persistence (CoreData / SwiftData) | — | planned |
| UIKit interop | — | planned |
| Testing (XCTest) | — | planned |

When adding a planned topic, follow `architecture.md` → "Adding a New Interview Topic".

---

## 🔧 TROUBLESHOOTING

| Symptom | Cause | Solution |
|---------|-------|----------|
| New `*.swift` file not visible in Xcode | `project.yml` regenerated wasn't run | `cd A3_poc_ios_only && xcodegen generate` |
| `command not found: xcodegen` | XcodeGen not installed | `brew install xcodegen` |
| Build fails with "Min deployment target" | Using API < iOS 17 | Project targets iOS 17.0; either bump API or lower target in `project.yml` |
| `.xcuserstate` keeps showing in `git status` | Xcode UI state churn | Already harmless; can be added to `.gitignore` if it gets noisy |
| Purple runtime warning ("Publishing changes from background threads") | UI mutation off main | Wrap in `DispatchQueue.main.async` or mark VM `@MainActor` |

---

## 🎯 REMEMBER

1. **Parse** → match intent (Task Classifier).
2. **Load** P0 guide(s).
3. **Check** confidence ≥ 80%? If not, load P1 or ask the user.
4. **Execute** using patterns from the guides.
5. **Validate** against the checklist (especially `xcodegen generate` after structural changes).
6. **Deliver**.

### When to Ask the User

- Adding a brand-new top-level topic that doesn't match an existing guide.
- Scaffolding a test target (none exists today).
- Changing iOS deployment target or Swift version.
- Touching `project.pbxproj` directly (don't — edit `project.yml`).
