# SwiftUI Patterns

**Purpose**: SwiftUI conventions used across the demo screens and recurring snippets useful in Senior iOS interview discussions.

---

## State Ownership Cheat-Sheet

| Wrapper | Use When | Lifetime |
|---------|----------|----------|
| `@State` | View owns simple value-type state | Tied to view identity |
| `@Binding` | Child mutates state owned by parent | Parent's lifetime |
| `@StateObject` | View creates & owns a reference-type model | Tied to view identity |
| `@ObservedObject` | View receives a model owned elsewhere | External |
| `@EnvironmentObject` | Inject deep into view tree | Provided by ancestor |
| `@Published` | Property in `ObservableObject` triggers updates | Owner's lifetime |

**Rule**: *create with `@StateObject`, pass with `@ObservedObject`, inject with `@EnvironmentObject`.* Mixing these up is the most common SwiftUI interview trap.

---

## Demo Screen Skeleton

Every topic screen in this repo follows this skeleton — copy it when adding a new demo.

```swift
struct TopicView: View {
    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("Demo A", color: .blue)   { runDemoA() }
                    demoButton("Demo B", color: .purple) { runDemoB() }
                }.padding(.horizontal)
            }.padding(.vertical, 12)
            Divider()
            logView
        }
        .navigationTitle("Topic")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") { log.removeAll() }
            }
        }
    }
}
```

Reference: `A3_poc_ios_only/Sources/GCDView.swift:20-46`.

---

## Auto-Scrolling Log View

Reusable pattern for showing a streaming log that follows the latest entry.

```swift
private var logView: some View {
    ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(log.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                        .id(index)
                }
            }.padding()
        }
        .onChange(of: log.count) { _, _ in
            if let last = log.indices.last {
                withAnimation { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }
}
```

`A3_poc_ios_only/Sources/GCDView.swift:64-82`. The two-parameter `onChange(of:_:)` is the iOS 17+ API; the single-parameter form is deprecated.

---

## Navigation

The app uses `NavigationStack` (iOS 16+) with `NavigationLink(destination:)` rows in a `List`. See `A3_poc_ios_only/Sources/HomeView.swift:13-48`.

For value-driven navigation (deep links, state restoration) prefer:

```swift
NavigationStack(path: $path) {
    List(topics) { topic in
        NavigationLink(value: topic) { Label(topic.title, systemImage: topic.icon) }
    }
    .navigationDestination(for: Topic.self) { TopicView(topic: $0) }
}
```

Currently unused, but commonly asked about in interviews.

---

## ViewModel Pattern (MVVM-lite)

Use when the screen owns subscriptions, async work, or needs testability.

```swift
@MainActor
final class FeatureViewModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    private var cancellables = Set<AnyCancellable>()
    func load() { /* ... */ }
}

struct FeatureView: View {
    @StateObject private var vm = FeatureViewModel()
    var body: some View { /* read vm.items */ }
}
```

`@MainActor` on the VM removes the need for manual main-queue hops when mutating `@Published` properties. See `A3_poc_ios_only/Sources/CombineView.swift:20-31`.

---

## Common Pitfalls

- **`@StateObject` recreated on every render** — only happens if you misuse `@ObservedObject` for ownership; `@StateObject` is created exactly once per view identity.
- **Modifying state during view update** — e.g. calling `vm.load()` inside `body`. Use `.task { }` or `.onAppear { }`.
- **Long-running work on `MainActor`** — blocks UI. Call out to a `nonisolated` async function and `await` it.
- **`#Preview` crashes with environment objects** — provide stubs: `.environmentObject(StubVM())`.
- **Forgetting `id:` in `ForEach`** — leads to incorrect diffing; use stable identity (`\.id`) over `\.offset` for real data (offset is fine for append-only logs as in this PoC).
