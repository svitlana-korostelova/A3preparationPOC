# Concurrency Patterns

**Purpose**: Reference for the concurrency primitives demonstrated in this interview-prep PoC and when each is the right choice.

All demos live in `A3_poc_ios_only/Sources/` and follow the same visual layout (see `architecture.md`).

---

## Map of Demos

| Topic | File | Primary Primitives |
|-------|------|-------------------|
| GCD | `GCDView.swift` | Serial / Concurrent `DispatchQueue`, `DispatchGroup`, main-queue hop |
| OperationQueue | `OperationQueueView.swift` | `Operation`, `OperationQueue`, dependencies, cancellation |
| Semaphores | `SemaphoreView.swift` | `DispatchSemaphore` (counting & binary) |
| Locks | `LocksView.swift` | `NSLock`, `NSRecursiveLock`, `os_unfair_lock`, serial-queue-as-lock |
| Structured Concurrency | `StructuredConcurrencyView.swift` | `async/await`, `async let`, `TaskGroup`, `actor`, `MainActor`, cancellation |
| pthreads | `PThreadsView.swift` | C `pthread_create` / `pthread_join` |
| Combine | `CombineView.swift` | `PassthroughSubject`, `CurrentValueSubject`, `@Published`, operators, `combineLatest` |

---

## Choosing a Primitive (interview cheat-sheet)

| Need | Prefer | Why |
|------|--------|-----|
| Run async work and await result | `async/await` + `Task` | Structured, cancellation propagates, no callback hell |
| Fan-out parallel work, fixed N | `async let` | Eager, ergonomic, clear at call site |
| Fan-out parallel work, dynamic N | `TaskGroup` / `withThrowingTaskGroup` | Dynamic count, can collect results |
| Protect mutable state in async code | `actor` | Compiler-enforced isolation |
| Update UI from background | `@MainActor` or `DispatchQueue.main.async` | Required for UIKit/SwiftUI |
| Wait for several async tasks (legacy / GCD) | `DispatchGroup` | Pre-async/await codebases |
| Limit concurrent access to N | `DispatchSemaphore(value: N)` | Counting semaphore, e.g. throttle network calls |
| Tight critical section, hot path | `os_unfair_lock` (boxed) | Lowest overhead; not recursive, not fair |
| Recursive critical section | `NSRecursiveLock` | Same thread can re-enter |
| Operation with dependencies / cancellation in legacy code | `Operation` + `OperationQueue` | Built-in `addDependency`, KVO, cancel |

Avoid raw `pthread_*` in app code — kept in this repo only for interview completeness.

---

## Pattern Snippets

### Main-thread hop (GCD)

```swift
DispatchQueue.global(qos: .userInitiated).async {
    let result = doHeavyWork()
    DispatchQueue.main.async {
        self.label.text = result   // UI must be on main
    }
}
```

`A3_poc_ios_only/Sources/GCDView.swift:200-221`

### `async let` parallel fan-out

```swift
async let a = fetchA()
async let b = fetchB()
let (resA, resB) = try await (a, b)
```

`A3_poc_ios_only/Sources/StructuredConcurrencyView.swift` — `runAsyncLet()`.

### Actor for shared state

```swift
actor Counter {
    private var value = 0
    func inc() { value += 1 }
    func read() -> Int { value }
}
```

`A3_poc_ios_only/Sources/StructuredConcurrencyView.swift` — `runActor()`.

### DispatchGroup notify

```swift
let group = DispatchGroup()
for i in 1...3 {
    group.enter()
    queue.async { /* work */ ; group.leave() }
}
group.notify(queue: .main) { /* all done */ }
```

`A3_poc_ios_only/Sources/GCDView.swift:165-192`

### Combine: `@Published` → operators

```swift
$searchText
    .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
    .removeDuplicates()
    .map { runSearch($0) }
    .assign(to: &$searchResult)
```

`A3_poc_ios_only/Sources/CombineView.swift:173-185`

---

## Common Interview Pitfalls Highlighted in the Demos

- **Priority inversion / deadlock with `sync` on the same serial queue** — never call `serial.sync` from a block already running on `serial`.
- **Forgetting `[weak self]`** in long-lived `sink {}` / `Task {}` closures → retain cycle.
- **Touching UI off-main** — purple runtime warning in Xcode; use `@MainActor` or main hop.
- **`async let` not awaited** — compiler warns, but a discarded `async let` still runs and can leak work; always `await` or explicitly cancel.
- **`os_unfair_lock` recursion** — undefined behaviour; switch to `NSRecursiveLock` if recursion is needed.
- **Combine subscriptions not stored** — they are cancelled immediately; always `.store(in: &cancellables)` or `assign(to:)` to a `@Published`.

---

## Adding a New Concurrency Demo

1. Add `<Topic>View.swift` under `Sources/` with the standard layout (button row + log view + Clear toolbar).
2. Add a `NavigationLink` to it inside `HomeView`'s `Section`.
3. Run `xcodegen generate` to refresh the project file.
4. Keep each `runXxx()` self-contained — no shared globals across demos (see exception: `bankBalance` in `LocksView.swift:19`, deliberately global to demonstrate races).
