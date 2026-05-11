import SwiftUI
import Combine

// ════════════════════════════════════════════════════════════════════════════
// Structured Concurrency Demo (Swift 5.5+)
//
// Swift's concurrency model builds structure around async work:
//   • Every Task has a parent → child tasks are cancelled when the parent is.
//   • async/await – suspends the function, frees the thread while waiting.
//   • async let   – starts work eagerly in parallel, awaits later.
//   • TaskGroup   – dynamic fan-out with a fixed result type.
//   • Actor       – reference type that serialises its own state access.
//   • MainActor   – the special actor that runs on the main thread.
// ════════════════════════════════════════════════════════════════════════════

struct StructuredConcurrencyView: View {

    @State private var log: [String] = []
    // Keep a handle so we can cancel from the UI.
    @State private var cancellableTask: Task<Void, Never>?
    
    //TODO: make that Promise 
    let a: Future<Int, Error>? = Future { promise in
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            promise(.success(10))
        }
        //in else block
        //promise(.failure(URLError(.badServerResponse)))
    }


    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("async/await",  color: .blue)   {
                        Task {
                            runAsyncAwait()
                            runAsyncAwait()
                            runAsyncAwait()
                        }
                    }
                    demoButton("async/await svetaTest",  color: .blue)   {
                        Task {
                            await svetaTest()
                            await svetaTest()
                            await svetaTest()
                        }
                    }
                    demoButton("async let",    color: .purple) { runAsyncLet() }
                    demoButton("TaskGroup",    color: .orange) { runTaskGroup() }
                    demoButton("Actor",        color: .teal)   { runActor() }
                    demoButton("Detached",     color: .green)  { runDetachedTask() }
                    demoButton("Cancel Task",  color: .red)    { runCancellableTask() }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()
            logView
        }
        .navigationTitle("Structured Concurrency")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    cancellableTask?.cancel()
                    log.removeAll()
                }
            }
        }
        .task {
            await svetaTest()
        }
    }

    // MARK: - UI helpers

    private func demoButton(_ title: String, color: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var logView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(log.enumerated()), id: \.offset) { i, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .id(i)
                    }
                }
                .padding()
            }
            .onChange(of: log.count) { _, _ in
                if let last = log.indices.last {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    // Called from async contexts – already on MainActor via @State.
    @MainActor
    private func append(_ line: String) {
        log.append(line)
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 1 – async / await  (sequential async calls)
    //
    // await suspends the current function until the called function returns.
    // The thread is released during suspension (unlike blocking sleep).
    // ════════════════════════════════════════════════════════════════════════
    private func runAsyncAwait() {
        // Task{} bridges from sync SwiftUI context into async world.
//        DispatchQueue.main.async {
//             append("── async/await ──")
//
//            // 1. Call an async function; suspend here until it resolves.
//             append("[1] Fetching user profile…")
//            let profile = await fakeNetworkCall(label: "profile", delay: 0.3)
//
//            // 2. Resumed after profile is ready. Call the next async function.
//             append("[2] Profile='\(profile)' – now fetching feed…")
//            let feed = await fakeNetworkCall(label: "feed", delay: 0.2)
//
//            // 3. Both calls completed sequentially: total ~0.5 s.
//             append("[3] Feed='\(feed)' – both calls sequential, done ✓")
//        }
        Task {
            await append("── async/await ──")

            // 1. Call an async function; suspend here until it resolves.
            await append("[1] Fetching user profile…")
            let profile = await fakeNetworkCall(label: "profile", delay: 0.3)

            // 2. Resumed after profile is ready. Call the next async function.
            await append("[2] Profile='\(profile)' – now fetching feed…")
            let feed = await fakeNetworkCall(label: "feed", delay: 0.2)

            // 3. Both calls completed sequentially: total ~0.5 s.
            await append("[3] Feed='\(feed)' – both calls sequential, done ✓")
        }
    }
    
    private func svetaTest() async {
        // Task{} bridges from sync SwiftUI context into async world.
//        Task.detached {
            await append("── async/await ──")

            // 1. Call an async function; suspend here until it resolves.
            await append("[1] Fetching user profile…")
            let profile = await fakeNetworkCall(label: "profile", delay: 3.3)

            // 2. Resumed after profile is ready. Call the next async function.
            await append("[2] Profile='\(profile)' – now fetching feed…")
            let feed = await fakeNetworkCall(label: "feed", delay: 0.2)

            // 3. Both calls completed sequentially: total ~0.5 s.
            await append("[3] Feed='\(feed)' – both calls sequential, done ✓")
//        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 2 – async let  (parallel async calls)
    //
    // async let starts the child task immediately WITHOUT suspending.
    // The await on the variable suspends only when the value is needed.
    // Total time ≈ max(profile, feed) instead of sum.
    // ════════════════════════════════════════════════════════════════════════
    private func runAsyncLet() {
        Task {
            await append("── async let (parallel) ──")

            // 1. Both tasks start IN PARALLEL right now.
            await append("[1] Starting profile AND feed fetches in parallel")
            async let profile = fakeNetworkCall(label: "profile", delay: 3.3)
            async let feed    = fakeNetworkCall(label: "feed",    delay: 0.2)

            // 2. Suspend until BOTH values are ready (like Promise.all).
            //    feed finishes first (~0.2 s), profile finishes at ~0.3 s.
            let (p, f) = await (profile, feed)

            // 3. Total wall time ≈ 0.3 s (max), not 0.5 s (sum).
            await append("[2] profile='\(p)', feed='\(f)' – parallel done ✓")
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 3 – withTaskGroup  (dynamic fan-out)
    //
    // Use when the number of parallel tasks is determined at runtime.
    // Child tasks are all cancelled if the group exits early.
    // ════════════════════════════════════════════════════════════════════════
    private func runTaskGroup() {
        Task {
            await append("── TaskGroup ──")
            let items = ["alpha", "beta", "gamma", "delta"]

            // 1. withTaskGroup creates the group; its body runs synchronously.
            let results = await withTaskGroup(of: String.self) { group in
                var collected: [String] = []

                // 2. Spawn one child task per item. Children run concurrently.
                for (i, item) in items.enumerated() {
                    group.addTask {
                        // 3. Each child does its own async work.
                        await self.append("[\(i+1)] Group: processing '\(item)'")
                        try? await Task.sleep(nanoseconds: UInt64((i + 1) * 100_000_000))
                        return item.uppercased()
                    }
                }

                // 4. Iterate over results AS EACH child finishes (not in order).
                for await result in group {
                    collected.append(result)
                    await self.append("[+] Group: collected '\(result)'")
                }

                return collected
            }   // 5. Group scope ends – all children guaranteed finished.

            await append("[5] Group: all done, results=\(results.sorted()) ✓")
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 4 – Actor
    //
    // An actor serialises access to its mutable state. Calling actor methods
    // from outside requires await, which ensures only one caller runs at a time.
    // ════════════════════════════════════════════════════════════════════════
    private func runActor() {
        Task {
            await append("── Actor ──")

            // 1. Create the actor instance.
            let counter = SafeCounter()

            // 2. Spawn multiple tasks that all try to increment concurrently.
            await withTaskGroup(of: Void.self) { group in
                for i in 1...5 {
                    group.addTask {
                        // 3. await serialises: only ONE increment runs at a time.
                        await counter.increment()
                        let val = await counter.value
                        await self.append("[\(i)] Actor: after increment, value=\(val)")
                    }
                }
            }

            // 4. Final value is always 5 – no data race possible.
            let final = await counter.value
            await append("[6] Actor: final value=\(final) (always correct, no race) ✓")
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 5 – Task.detached  (unstructured, no inherited context)
    //
    // Task.detached creates a top-level task that does NOT inherit:
    //   • the parent's priority
    //   • the parent's task-local values
    //   • the parent's actor context (e.g. @MainActor)
    //
    // Because it runs off the main actor, UI updates require explicit
    // MainActor.run {} or calling a @MainActor-isolated method.
    //
    // Use sparingly – most of the time a regular Task {} is better because
    // it preserves structured concurrency guarantees.
    // ════════════════════════════════════════════════════════════════════════
    private func runDetachedTask() {
        Task {
            await append("── Task.detached ──")
            await append("[1] Starting from MainActor (Task {})")

            // Launch a detached task – it does NOT inherit @MainActor.
            let handle = Task.detached(priority: .background) { [self] in
                // This closure runs on a background thread, NOT on MainActor.
                // Detached task does NOT inherit the caller's actor or priority.
                await self.append("[2] Detached: priority = \(Task.currentPriority) (background, not inherited)")

                // Simulate some heavy background work.
                let result = await self.fakeNetworkCall(label: "detached-fetch", delay: 0.5)
                await self.append("[4] Detached: got '\(result)'")

                // Show that we do NOT inherit the parent's cancellation.
                await self.append("[5] Detached: Task.isCancelled = \(Task.isCancelled)")

                return result
            }

            // Await the detached task's result back on MainActor.
            let value = await handle.value
            await append("[6] Back on MainActor: detached returned '\(value)' ✓")
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 6 – Task Cancellation
    //
    // Cancellation in Swift is cooperative: the task must check
    // Task.isCancelled (or call try Task.checkCancellation()) periodically.
    // ════════════════════════════════════════════════════════════════════════
    private func runCancellableTask() {
        // Cancel any previously running demo task.
        cancellableTask?.cancel()

        log.append("── Task Cancellation ──")

        // 1. Detach a new task and save the handle.
        cancellableTask = Task {
            await append("[1] CancelTask: started, will run 10 iterations")

            for i in 1...10 {
                // 2. Check before each unit of work.
                if Task.isCancelled {
                    await append("[!] CancelTask: isCancelled at iteration \(i) – stopping")
                    return
                }

                // 3. Task.sleep respects cancellation: it throws CancellationError
                //    if the task is cancelled while sleeping.
                do {
                    try await Task.sleep(nanoseconds: 200_000_000)   // 0.2 s
                } catch {
                    await append("[!] CancelTask: sleep cancelled at iteration \(i)")
                    return
                }

                await append("[\(i+1)] CancelTask: iteration \(i) done")
            }

            await append("[11] CancelTask: finished without cancellation ✓")
        }

        // 4. Schedule a cancel after 0.55 s (should interrupt around iteration 3).
        Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            await append("[2] CancelTask: calling cancel() externally")
            cancellableTask?.cancel()
        }
    }

    // MARK: - Shared fake async helper

    /// Simulates a network call. Using try? Task.sleep instead of Thread.sleep
    /// so the thread is truly released during the delay.
    private func fakeNetworkCall(label: String, delay: Double) async -> String {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return "\(label)_data"
    }
}

// ════════════════════════════════════════════════════════════════════════════
// SafeCounter – Actor example
//
// The `actor` keyword replaces `class` and adds mutual exclusion automatically.
// All stored properties are protected; callers must await access from outside.
// ════════════════════════════════════════════════════════════════════════════
actor SafeCounter {
    // 1. Private mutable state – only accessible through actor methods.
    private(set) var value: Int = 0

    // 2. Methods run on the actor's executor (serial) – no data races.
    func increment() {
        value += 1
    }
}

#Preview {
    NavigationStack { StructuredConcurrencyView() }
}
