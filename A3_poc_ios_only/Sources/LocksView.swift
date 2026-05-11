import SwiftUI
import os.lock          // os_unfair_lock

// ════════════════════════════════════════════════════════════════════════════
// Locks Demo
//
// A "lock" serialises access to a shared resource by letting only one thread
// hold the lock at a time. Others block (spin or sleep) until the lock is free.
//
// Primitives covered:
//   1. NSLock            – object-oriented, fair, ObjC-compatible
//   2. NSRecursiveLock   – same thread may lock multiple times without deadlock
//   3. os_unfair_lock    – ultra-fast C-level lock (use in tight loops)
//   4. Serial GCD queue  – conceptually a lock; dispatch_sync is the critical section
//   5. @Sendable / actor – covered in the Structured Concurrency scene
// ════════════════════════════════════════════════════════════════════════════

// Shared mutable state used across demos
private var bankBalance: Int = 1_000

struct LocksView: View {

    @State private var log: [String] = []

    // Each lock type is kept as a stored property so multiple taps don't
    // interfere. We wrap os_unfair_lock in a class for stable pointer semantics.
    private let nsLock          = NSLock()
    private let recursiveLock   = NSRecursiveLock()
    private let unfairLockBox   = UnfairLockBox()
    private let serialQueue     = DispatchQueue(label: "com.poc.lock.serial")

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("NSLock",          color: .blue)   { runNSLock() }
                    demoButton("RecursiveLock",   color: .purple) { runRecursiveLock() }
                    demoButton("os_unfair_lock",  color: .orange) { runUnfairLock() }
                    demoButton("Serial Queue",    color: .green)  { runSerialQueueLock() }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()
            logView
        }
        .navigationTitle("Locks")
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
    // DEMO 1 – NSLock
    //
    // Simple mutual-exclusion lock. lock() BLOCKS until the lock is free.
    // Calling lock() twice from the SAME thread → deadlock (use NSRecursiveLock).
    // ════════════════════════════════════════════════════════════════════════
    private func runNSLock() {
        log.append("── NSLock ──")
        bankBalance = 1_000

        let queue = DispatchQueue(label: "com.poc.nslock", attributes: .concurrent)

        for i in 1...4 {
            queue.async {
                // 1. Attempt to acquire the lock; blocks if another thread holds it.
                nsLock.lock()
                append("[\(i)a] NSLock: thread \(i) locked – balance=\(bankBalance)")

                // ── Critical section ──────────────────────────────────────
                bankBalance -= 100
                Thread.sleep(forTimeInterval: 0.1)
                let bal = bankBalance
                // ── End critical section ──────────────────────────────────

                // 2. Release the lock so the next waiting thread can proceed.
                nsLock.unlock()
                append("[\(i)b] NSLock: thread \(i) unlocked – balance=\(bal)")
            }
        }

        append("[0] NSLock: 4 withdraw tasks dispatched")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 2 – NSRecursiveLock
    //
    // Allows the SAME thread to call lock() multiple times without deadlocking.
    // Useful in recursive algorithms or when a locked method calls another
    // locked method on the same object.
    // ════════════════════════════════════════════════════════════════════════
    private func runRecursiveLock() {
        log.append("── NSRecursiveLock ──")
        var count = 0

        // 1. The helper is called recursively, acquiring the lock each time.
        func recursiveIncrement(depth: Int) {
            guard depth > 0 else { return }

            // 2. lock() succeeds even though the SAME thread already holds it.
            recursiveLock.lock()
            count += 1
            append("[\(5 - depth)] RecursiveLock: depth=\(depth), count=\(count)")

            // 3. Recursive call – NSLock would deadlock here!
            recursiveIncrement(depth: depth - 1)

            // 4. Each unlock() reduces the recursion depth.
            recursiveLock.unlock()
            append("[\(10 - depth)] RecursiveLock: unlock at depth=\(depth)")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            append("[1] RecursiveLock: starting recursion")
            recursiveIncrement(depth: 4)
            self.append("[9] RecursiveLock: finished, final count=\(count)")
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 3 – os_unfair_lock
    //
    // The fastest lock on Apple platforms. It's a C struct, so it must live
    // at a STABLE memory address (heap-allocated, never on the stack).
    // Not fair: high-priority threads may preempt others.
    // ════════════════════════════════════════════════════════════════════════
    private func runUnfairLock() {
        log.append("── os_unfair_lock ──")
        var sharedValue = 0
        let queue = DispatchQueue(label: "com.poc.unfair", attributes: .concurrent)

        for i in 1...5 {
            queue.async {
                // 1. Acquire. Internally uses a very fast futex-like mechanism.
                unfairLockBox.lock()
                append("[\(i)a] UnfairLock: thread \(i) in – value=\(sharedValue)")

                // ── Critical section ──────────────────────────────────────
                sharedValue += i
                Thread.sleep(forTimeInterval: 0.05)
                let v = sharedValue
                // ── End critical section ──────────────────────────────────

                // 2. Release. Another thread unblocks.
                unfairLockBox.unlock()
                append("[\(i)b] UnfairLock: thread \(i) out – value=\(v)")
            }
        }

        append("[0] UnfairLock: 5 tasks dispatched")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 4 – Serial DispatchQueue as a Logical Lock
    //
    // A serial queue processes one item at a time, which is semantically
    // equivalent to a mutex. dispatch_sync acts as the critical section gate.
    //
    // Advantages: no explicit lock/unlock; automatic cleanup on throw.
    // Disadvantage: slightly more overhead than os_unfair_lock.
    // ════════════════════════════════════════════════════════════════════════
    private func runSerialQueueLock() {
        log.append("── Serial Queue as Lock ──")
        var sharedData: [Int] = []

        let writers = DispatchQueue(label: "com.poc.writers", attributes: .concurrent)

        for i in 1...5 {
            writers.async {
                // 1. sync on the SERIAL queue: this thread blocks until the
                //    serial queue has finished processing any earlier sync block.
                self.serialQueue.sync {
                    // 2. Only one thread executes this closure at a time.
                    append("[\(i)a] SerialQ: writer \(i) modifying sharedData")
                    sharedData.append(i)
                    Thread.sleep(forTimeInterval: 0.05)
                    append("[\(i)b] SerialQ: writer \(i) done, data=\(sharedData)")
                }
                // 3. sync returns, this thread continues with the next task.
            }
        }

        append("[0] SerialQ: 5 writers dispatched to concurrent queue")
    }
}

// ════════════════════════════════════════════════════════════════════════════
// UnfairLockBox
//
// os_unfair_lock is a value type (struct). If it were on the stack it could
// be copied, invalidating the pointer. By wrapping it in a class we pin it
// to a single heap address that never moves.
// ════════════════════════════════════════════════════════════════════════════
final class UnfairLockBox {
    // 1. Allocate the lock on the heap via UnsafeMutablePointer.
    private let storage: UnsafeMutablePointer<os_unfair_lock>

    init() {
        // 2. Allocate one os_unfair_lock and initialise it to OS_UNFAIR_LOCK_INIT.
        storage = .allocate(capacity: 1)
        storage.initialize(to: os_unfair_lock())
    }

    deinit {
        // 3. Always deallocate to avoid memory leaks.
        storage.deinitialize(count: 1)
        storage.deallocate()
    }

    func lock()   { os_unfair_lock_lock(storage) }
    func unlock() { os_unfair_lock_unlock(storage) }

    /// Non-blocking try: returns false if lock is already held.
    @discardableResult
    func tryLock() -> Bool { os_unfair_lock_trylock(storage) }
}

#Preview {
    NavigationStack { LocksView() }
}
