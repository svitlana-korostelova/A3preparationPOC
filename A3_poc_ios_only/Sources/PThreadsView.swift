import SwiftUI
import Darwin   // pthread_t, pthread_mutex_t, pthread_attr_t …

// ════════════════════════════════════════════════════════════════════════════
// POSIX Threads (pthreads) Demo
//
// pthreads are the lowest-level threading primitive on UNIX/Darwin.
// GCD, OperationQueue, and Swift concurrency all build on top of them.
// You rarely use pthreads directly in app code, but understanding them
// clarifies what the higher-level APIs do under the hood.
//
// Key functions:
//   pthread_create   – spawn a thread
//   pthread_join     – block caller until thread exits and collect exit value
//   pthread_detach   – let thread clean itself up (no join needed)
//   pthread_mutex_*  – POSIX mutual-exclusion lock
//   pthread_cond_*   – condition variable (sleep/wake on condition)
//
// ────────────────────────────────────────────────────────────────────────────
// UIKit Bridge (SwiftUI ↔ UIKit)
//
// Because pthreads are C-level, bridging them through UIKit is a natural
// teaching moment. Below you'll see:
//
//   struct PThreadLogViewController : UIViewControllerRepresentable
//
// This is the standard way to embed any UIViewController into a SwiftUI
// hierarchy. The Coordinator acts as the UIKit delegate bridge.
// ════════════════════════════════════════════════════════════════════════════

struct PThreadsView: View {

    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("Create/Join",    color: .blue)   { runCreateJoin() }
                    demoButton("Mutex",          color: .purple) { runMutex() }
                    demoButton("Detach",         color: .orange) { runDetach() }
                    demoButton("UIKit Bridge",   color: .teal)   { runUIKitBridge() }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()

