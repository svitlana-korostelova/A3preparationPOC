# Swift Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create Chapter 1, “Swift Foundation,” in synchronized Markdown and HTML Knowledge Base trees.

**Architecture:** The Markdown file is the chapter-level source-like document. The HTML tree contains a chapter index and one rendered point per topic, matching the existing Knowledge Base layout. The root HTML index receives one new chapter link.

**Tech Stack:** Markdown, static HTML, existing Knowledge Base CSS and breadcrumb conventions.

---

### Task 1: Create the chapter content

**Files:**
- Create: `Knowledge Base/Private & Shared-1/1 Swift Foundation.md`

- [ ] **Step 1:** Add the chapter heading and six sections: Swift language fundamentals; optionals and collections; closures; protocols and generics; error handling; value and reference semantics.
- [ ] **Step 2:** Add interview-focused explanations, examples, and trade-offs for types, optionals, collections, closures, protocols, generics, `throws`/`Result`, structs/classes, and copy-on-write.
- [ ] **Step 3:** Verify the file has a unique `# 1. Swift Foundation` heading and `###` headings for every HTML point.

### Task 2: Create the HTML chapter tree

**Files:**
- Create: `Knowledge Base/knowledge-base/1. Swift Foundation/index.html`
- Create: `Knowledge Base/knowledge-base/1. Swift Foundation/1 Topics/index.html`
- Create: one HTML point file for each `###` heading in the Markdown chapter

- [ ] **Step 1:** Copy the repository’s existing static HTML CSS and breadcrumb structure.
- [ ] **Step 2:** Add a chapter index linking to `1 Topics/index.html`.
- [ ] **Step 3:** Add a topic index linking to each point file with URL-encoded filenames.
- [ ] **Step 4:** Render each Markdown point as valid HTML inside `<main>`, preserving identical heading text.

### Task 3: Link Chapter 1 from the root index

**Files:**
- Modify: `Knowledge Base/knowledge-base/index.html`

- [ ] **Step 1:** Add `<li><a href="1.%20Swift%20Foundation/index.html">1. Swift Foundation</a></li>` to the root table of contents.
- [ ] **Step 2:** Keep the existing generated topic links unchanged.

### Task 4: Validate synchronization and structure

**Files:**
- Verify all files created in Tasks 1–3.

- [ ] **Step 1:** Confirm every HTML point `<h1>` has exactly one matching Markdown `###` heading.
- [ ] **Step 2:** Check all new HTML files have balanced document tags and working relative links.
- [ ] **Step 3:** Confirm the root index links to the new chapter and the chapter indexes link to every point.
