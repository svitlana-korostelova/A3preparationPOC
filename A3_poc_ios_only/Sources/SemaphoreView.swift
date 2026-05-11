import SwiftUI

// ════════════════════════════════════════════════════════════════════════════
// Semaphores Demo
//
// A DispatchSemaphore maintains a count.
//   • signal()  increments the count (never blocks).
//   • wait()    decrements the count; if the count would go below 0 it
//               BLOCKS the calling thread until another thread calls signal().
//
// Common uses:
//   1. Mutex (value: 1)       – only one thread in the critical section
//   2. Signalling (value: 0)  – block a thread until another signals it
//   3. Rate limiting (value N)– allow at most N concurrent accesses
// ════════════════════════════════════════════════════════════════════════════

struct SemaphoreView: View {

    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("Mutex (1)",    color: .blue)   { runMutex() }
                    demoButton("Signal (0)",   color: .purple) { runSignalling() }
                    demoButton("Rate Limit(3)",color: .orange) { runRateLimit() }
                    demoButton("Sync Await",   color: .teal)   { runSyncAwait() }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()
            logView
        }
        .navigationTitle("Semaphores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") { log.removeAll() }
            }
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

    private func append(_ line: String) {
        DispatchQueue.main.async { log.append(line) }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 1 – Mutex (initial value = 1)
    //
    // Like a binary lock: only ONE thread may be in the critical section.
    // Any extra thread blocks on wait() until the first calls signal().
    // ════════════════════════════════════════════════════════════════════════
    private func runMutex() {
        log.append("── Semaphore as Mutex (value=1) ──")

        // 1. Initial value 1 → first wait() succeeds immediately.
        let mutex = DispatchSemaphore(value: 1)
        var sharedCounter = 0
        let queue = DispatchQueue(label: "com.poc.sem.mutex", attributes: .concurrent)

        for i in 1...4 {
            queue.async {
                // 2. wait() decrements counter to 0 → thread enters critical section.
                //    All other threads that reach wait() block here.
                mutex.wait()
                append("[\(i)a] Mutex: thread \(i) entered critical section, counter=\(sharedCounter)")

                // ── Critical section ──────────────────────────────────────
                sharedCounter += 1                  // safe: only 1 thread here
                Thread.sleep(forTimeInterval: 0.1)
                let val = sharedCounter
                // ── End of critical section ───────────────────────────────

                // 3. signal() increments counter back to 1 → next waiting thread unblocks.
                mutex.signal()
                append("[\(i)b] Mutex: thread \(i) left, counter=\(val)")
            }
        }

        append("[0] Mutex: 4 tasks dispatched to concurrent queue")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 2 – Signalling (initial value = 0)
    //
    // Thread B calls wait() and BLOCKS because the count starts at 0.
    // Thread A does work, then calls signal() to unblock Thread B.
    // Classic producer-consumer handoff.
    // ════════════════════════════════════════════════════════════════════════
    private func runSignalling() {
        log.append("── Semaphore as Signal (value=0) ──")

        // 1. Initial value 0 → wait() will block immediately.
        let sem = DispatchSemaphore(value: 0)

        // 2. "Consumer" thread – waits for data to be ready.
        DispatchQueue.global(qos: .default).async {
            append("[1] Consumer: calling wait() – will BLOCK until producer signals")
            sem.wait()                              // ← blocks here
            // 5. Unblocked after producer calls signal().
            append("[4] Consumer: unblocked – data is ready, processing…")
        }

        // 3. "Producer" thread – simulates work then signals.
        DispatchQueue.global(qos: .userInitiated).async {
            append("[2] Producer: starting work…")
            Thread.sleep(forTimeInterval: 0.5)     // simulate data fetch
            append("[3] Producer: work done, calling signal()")
            sem.signal()                            // ← unblocks consumer
        }

        append("[0] Signal: consumer and producer both dispatched")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 3 – Rate Limiting (initial value = N)
    //
    // Only N tasks may proceed concurrently. Extras wait until a slot frees.
    // Useful for limiting simultaneous network requests, DB connections, etc.
    // ════════════════════════════════════════════════════════════════════════
    private func runRateLimit() {
        log.append("── Semaphore Rate Limiting (N=3, 6 tasks) ──")

        // 1. Allow at most 3 concurrent tasks.
        let slots = DispatchSemaphore(value: 3)
        let queue = DispatchQueue(label: "com.poc.sem.rate", attributes: .concurrent)

        for i in 1...6 {
            queue.async {
                // 2. Each task tries to acquire a slot.
                //    Tasks 4, 5, 6 block until one of 1-3 finishes.
                slots.wait()
                append("[\(i)a] RateLimit: task \(i) acquired slot")

                Thread.sleep(forTimeInterval: 0.3)  // simulate work

                // 3. Release the slot so a waiting task can proceed.
                slots.signal()
                append("[\(i)b] RateLimit: task \(i) released slot")
            }
        }

        append("[0] RateLimit: 6 tasks dispatched, max 3 run at once")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 4 – Synchronous wait (bridging async → sync)
    //
    // Sometimes (e.g. in a unit test or non-async context) you need to block
    // the current thread until async work finishes. A semaphore with value 0
    // is the classic pattern for this.
    //
    // ⚠️ NEVER call .wait() on the main thread – it causes a deadlock if the
    //    completion also needs the main thread, and it freezes the UI.
    // ════════════════════════════════════════════════════════════════════════
    private func runSyncAwait() {
        log.append("── Semaphore Sync-Await Bridge ──")

        // 1. Run everything on a background thread so we don't block the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            append("[1] SyncAwait: running on background thread")

            // 2. Semaphore with value 0 – wait() will block.
            let done = DispatchSemaphore(value: 0)

            // 3. Call the "async" function (callback-based, not Swift async).
            self.fetchDataWithCallback { result in
                // 4. Callback fires on some background thread.
                self.append("[3] SyncAwait: callback received result: \(result)")
                done.signal()                       // ← unblock the waiter
            }

            // 4. Block THIS background thread until signal() is called above.
            append("[2] SyncAwait: blocking background thread with wait()…")
            done.wait()

            // 5. Execution continues only after the callback called signal().
            append("[4] SyncAwait: wait() returned – continuing synchronously ✓")
        }

        append("[0] SyncAwait: kicked off on background thread")
    }

    /// Simulates a callback-based async function (e.g. URLSession pre-async API).
    private func fetchDataWithCallback(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.4) {
            completion("42")
        }
    }
}

#Preview {
    NavigationStack { SemaphoreView() }
}
