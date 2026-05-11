import SwiftUI
import Foundation

// ════════════════════════════════════════════════════════════════════════════
// OperationQueue Demo
//
// OperationQueue is an Objective-C/Swift abstraction over GCD that adds:
//   • Object-oriented, cancellable work units (Operation subclasses)
//   • Dependency chains  (op2.addDependency(op1))
//   • Max-concurrency cap (maxConcurrentOperationCount)
//   • Key-Value Observing (isFinished, isCancelled …)
//
// Demos in this scene:
//   1. BlockOperation – anonymous closure wrapped as an Operation
//   2. Custom Operation – subclass with proper isExecuting/isFinished KVO
//   3. Dependencies – ops run in declared order even if queue is concurrent
//   4. Cancellation – cancel a long-running op mid-flight
// ════════════════════════════════════════════════════════════════════════════

struct OperationQueueView: View {

    @State private var log: [String] = []
    // Hold a reference so we can cancel ops from the Cancel demo.
    @State private var cancelDemoQueue: OperationQueue?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("BlockOperation", color: .blue)   { runBlockOperation() }
                    demoButton("Custom Op",      color: .purple) { runCustomOperation() }
                    demoButton("Async Op",        color: .teal)   { runAsyncOperation() }
                    demoButton("Dependencies",   color: .orange) { runDependencies() }
                    demoButton("Cancellation",   color: .red)    { runCancellation() }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()
            logView
        }
        .navigationTitle("OperationQueue")
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
    // DEMO 1 – BlockOperation
    //
    // BlockOperation is the simplest Operation subclass. It wraps one or
    // more plain closures ("execution blocks") into a single, cancellable,
    // dependency-aware Operation without any subclassing.
    //
    // Key facts demonstrated here:
    //   a) Convenience initialiser  – wraps a single closure.
    //   b) addExecutionBlock()      – adds more closures; they run CONCURRENTLY
    //                                 inside the same BlockOperation (the op is
    //                                 not finished until ALL of them complete).
    //   c) completionBlock          – fires once, after every execution block
    //                                 finishes (or after cancellation).
    //   d) Cancellation             – BlockOperation respects isCancelled only
    //                                 for blocks not yet started; running blocks
    //                                 must check it themselves.
    //   e) Dependency               – a downstream BlockOperation can depend on
    //                                 the multi-block op; it starts only after
    //                                 the upstream op's isFinished = true.
    // ════════════════════════════════════════════════════════════════════════
    private func runBlockOperation() {
        log.append("── BlockOperation ──")

        // ── (a) Single-closure convenience initialiser ───────────────────
        // The shortest way to create a BlockOperation: pass one closure.
        let singleOp = BlockOperation {
            self.append("  [a] single-block op: running on \(Thread.current.name ?? "?")")
        }

        // ── (b) Multiple execution blocks ────────────────────────────────
        // Create a second op with THREE blocks.  The queue gives each block
        // its own thread; they overlap in time – you will see interleaved
        // log lines (A / B / C in non-deterministic order).
        let multiOp = BlockOperation()

        multiOp.addExecutionBlock {
            self.append("  [b] block-A  started")
            Thread.sleep(forTimeInterval: 0.30)
            self.append("  [b] block-A  finished")
        }
        multiOp.addExecutionBlock {
            self.append("  [b] block-B  started  (runs concurrently with A & C)")
            Thread.sleep(forTimeInterval: 0.15)
            self.append("  [b] block-B  finished")
        }
        multiOp.addExecutionBlock {
            self.append("  [b] block-C  started")
            Thread.sleep(forTimeInterval: 0.20)
            self.append("  [b] block-C  finished")
        }

        // ── (c) completionBlock ──────────────────────────────────────────
        // Called exactly once after ALL execution blocks complete.
        // It is NOT guaranteed to run on the main thread.
        multiOp.completionBlock = {
            self.append("  [c] completionBlock – all blocks done, isFinished=\(multiOp.isFinished) ✓")
        }

        // ── (d) Cancellation check inside a block ────────────────────────
        // BlockOperation sets isCancelled on all not-yet-started blocks when
        // cancel() is called, but it cannot stop a block that is already
        // running.  Long-running blocks should poll isCancelled themselves.
        let slowOp = BlockOperation()
        slowOp.addExecutionBlock {
            for tick in 1...6 {
                if slowOp.isCancelled {
                    self.append("  [d] slowOp cancelled at tick \(tick) – exiting early")
                    return
                }
                Thread.sleep(forTimeInterval: 0.1)
                self.append("  [d] slowOp tick \(tick)/6")
            }
            self.append("  [d] slowOp finished normally")
        }

        // ── (e) Dependency between BlockOperations ────────────────────────
        // summaryOp depends on multiOp: it will not start until multiOp's
        // isFinished becomes true (i.e. after all three blocks AND the
        // completionBlock have run).
        let summaryOp = BlockOperation {
            self.append("  [e] summaryOp: multiOp dependency satisfied – pipeline complete ✓")
        }
        summaryOp.addDependency(multiOp)

        // ── Enqueue everything ───────────────────────────────────────────
        let queue = OperationQueue()
        queue.name = "com.poc.blockop"
        queue.maxConcurrentOperationCount = 4   // plenty of threads for concurrent blocks

        queue.addOperation(singleOp)
        queue.addOperation(multiOp)
        queue.addOperation(slowOp)
        queue.addOperation(summaryOp)           // waits for multiOp automatically

        // Cancel slowOp after 0.25 s to trigger the isCancelled demonstration.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.append("  [d] cancelling slowOp now…")
            slowOp.cancel()
        }

        append("[0] BlockOp: 4 operations enqueued (singleOp, multiOp, slowOp, summaryOp)")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 2 – Custom Operation
    //
    // Subclassing Operation gives full control over KVO state, cancellation
    // checks, and asynchronous wrapping (not shown here – see Apple docs for
    // async Operation patterns).
    // ════════════════════════════════════════════════════════════════════════
    private func runCustomOperation() {
        log.append("── Custom Operation ──")

        // 1. Create the queue.
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3

        // 2. Instantiate our custom operation (defined below this View).
        let op = DownloadSimulatorOperation(id: 42, logger: append)

        // 3. Attach completion.
        op.completionBlock = {
            self.append("[4] CustomOp: completionBlock – isFinished=\(op.isFinished)")
        }

        // 4. Enqueue.
        queue.addOperation(op)
        append("[0] CustomOp: DownloadSimulatorOperation enqueued")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 2b – Asynchronous Operation
    //
    // An "async Operation" keeps isExecuting = true after start()/main() return.
    // The queue sees the op as still running until the op itself flips
    // isExecuting → false and isFinished → true via KVO.
    //
    // This pattern is the bridge between the old OperationQueue world and
    // modern async APIs (URLSession completion handlers, async/await, etc.).
    // ════════════════════════════════════════════════════════════════════════
    private func runAsyncOperation() {
        log.append("── Async Operation ──")

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 4

        // 1. Create the async op – it wraps a URLSession data task internally.
        let op = AsyncDownloadOperation(
            url: URL(string: "https://httpbin.org/delay/1")!,
            logger: append
        )

        // 2. completionBlock is called only after the op sets isFinished = true,
        //    which happens inside the URLSession completion handler – not when
        //    start() returns.
        op.completionBlock = {
            self.append("[5] AsyncOp: completionBlock – isFinished=\(op.isFinished) ✓")
        }

        // 3. Enqueue – the queue calls start(), but the op is still "running"
        //    after start() returns because isAsynchronous = true.
        queue.addOperation(op)
        append("[0] AsyncOp: enqueued (start() will return immediately)")
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 3 – Dependencies
    //
    // op2.addDependency(op1) guarantees op2 waits for op1 to finish,
    // regardless of how many threads are available.
    // ════════════════════════════════════════════════════════════════════════
    private func runDependencies() {
        log.append("── Dependencies ──")

        // 1. Concurrent queue – without dependencies the 3 ops could run in any order.
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 4

        // 2. Define three operations that simulate steps in a pipeline:
        //    fetch → parse → render
        let fetch  = makeLoggingOp(name: "Fetch",  step: 1, delay: 0.3)
        let parse  = makeLoggingOp(name: "Parse",  step: 2, delay: 0.2)
        let render = makeLoggingOp(name: "Render", step: 3, delay: 0.1)

        // 3. Declare the dependency chain: parse waits for fetch; render waits for parse.
        parse.addDependency(fetch)
        render.addDependency(parse)

        // 4. Add ALL at once. The queue respects the dependency graph even
        //    though render is "ready to run" by thread-pool availability.
        queue.addOperations([fetch, parse, render], waitUntilFinished: false)
        append("[0] Deps: fetch → parse → render enqueued (concurrent queue)")
    }

    private func makeLoggingOp(name: String, step: Int, delay: TimeInterval) -> BlockOperation {
        BlockOperation {
            self.append("[\(step)a] Deps: \(name) started")
            Thread.sleep(forTimeInterval: delay)
            self.append("[\(step)b] Deps: \(name) finished")
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // DEMO 4 – Cancellation
    //
    // Operation.cancel() sets isCancelled = true. The operation itself must
    // CHECK isCancelled periodically and bail out early – GCD won't forcibly
    // kill the thread.
    // ════════════════════════════════════════════════════════════════════════
    private func runCancellation() {
        log.append("── Cancellation ──")

        // 1. Fresh queue for this demo.
        let queue = OperationQueue()
        queue.name = "com.poc.cancel"
        cancelDemoQueue = queue

        // 2. A long operation that checks isCancelled each iteration.
        let longOp = CancellableOperation(logger: append)

        // 3. Enqueue the operation.
        queue.addOperation(longOp)
        append("[1] Cancel: long operation enqueued")

        // 4. After 0.35 s, cancel it while it's mid-flight.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.append("[2] Cancel: calling cancel() on the operation")
            longOp.cancel()                         // sets isCancelled = true
            // The operation sees isCancelled and exits its loop early.
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Custom Operation – DownloadSimulatorOperation
//
// Subclass adds:
//   • Named progress reporting
//   • Automatic isCancelled check
// ════════════════════════════════════════════════════════════════════════════
final class DownloadSimulatorOperation: Operation, @unchecked Sendable {

    private let id: Int
    private let logger: (String) -> Void

    init(id: Int, logger: @escaping (String) -> Void) {
        self.id = id
        self.logger = logger
    }

    // 1. main() is the entry point for synchronous operations.
    override func main() {
        // 2. Always check isCancelled at the very start.
        guard !isCancelled else {
            logger("[1] CustomOp #\(id): cancelled before starting")
            return
        }
        logger("[1] CustomOp #\(id): main() entered")

        // 3. Simulate download chunks, checking cancellation each iteration.
        for chunk in 1...3 {
            guard !isCancelled else {
                logger("[!] CustomOp #\(id): cancelled at chunk \(chunk)")
                return
            }
            Thread.sleep(forTimeInterval: 0.15)
            logger("[\(chunk+1)] CustomOp #\(id): chunk \(chunk)/3 downloaded")
        }

        // 4. All chunks done – operation finishes naturally.
        logger("[4] CustomOp #\(id): download complete")
        // When main() returns, the Operation runtime sets isFinished = true,
        // which triggers the completionBlock.
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Custom Operation – CancellableOperation
// ════════════════════════════════════════════════════════════════════════════
final class CancellableOperation: Operation, @unchecked Sendable {

    private let logger: (String) -> Void

    init(logger: @escaping (String) -> Void) {
        self.logger = logger
    }

    override func main() {
        logger("[1] CancelOp: started, will loop 10 times")

        for i in 1...10 {
            // 2. Check BEFORE each unit of work – this is the idiomatic pattern.
            if isCancelled {
                logger("[!] CancelOp: isCancelled=true detected at iteration \(i), exiting")
                return                              // early exit hands control back to queue
            }
            Thread.sleep(forTimeInterval: 0.1)
            logger("[\(i+1)] CancelOp: iteration \(i) done")
        }

        logger("[11] CancelOp: finished normally (no cancellation)")
    }
}

// ════════════════════════════════════════════════════════════════════════════
// Asynchronous Operation – AsyncDownloadOperation
//
// Key requirement for an async Operation:
//   • Override isAsynchronous → true  (tells the queue not to wait for main())
//   • Override isExecuting / isFinished  with manual KVO willChange/didChange
//   • Override start() – kick off async work, then RETURN immediately
//   • When async work completes, flip _executing=false / _finished=true via KVO
//
// The OperationQueue respects isFinished KVO: it does not remove the op from
// its internal list (or unblock dependent ops) until isFinished becomes true.
// ════════════════════════════════════════════════════════════════════════════
final class AsyncDownloadOperation: Operation, @unchecked Sendable {

    private let url: URL
    private let logger: (String) -> Void

    // URLSessionDataTask held so we can cancel it if the Operation is cancelled.
    private var task: URLSessionDataTask?

    // MARK: – Manual KVO-backed state

    // Backing storage – must NOT call super.isExecuting/isFinished setters
    // because Operation's own implementations don't fire our KVO notifications.
    private var _executing = false {
        willSet { willChangeValue(forKey: "isExecuting") }
        didSet  { didChangeValue(forKey: "isExecuting") }
    }
    private var _finished = false {
        willSet { willChangeValue(forKey: "isFinished") }
        didSet  { didChangeValue(forKey: "isFinished") }
    }

    // 1. Advertise that this is an asynchronous operation.
    override var isAsynchronous: Bool { true }
    override var isExecuting: Bool    { _executing }
    override var isFinished:  Bool    { _finished  }

    init(url: URL, logger: @escaping (String) -> Void) {
        self.url = url
        self.logger = logger
    }

    // MARK: – Lifecycle

    // 2. start() is called by the queue on a background thread.
    //    We flip _executing, launch the async work, then RETURN.
    override func start() {
        // Always check for early cancellation before doing any work.
        guard !isCancelled else {
            logger("[!] AsyncOp: cancelled before start()")
            finish()
            return
        }

        logger("[1] AsyncOp: start() called – launching URLSession data task")
        _executing = true

        // 3. Kick off async work (URLSession completion handler).
        task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }

            // 4. Check cancellation again inside the callback.
            if self.isCancelled {
                self.logger("[!] AsyncOp: cancelled during network call")
                self.finish()
                return
            }

            if let error {
                self.logger("[3] AsyncOp: error – \(error.localizedDescription)")
            } else {
                let bytes = data?.count ?? 0
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                self.logger("[3] AsyncOp: response \(status), \(bytes) bytes received")
            }

            self.logger("[4] AsyncOp: async work done, marking finished")
            // 5. Flip state – triggers KVO which unblocks the queue.
            self.finish()
        }
        task?.resume()

        // start() returns HERE – the operation is still "running" in the queue's eyes.
        logger("[2] AsyncOp: start() returning (task is in-flight, isExecuting=\(_executing))")
    }

    // 3. cancel() also cancels the underlying URLSessionDataTask.
    override func cancel() {
        super.cancel()
        task?.cancel()
        logger("[!] AsyncOp: cancel() called – URLSessionDataTask cancelled")
    }

    // MARK: – Helpers

    private func finish() {
        _executing = false
        _finished  = true
    }
}

#Preview {
    NavigationStack { OperationQueueView() }
}
