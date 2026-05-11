import SwiftUI

// ════════════════════════════════════════════════════════════════════════════
// GCD – Grand Central Dispatch Demo
//
// GCD is Apple's C-based threading library built into libdispatch.
// Key concepts demonstrated here:
//   • Serial queues  – tasks run one-at-a-time in FIFO order
//   • Concurrent queues – tasks start FIFO but may overlap
//   • DispatchGroup   – synchronise a set of async tasks
//   • Main-queue hop  – always update UI from the main thread
// ════════════════════════════════════════════════════════════════════════════

struct GCDView: View {

    // Each demo appends human-readable steps into this array.
    // @MainActor makes every write happen on the main thread automatically.
    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // ── Button grid ──────────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("Serial Queue",      color: .blue)   { runSerialQueue() }
                    demoButton("Concurrent Queue",  color: .purple) { runConcurrentQueue() }
                    demoButton("DispatchGroup",     color: .orange) { runDispatchGroup() }
                    demoButton("Main-Queue Hop",    color: .green)  { runMainQueueHop() }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()

            // ── Log output ───────────────────────────────────────────────
            logView
        }
        .navigationTitle("GCD")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") { log.removeAll() }
            }
        }
    }

    // MARK: - UI helpers

    private func demoButton(_ title: String,
                             color: Color,
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
                    ForEach(Array(log.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .id(index)
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

    // MARK: - Append helpers

    private func append(_ line: String) {
        // [Step N] prefix is added by each demo so the reader can follow
        // the exact order of execution.
        DispatchQueue.main.async {          // ← safe main-thread UI update
            log.append(line)
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 1 – Serial Queue
    //
    // A serial DispatchQueue executes one block at a time.
    // Block 2 cannot start until Block 1 finishes.
    // ════════════════════════════════════════════════════════════════════════
    private func runSerialQueue() {
        log.append("── Serial Queue ──")

        // 1. Create a private serial queue (label is used in Instruments / crash logs).
        let serial = DispatchQueue(label: "com.poc.serial")

        // 2. Schedule Block A asynchronously – control returns immediately.
        serial.async {
            append("[1] Serial: Block A started (thread \(threadName()))")
            Thread.sleep(forTimeInterval: 0.3)          // simulate work
            append("[2] Serial: Block A finished")

            // 3. Block B is dispatched FROM inside Block A. Because this is
            //    a serial queue, B is placed behind A; it won't run until A
            //    calls its last line and returns.
        }

        // 4. Block B is also dispatched asynchronously from the calling thread.
        serial.async {
            // 5. Execution reaches here only AFTER Block A has fully finished.
            append("[3] Serial: Block B started – proves A finished first")
            Thread.sleep(forTimeInterval: 0.2)
            append("[4] Serial: Block B finished")
        }

        // 6. This runs right after the two async calls return, BEFORE A or B run.
        append("[0] Serial: Both async calls enqueued (may print before [1])")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 2 – Concurrent Queue
    //
    // A concurrent queue starts tasks in FIFO order, but they execute in
    // parallel across multiple threads from the thread pool.
    // ════════════════════════════════════════════════════════════════════════
    private func runConcurrentQueue() {
        log.append("── Concurrent Queue ──")

        // 1. Create a concurrent queue.
        let concurrent = DispatchQueue(label: "com.poc.concurrent",
                                       attributes: .concurrent)

        // 2. Dispatch three tasks. They will start in order but may finish
        //    in any order depending on the system scheduler.
        for i in 1...3 {
            concurrent.async {
                // 3. Each block starts, does work, then finishes.
                //    Observe the finish order – it often differs from start order.
                append("[\(i)a] Concurrent: Task \(i) started (thread \(threadName()))")
                let delay = Double(4 - i) * 0.2           // task 1 sleeps longest
                Thread.sleep(forTimeInterval: delay)
                append("[\(i)b] Concurrent: Task \(i) finished after \(delay)s")
            }
        }

        // 4. All three async calls return immediately; tasks run in parallel.
        append("[0] Concurrent: All three tasks enqueued")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 3 – DispatchGroup
    //
    // DispatchGroup lets you track multiple async tasks as a unit and
    // receive a single notification when ALL of them finish.
    // ════════════════════════════════════════════════════════════════════════
    private func runDispatchGroup() {
        log.append("── DispatchGroup ──")

        // 1. Create the group.
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.poc.group", attributes: .concurrent)

        // 2. Enter the group manually (useful when the async work is not
        //    dispatched through the group directly).
        for i in 1...3 {
            group.enter()                               // ← increment group count
            queue.async {
                // 3. Do work on a background thread.
                append("[\(i)] Group: Task \(i) started")
                Thread.sleep(forTimeInterval: Double(i) * 0.15)
                append("[\(i+3)] Group: Task \(i) done")
                group.leave()                           // ← decrement group count
            }
        }

        // 4. notify fires on the main queue when the group count reaches 0.
        //    This block is guaranteed to run after all three leave() calls.
        group.notify(queue: .main) {
            append("[7] Group: ALL tasks done – notified on main thread ✓")
        }

        append("[0] Group: All tasks enqueued, waiting for group…")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 4 – Main-Queue Hop
    //
    // Any UIKit / SwiftUI update MUST happen on the main thread.
    // Pattern: do heavy work on a background queue, then hop to main.
    // ════════════════════════════════════════════════════════════════════════
    private func runMainQueueHop() {
        log.append("── Main-Queue Hop ──")

        // 1. Kick off heavy work on a global background queue.
        //    .userInitiated means the user is waiting for this result.
        DispatchQueue.global(qos: .userInitiated).async {
            append("[1] Background: fetching data on thread \(threadName())")

            // 2. Simulate a network/disk call.
            Thread.sleep(forTimeInterval: 0.4)
            let result = "🎉 Data ready"

            // 3. HOP BACK to main queue to update the UI.
            //    Skipping this would cause "purple runtime warning" in Xcode.
            DispatchQueue.main.async {
                append("[2] Main thread: updating UI with '\(result)'")
                append("[3] Main-Queue Hop: complete ✓")
            }
        }

        append("[0] Main-Queue Hop: background work dispatched")
    }

    // MARK: - Utility
    private func threadName() -> String {
        // Thread.current.name is empty for GCD-managed threads;
        // use the description to grab the internal thread number.
        let desc = "\(Thread.current)"
        if let range = desc.range(of: "number = ") {
            let after = desc[range.upperBound...]
            return String(after.prefix(while: { $0.isNumber }))
        }
        return Thread.isMainThread ? "main" : "?"
    }
}

#Preview {
    NavigationStack { GCDView() }
}