            // ── Log rendered via UIKit UITableViewController (UIKit Bridge demo) ──
            // Wrap the UIKit view controller so it lives inside our SwiftUI body.
            // This is the idiomatic pattern when you need UIKit inside SwiftUI.
            PThreadLogView(log: log)
        }
        .navigationTitle("pthreads")
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

    private func append(_ line: String) {
        DispatchQueue.main.async { log.append(line) }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 1 – pthread_create + pthread_join
    //
    // pthread_create spawns a new OS thread. pthread_join blocks the CALLER
    // until the spawned thread has finished and optionally captures its return.
    // ════════════════════════════════════════════════════════════════════════
    private func runCreateJoin() {
        log.append("── pthread_create / pthread_join ──")

        // Run the blocking pthread_join on a background GCD thread so we
        // don't freeze the main thread (which owns the UI).
        DispatchQueue.global(qos: .userInitiated).async {

            // 1. pthread_t is the thread handle.
            var thread: pthread_t?

            // 2. Context must outlive the thread. We use a heap-allocated box.
            let ctx = PThreadContext(id: 1, logger: self.append)
            let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()   // +1 retain

            append("[1] pthread_create: spawning thread…")

            // 3. pthread_create(handle, attrs, start_routine, arg)
            //    The start_routine MUST be a C function pointer (or @convention(c) closure).
            let rc = pthread_create(&thread, nil, { ptr -> UnsafeMutableRawPointer? in
                // ── This closure runs on the NEW thread ──────────────────
                // 4. Recover the Swift object from the opaque pointer.
                //    ptr is non-optional UnsafeMutableRawPointer on Darwin.
                let ctx = Unmanaged<PThreadContext>.fromOpaque(ptr).takeRetainedValue()
                ctx.logger("[2] pthread: running on new thread (id=\(ctx.id))")
                Thread.sleep(forTimeInterval: 0.3)
                ctx.logger("[3] pthread: work done, returning from thread")
                return nil   // return value captured by pthread_join
            }, ctxPtr)

            guard rc == 0 else {
                append("[!] pthread_create failed: \(rc)")
                return
            }

            // 5. pthread_join: blocks the current GCD thread until 'thread' exits.
            //    Pass nil if you don't need the thread's return value.
            append("[4] pthread_join: calling join – blocking GCD thread")
            pthread_join(thread!, nil)
            append("[5] pthread_join returned – thread finished ✓")
        }

        append("[0] Create/Join: GCD thread dispatched (will create pthread)")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 2 – pthread_mutex (POSIX mutual exclusion)
    //
    // POSIX mutex is the C-level lock that NSLock and os_unfair_lock wrap.
    // Must be init'd before use and destroyed afterwards to avoid leaks.
    // ════════════════════════════════════════════════════════════════════════
    private func runMutex() {
        log.append("── pthread_mutex ──")

        DispatchQueue.global(qos: .userInitiated).async {

            // 1. Allocate the mutex on the heap (stable address required).
            let mutexPtr = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
            mutexPtr.initialize(to: pthread_mutex_t())

            // 2. Init with default attributes (non-recursive, normal type).
            var attr = pthread_mutexattr_t()
            pthread_mutexattr_init(&attr)
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_DEFAULT)
            pthread_mutex_init(mutexPtr, &attr)
            pthread_mutexattr_destroy(&attr)
            self.append("[1] Mutex: pthread_mutex initialised")

            var counter = 0

            // 3. Spawn 3 threads that each increment the counter 3 times.
            var threads = [pthread_t?](repeating: nil, count: 3)
            let boxedCtx = MutexContext(mutex: mutexPtr,
                                        counterPtr: &counter,
                                        logger: self.append)
            let rawCtx = Unmanaged.passRetained(boxedCtx).toOpaque()

            for i in 0..<3 {
                pthread_create(&threads[i], nil, { ptr -> UnsafeMutableRawPointer? in
                    let ctx = Unmanaged<MutexContext>.fromOpaque(ptr).takeUnretainedValue()
                    for _ in 1...3 {
                        // 4. lock – blocks if another thread holds the mutex.
                        pthread_mutex_lock(ctx.mutex)
                        ctx.counterPtr.pointee += 1
                        let val = ctx.counterPtr.pointee
                        ctx.logger("[+] Mutex: counter=\(val)")
                        // 5. unlock – next waiting thread proceeds.
                        pthread_mutex_unlock(ctx.mutex)
                    }
                    return nil
                }, rawCtx)
            }

            // 6. Join all three.
            for i in 0..<3 { pthread_join(threads[i]!, nil) }
            Unmanaged<MutexContext>.fromOpaque(rawCtx).release()   // balance retain

            // 7. Destroy and deallocate the mutex.
            pthread_mutex_destroy(mutexPtr)
            mutexPtr.deallocate()
            self.append("[2] Mutex: final counter=\(counter) (expected 9) ✓")
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 3 – pthread_detach
    //
    // A detached thread cleans up its own resources when it exits.
    // You cannot call pthread_join on a detached thread.
    // Use when you don't need the result and fire-and-forget semantics are fine.
    // ════════════════════════════════════════════════════════════════════════
    private func runDetach() {
        log.append("── pthread_detach ──")

        // 1. Build context.
        let ctx = PThreadContext(id: 99, logger: self.append)
        let rawCtx = Unmanaged.passRetained(ctx).toOpaque()

        var thread: pthread_t?

        // 2. Create the thread.
        pthread_create(&thread, nil, { ptr -> UnsafeMutableRawPointer? in
            let ctx = Unmanaged<PThreadContext>.fromOpaque(ptr).takeRetainedValue()
            ctx.logger("[1] Detached: thread started (id=\(ctx.id))")
            Thread.sleep(forTimeInterval: 0.25)
            ctx.logger("[2] Detached: thread exiting, self-cleaning ✓")
            return nil
        }, rawCtx)

        // 3. Detach immediately after creation – no need to join later.
        pthread_detach(thread!)
        append("[0] Detach: thread created and detached – caller continues freely")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 4 – UIKit Bridge explanation
    //
    // Tapping this button scrolls the SwiftUI log (which IS the UIKit bridge)
    // and prints an explanation of how the embedding works.
    // ════════════════════════════════════════════════════════════════════════
    private func runUIKitBridge() {
        log.append("── UIKit Bridge (UIViewControllerRepresentable) ──")
        append("[1] The log list below IS a UITableViewController embedded in SwiftUI.")
        append("[2] PThreadLogView : UIViewControllerRepresentable wraps it.")
        append("[3] makeUIViewController() is called ONCE to create the VC.")
        append("[4] updateUIViewController() is called when SwiftUI state changes.")
        append("[5] Coordinator acts as UITableViewDataSource & Delegate bridge.")
        append("[6] @Binding or explicit update call passes new data from SwiftUI → UIKit.")
        append("[7] To go the other way (UIKit → SwiftUI) use the Coordinator/callback.")
        append("[8] UIKit Bridge demo complete ✓")
    }
}

// ════════════════════════════════════════════════════════════════════════════
// UIKit Bridge: PThreadLogView
//
// Embeds a UITableViewController into SwiftUI.
//
// Pattern:
//   struct MyView: UIViewControllerRepresentable {
//       // 1. makeUIViewController  – creates the UIKit VC once
//       // 2. updateUIViewController – called every SwiftUI rerender
//       // 3. Coordinator           – bridges delegates/callbacks
//   }
// ════════════════════════════════════════════════════════════════════════════

// [SYNC NOTE] UIViewControllerRepresentable requires the struct to be on the
// MainActor since it interacts with UIKit, which is main-thread-only.
@MainActor
struct PThreadLogView: UIViewControllerRepresentable {

    // 1. SwiftUI passes updated data via this property.
    let log: [String]

    // 2. Create the UIKit VC. Called ONCE by SwiftUI when first rendered.
    func makeUIViewController(context: Context) -> LogTableViewController {
        let vc = LogTableViewController()
        // Wire the coordinator so the VC can send events back (not needed here
        // but shown for completeness – this is the standard pattern).
        vc.coordinator = context.coordinator
        return vc
    }

    // 3. Called every time SwiftUI state causes a re-render.
    //    Push new data into the UIKit VC here.
    func updateUIViewController(_ vc: LogTableViewController, context: Context) {
        vc.update(with: log)
    }

    // 4. Coordinator bridges UIKit delegate/datasource calls back to SwiftUI.
    func makeCoordinator() -> Coordinator { Coordinator() }

    // ── Coordinator ──────────────────────────────────────────────────────
    // [SYNC NOTE] Coordinator is a class (reference type) owned by SwiftUI.
    // It can conform to UIKit protocols without being a struct.
    final class Coordinator: NSObject {
        // Add UITableViewDelegate / UITableViewDataSource conformance here
        // when you need to forward UIKit events back to SwiftUI state.
    }
}

// ════════════════════════════════════════════════════════════════════════════
// LogTableViewController – a plain UITableViewController
//
// This is a normal UIKit view controller. SwiftUI doesn't know or care about
// its internals; it just calls makeUIViewController / updateUIViewController.
// ════════════════════════════════════════════════════════════════════════════
final class LogTableViewController: UITableViewController {

    var coordinator: PThreadLogView.Coordinator?
    private var rows: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // Register a basic cell style – no XIB needed for plain text.
        tableView.register(UITableViewCell.self,
                           forCellReuseIdentifier: "cell")
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.backgroundColor = .systemBackground
    }

    /// Called by updateUIViewController whenever the log array changes.
    func update(with newRows: [String]) {
        rows = newRows
        tableView.reloadData()
        // Auto-scroll to the last row.
        if !rows.isEmpty {
            let last = IndexPath(row: rows.count - 1, section: 0)
            tableView.scrollToRow(at: last, at: .bottom, animated: true)
        }
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView,
                             numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView,
                             cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell",
                                                  for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        cfg.text = rows[indexPath.row]
        cfg.textProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cfg.textProperties.numberOfLines = 0
        cell.contentConfiguration = cfg
        return cell
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Helper context objects (heap-allocated so pthread closures can reference them)
// ════════════════════════════════════════════════════════════════════════════

final class PThreadContext {
    let id: Int
    let logger: (String) -> Void
    init(id: Int, logger: @escaping (String) -> Void) {
        self.id = id
        self.logger = logger
    }
}

final class MutexContext {
    let mutex: UnsafeMutablePointer<pthread_mutex_t>
    let counterPtr: UnsafeMutablePointer<Int>
    let logger: (String) -> Void
    init(mutex: UnsafeMutablePointer<pthread_mutex_t>,
         counterPtr: UnsafeMutablePointer<Int>,
         logger: @escaping (String) -> Void) {
        self.mutex = mutex
        self.counterPtr = counterPtr
        self.logger = logger
    }
}

#Preview {
    NavigationStack { PThreadsView() }
}
