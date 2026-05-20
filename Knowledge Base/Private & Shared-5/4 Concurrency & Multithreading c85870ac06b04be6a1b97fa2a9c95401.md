# 4. Concurrency & Multithreading

### 4.1. Concept of multithreading vs concurrency vs parallelism

**Asynchrony** — execution of a task in a non-blocking mode. When a task is dispatched from one thread to another, the calling thread is not suspended and continues its own execution. In general terms: asynchrony means a program thread can keep processing without waiting for a system call to complete.

---

**Concurrency** — implies multithreading within a queue. A concurrent queue is backed by a pool of system-provided threads across which the queued tasks are distributed and executed.

---

**Parallelism** — occurs when asynchronous tasks are distributed across threads running on **different CPU cores** simultaneously.

Main - is serial queue, it has one main thread. Concurrent queues has multiple threads.

---

| **Concept** | **Key idea** |
| --- | --- |
| **Asynchrony** | Non-blocking dispatch; caller doesn't wait |
| **Concurrency** | Multiple tasks in progress, managed across a thread pool |
| **Parallelism** | Multiple tasks executing *simultaneously* on multiple cores |
| **Multithreading** | Multiple threads exist; parallel *or* time-sliced depending on hardware |

### 4.2. Why multithreading? purpose?

**Purpose of multithreading:**

To keep the app responsive by offloading heavy or slow tasks (network, I/O, computation) to background threads, so the **main thread is never blocked**.

***Multithreading is possible even on a single-core processor — queues and threads exist, async tasks are dispatched — but the CPU simply time-slices between them, executing each a little at a time. True parallelism requires multiple cores.***

### 4.3. iOS multithreading options

notes: 

1. **GCD** (Grand Central Dispatch) — low-level C-based API, queues  - closures(blocks), can’t cancel (workaround inside closure check isCancelled)
2. **OperationQueue** — higher-level, built on top of GCD, uses **`Operation`** objects (custom class), use or custom operations or use same block. main/start (until call [self.is](http://self.is)Finished)
    1. maxConcurrentOperationCount (how much tasks in parallel) ==1 means serial as 1 at a time
    2. main profit is DEPENDENCY between tasks //TODO: UIView
    3. read about Promises as NSOperation-based. Future and do example Combine
3. **Thread** (**`NSThread`**) — manual thread management, low-level //timer
4. **async/await** (Swift Concurrency) — modern Swift-native solution 
    1. //TODO: task.detached
    2. AsyncStream
    3. withContinuation
    4. Task{} is asynchronous by default - Task {} inherits the actor context it's created from, but it runs asynchronously (the caller doesn't wait for it).
5. **Actors** — Swift Concurrency, thread-safe reference type
6. **Combine** — reactive framework, supports async data streams
7. **Pthread** — POSIX threads, C-level, rarely used in iOS directly

### 4.4. Grand Central Dispatch

#### 4.4.1. QualityOfService

let defaultQueue = DispatchQueue.global() // by default

**QoS Priority Order (highest → lowest)**

| **QoS** | **Use Case** |
| --- | --- |
| `.userInteractive` | Animations, UI updates |
| `.userInitiated` | User-triggered, needs quick result |
| `.default` | General work |
| `.utility` | Long tasks with progress (downloads) |
| `.background` | Invisible work, backups, prefetching |
| `.unspecified` | Legacy, system infers |

#### 4.4.2. How to make task 3 waiting completes tasks 1 and 2?

let group = DispatchGroup()
let concurrentQueue = DispatchQueue(label: "com.app.batch", attributes: .concurrent)

```swift
// --- Batch 1 ---
group.enter()
concurrentQueue.async {
print("📦 Task 1.1 — downloading image")
Thread.sleep(forTimeInterval: 2)
print("✅ Task 1.1 done")
group.leave()
}
```

```swift
group.enter()
concurrentQueue.async {
print("📦 Task 1.2 — downloading JSON")
Thread.sleep(forTimeInterval: 1)
print("✅ Task 1.2 done")
group.leave()
}
```

// When ALL tasks in Batch 1 are done → start Batch 2
group.notify(queue: .main) {
print("\n🚀 Batch 1 complete! Starting Batch 2...\n")

```swift
let group2 = DispatchGroup()

group2.enter()
concurrentQueue.async {
    print("📦 Task 2.1 — processing data")
    Thread.sleep(forTimeInterval: 1)
    print("✅ Task 2.1 done")
    group2.leave()
}

group2.notify(queue: .main) {
    print("\\n🎉 All batches finished!")
}
}
```

HOW TO OD IT WITHOUT DISPATCH GROUP?

1. Not optimal

```swift
let serialQueue = DispatchQueue(label: "com.app.serial")
```

```swift
// Off the main queue
serialQueue.async {
print("Task 1") // runs first
}
serialQueue.async {
print("Task 2") // runs second
}
serialQueue.async {
print("Task 3") // runs AFTER 1 & 2 ✅
}
```

✅ Works, BUT...
Task 1 and Task 2 run sequentially, not in parallel
You lose concurrency — Task 2 waits for Task 1 even though they're independent
Task 3 will indeed run last — but at the cost of performance

1. Optimal

```swift
let concurrentQueue = DispatchQueue(label: "com.app.concurrent", attributes: .concurrent)
```

```swift
concurrentQueue.async {
print("📦 Task 1")
Thread.sleep(forTimeInterval: 2)
print("✅ Task 1 done")
}
```

```swift
concurrentQueue.async {
print("📦 Task 2")
Thread.sleep(forTimeInterval: 1)
print("✅ Task 2 done")
}
```

```swift
// Barrier waits for ALL previous async tasks, then runs exclusively
concurrentQueue.async(flags: .barrier) {
print("🚀 Task 3 — runs AFTER 1 & 2 are both done")
}
```

### 4.5. OperationQueue

#### 4.5.1. Example:

```swift
import Foundation

// MARK: - Custom Operation
class ImageDownloadOperation: Operation {
    
    private let url: URL
    var downloadedData: Data?
    
    init(url: URL) {
        self.url = url
    }
    
    override func main() {
        // Check if cancelled before starting
        guard !isCancelled else { return }
        
        print("Downloading: \(url.lastPathComponent)")
        
        // Simulate download
        downloadedData = try? Data(contentsOf: url)
        
        guard !isCancelled else {
            downloadedData = nil
            return
        }
        
        print("Finished: \(url.lastPathComponent)")
    }
}

// MARK: - Usage
class ImageLoader {
    
    // Configure the queue
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.app.imageLoader"
        queue.maxConcurrentOperationCount = 3   // Max parallel operations
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    func loadImages() {
        let urls = [
            URL(string: "https://example.com/image1.png")!,
            URL(string: "https://example.com/image2.png")!,
            URL(string: "https://example.com/image3.png")!,
            URL(string: "https://example.com/image4.png")!,
        ]
        
        // MARK: - Block Operation (simpler use case)
        let logOperation = BlockOperation {
            print("Starting image downloads...")
        }
        
        // MARK: - Creating operations with dependencies
        var downloadOps: [ImageDownloadOperation] = []
        
        for url in urls {
            let downloadOp = ImageDownloadOperation(url: url)
            
            // Add dependency - logOperation runs first
            downloadOp.addDependency(logOperation)
            
            // Completion block per operation
            downloadOp.completionBlock = {
                if let data = downloadOp.downloadedData {
                    print("✅ Got \(data.count) bytes from \(url.lastPathComponent)")
                } else {
                    print("❌ Failed or cancelled: \(url.lastPathComponent)")
                }
            }
            
            downloadOps.append(downloadOp)
        }
        
        // MARK: - Combine operation (runs after all downloads)
        let combineOperation = BlockOperation {
            print("All downloads finished, processing images...")
        }
        
        // combineOperation depends on all downloads
        downloadOps.forEach { combineOperation.addDependency($0) }
        
        // MARK: - Add all to queue
        operationQueue.addOperation(logOperation)
        operationQueue.addOperations(downloadOps, waitUntilFinished: false)
        operationQueue.addOperation(combineOperation)
    }
    
    // MARK: - Control operations
    func pauseQueue() {
        operationQueue.isSuspended = true
        print("Queue paused, pending ops: \(operationQueue.operationCount)")
    }
    
    func resumeQueue() {
        operationQueue.isSuspended = false
    }
    
    func cancelAll() {
        operationQueue.cancelAllOperations()
    }
}

// MARK: - Run
let loader = ImageLoader()
loader.loadImages()
```

Benefits:

| **Benefit** | **Description** |
| --- | --- |
| **Dependencies** | Easily chain operations in order |
| **Cancellation** | Cancel individual ops or the whole queue |
| **Reusability** | Encapsulate logic in subclasses |
| **Suspension** | Pause/resume the entire queue |
| **Max concurrency** | Fine-grained thread control |
| **State tracking** | Built-in **`isReady`**, **`isExecuting`**, **`isFinished`** states |
| **KVO support** | Observe operation state changes |

Cons:

| **Con** | **Description** |
| --- | --- |
| **Verbose** | More boilerplate vs GCD or async/await |
| **Complexity** | Harder to debug dependency chains |
| **Overhead** | Heavier than GCD for simple tasks |
| **Legacy feel** | Swift concurrency (**`async/await`**) is now preferred |
| **No return values** | Must use callbacks or shared state for results |

**When to Use**

```
✅ Complex task dependencies✅ Need to cancel specific tasks (e.g., cancel off-screen image loads)
✅ Limiting concurrent network requests
❌ Simple async tasks → use async/await
❌ One-off background work → use GCD
```

#### 4.3.2. Operation

notes: 

#### 4.3.3. BlockOperation

**`BlockOperation`** is a **concrete subclass of `Operation`** that manages concurrent execution of one or more blocks. It's a lightweight way to use **`OperationQueue`** **without subclassing** **`Operation`**.

```swift
// MARK: - Single Block
let operation = BlockOperation {
    print("Hello from BlockOperation")
}

operation.completionBlock = {
    print("Done!")
}

let queue = OperationQueue()
queue.addOperation(operation)
```

### Operation states

notes: 

### Operation queues with dependencies

```swift
// Most common real-world use case
let queue = OperationQueue()

let fetchOp = BlockOperation {
    print("1. Fetching data...")
}

let processOp = BlockOperation {
    print("2. Processing data...")
}

let saveOp = BlockOperation {
    print("3. Saving data...")
}

// Chain them
processOp.addDependency(fetchOp)
saveOp.addDependency(processOp)

queue.addOperations([fetchOp, processOp, saveOp], waitUntilFinished: false)

// Output always in order:
// 1. Fetching data...
// 2. Processing data...
// 3. Saving data...
```

// TODO: operation.priority  -FI in queue. waitUntilFinished - in place where it called before next line

### Canceling operations

notes: 

### Operation dependencies

// dismiss completion on top view controller presented

notes: 

### Asynchronous operations

notes: 

### GCD vs Operation

notes: 

## Thread safe array

```swift
import Foundation

final class ThreadSafeArray<T> {
    
    private var array: [T] = []
    private let queue = DispatchQueue(label: "com.threadsafe.array", attributes: .concurrent)
    
    // MARK: - Read
    var all: [T] {
        queue.sync {
            return array
        }
    }
    
    var count: Int {
        queue.sync {
            return array.count
        }
    }
    
    subscript(index: Int) -> T? {
        queue.sync {
            guard index >= 0, index < array.count else { return nil }
            return array[index]
        }
    }
    
    // MARK: - Write
    func append(_ element: T) {
        queue.async(flags: .barrier) {
            self.array.append(element)
        }
    }
    
    func remove(at index: Int) {
        queue.async(flags: .barrier) {
            guard index >= 0, index < self.array.count else { return }
            self.array.remove(at: index)
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.array.removeAll()
        }
    }
}
```

Example of usage:

```swift
import UIKit

// MARK: - Model
struct User {
    let id: Int
    let name: String
}

// MARK: - ViewController
class UsersViewController: UIViewController {
    
    // Thread-Safe Array
    private let users = ThreadSafeArray<User>()
    
    // UI Elements
    private let tableView = UITableView()
    private let fetchButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup UI
    private func setupUI() {...}
       
    
    // MARK: - Fetch Action
    @objc private func fetchButtonTapped() {
        fetchUsers()
    }
    
    private func fetchUsers() {
        // Clear existing data
        users.removeAll()
        
        activityIndicator.startAnimating()
        fetchButton.isEnabled = false
        statusLabel.text = "Fetching..."
        
        let group = DispatchGroup()
        
        // Simulate multiple concurrent API calls
        let mockDataBatches: [[User]] = [
            [User(id: 1, name: "Alice"), User(id: 2, name: "Bob")],
            [User(id: 3, name: "Charlie"), User(id: 4, name: "David")],
            [User(id: 5, name: "Eve"), User(id: 6, name: "Frank")]
        ]
        
        for batch in mockDataBatches {
            group.enter()
            
            // Simulate concurrent background fetching
            DispatchQueue.global(qos: .userInitiated).async {
                // Simulate network delay
                Thread.sleep(forTimeInterval: Double.random(in: 0.5...1.5))
                
                for user in batch {
                    self.users.append(user) // ✅ Thread-Safe write
                }
                
                group.leave()
            }
        }
        
        // All batches completed
        group.notify(queue: .main) {
            self.activityIndicator.stopAnimating()
            self.fetchButton.isEnabled = true
            self.statusLabel.text = "Loaded \(self.users.count) users" // ✅ Thread-Safe read
            self.tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource
extension UsersViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count // ✅ Thread-Safe read
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        if let user = users[indexPath.row] { // ✅ Thread-Safe subscript
            cell.textLabel?.text = "\(user.id). \(user.name)"
        }
        
        return cell
    }
}
```

### Synchronous vs Asynchronous

notes: 

### Managing tasks

notes: 

### Concurrency in Core Data

notes: 

### Locks, Mutexes

notes: 

### Dispatch queues

notes:  +asyncAfter

### DispatchGroup

notes: 

### Synchronous waiting

notes: 

### Wrapping async methods

notes: // with continuation

### Barrier

notes: 

### Semaphores

notes: 

### Canceling dispatch blocks

notes: 

### Concurrency looping

notes: 

### Swift 5.5 async/await

notes: TODO: + **Task.yield()**

### How to choose threading API (OperationQueue vs GCD)

notes: 

### Common concurrency problems

**Priority inversion** - A high-priority task blocked by a low-priority task holding a lock. Use `Task.withTaskGroup` or `async/await` instead of raw locks where possible.

**Race condition** - Example: one array i read and write same time from different threads

**Deadlock** - Two threads waiting on each other indefinitely — most common cause: calling `sync` on the **current** queue.

```swift
DispatchQueue.main.sync { */* called from main thread → deadlock */* }
```

If sync called on UI, main thread will freeze, that is critical issue for user

## Actor re-entrance

### Structured concurrency

// TODO: 3 types of issues . livelock, deadlock, race condition, priority inversion

//atomic properties how works

// how you will concatenate 1000 chunks to 1 file - dispatch_apply (it separates on threads —80 — to async invocation)

// one task depends on second one - how to do in GCD

// no cancel by default in GCD. how to do manually. Switch to Operation Queue (difference - we switch to subclass from NSOperation - its object insted of closures in GCD

// Semaphores - example  on app extensions that is starts in background. lock the file to read

// Apple's ready-to-use global queues — no setup needed

DispatchQueue.global(qos: .userInteractive).async {
// 🔴 Highest priority
// UI updates, animations, anything user sees RIGHT NOW
print("userInteractive — runs first")
}

DispatchQueue.global(qos: .userInitiated).async {
// 🟠 High priority
// User tapped a button and waits for result (e.g. loading a document)
print("userInitiated")
}

DispatchQueue.global(qos: .default).async {
// 🟡 Medium priority
// General tasks without explicit QoS
print("default")
}

DispatchQueue.global(qos: .utility).async {
// 🔵 Low priority
// Long-running tasks: downloads, imports, calculations
print("utility")
}

DispatchQueue.global(qos: .background).async {
// ⚫️ Lowest priority
// User doesn't know it's happening: prefetch, sync, cleanup
print("background — runs last")
}

# Sendable & swift6

#### 11.1. What is Sendable and why does it exist?

Sendable is a marker protocol that declares a type is safe to pass across concurrency boundaries (between actors, tasks, threads). Swift 6 makes this a hard compiler error — not a warning — when you cross isolation boundaries with non-Sendable types.

// Value types are Sendable by default if all stored properties are Sendable

```swift

struct User: Sendable {
let id: Int       // ✅ Int is Sendable
let name: String  // ✅ String is Sendable
}
```

---

#### 11.2. Sendable vs Codable — when to use each?

![image.png](4%20Concurrency%20&%20Multithreading/image.png)

A type can (and often should) be both.

---

#### 11.3. How does Swift 6 enforce Sendable? Implicit vs explicit conformance

Implicit — structs/enums where all stored properties are Sendable get it automatically.
Tuples of Sendable types are Sendable.

Explicit required for:

- Classes (must be final + all properties immutable or Sendable)
- Types crossing module boundaries
- Generic types — the compiler checks at instantiation

```swift
// Swift 6 — compiler ERROR, not warning
actor Counter {
var count = 0
}
class Box { var value = 0 }  // Not Sendable
```

```swift
Task {
let box = Box()
await counter.set(box)   // ❌ 'Box' is not Sendable
}
```

---

#### 11.4. Making classes Sendable — the challenge

Classes are reference types — shared mutable state is the problem.

```swift
// ✅ Option 1: final + only immutable/Sendable properties
final class ImmutableConfig: Sendable {
let timeout: Int
init(timeout: Int) { self.timeout = timeout }
}
```

```swift
// ✅ Option 2: internal synchronization + @unchecked Sendable
final class SafeCache: @unchecked Sendable {
private let lock = NSLock()
private var store: [String: Any] = [:]
```

```swift
  func set(_ key: String, _ value: Any) {
      lock.withLock { store[key] = value }
  }
  }
```

@unchecked Sendable — you manually guarantee thread safety; the compiler trusts you. Use only when you own the synchronization (locks, queues). Treat it like unsafe — last resort.

---

#### 11.5. Sendable + Actor isolation + Structured Concurrency

Actors are implicitly Sendable. Anything you pass into or out of an actor must be Sendable.

```swift
actor DataStore {
func save(_ user: User) { ... }   // User must be Sendable
}
```

```swift
// Structured concurrency — child tasks inherit isolation
// but crossing actor boundaries requires Sendable
Task.detached {
let result: NonSendableType = ...  // ❌ can't capture across isolation
}
```

Key rules:

- @MainActor types are isolated — passing them off-main requires Sendable
- Closures capturing non-Sendable values are themselves non-Sendable
- async functions on actors enforce Sendable at call sites

---

#### 11.6. Property wrappers, closures, and generics

Closures — a closure that captures non-Sendable values cannot be @Sendable:

```swift
let mutableObj = NSMutableArray()
let closure: @Sendable () -> Void = {
mutableObj.add(1)  // ❌ captures non-Sendable NSMutableArray
}
```

Generics — propagate Sendable constraints explicitly:

```swift
func process<T: Sendable>(_ value: T) async { ... }
```

```swift
// Protocol with Sendable
protocol Repository: Sendable {
associatedtype Entity: Sendable
}
```

---

#### 11.7. Real-world bug Sendable prevents

Classic race condition — two threads mutate shared state:

```swift
// Pre-Swift 6 — compiles, crashes at runtime
class UserSession {
var token: String = ""
}
let session = UserSession()
Task { session.token = "abc" }   // Thread 1
Task { session.token = "xyz" }   // Thread 2 — data race 💥
```

// Swift 6 — compiler catches it at build time
// 'UserSession' is not Sendable — error before you ship

---

1. Debugging Sendable errors in a large codebase
2. Enable gradually — use @preconcurrency import for legacy modules
3. Read the full error chain — Swift shows the exact crossing point
4. Audit shared mutable state — convert to actors or value types
5. Use @unchecked Sendable as a temporary shim with a TODO — don't leave it permanent
6. Performance — Sendable is zero-cost at runtime; it's purely compile-time. The trade-off
is API strictness, not speed.
- 

#### 11.8. Does Sendable applicable to UIKit?

⏺ Sendable in UIKit

UIKit is largely non-Sendable — and intentionally so. All UIKit classes (UIView,
UIViewController, UILabel, etc.) must be used on the main thread only.

---

Why UIKit isn't Sendable

UIKit predates Swift concurrency. Its objects are:

- Reference types (classes)
- Mutably stateful
- Not thread-safe internally

So they cannot conform to Sendable — passing them across concurrency boundaries is undefined
behavior.

---

How Swift 6 handles this

UIKit classes are annotated @MainActor — not Sendable:

```swift
// Conceptually what UIKit does internally:
@MainActor
class UIView { ... }   // isolated, NOT Sendable
```

This means:

- You can only access UIKit objects from @MainActor context
- You cannot pass a UIView into a Task.detached or background actor
- The compiler enforces this in Swift 6

```swift
let label = UILabel()
```

```swift
Task.detached {
label.text = "hello"  // ❌ Main actor-isolated, can't access from here
}
```

```swift
Task { @MainActor in
label.text = "hello"  // ✅ correct
}
```

---

The pattern for UIKit + async work

Fetch data off main, update UI on main:

```swift
func loadUser() {
Task {
let user = await apiService.fetchUser()  // off main ok
await MainActor.run {
nameLabel.text = [user.name](http://user.name/)           // ✅ back on main
}
}
}
```

---

![image.png](4%20Concurrency%20&%20Multithreading/image%201.png)

@MainActor is UIKit's answer to thread safety — it replaces the need for Sendable by simply
forbidding off-main access entirely.

---

---

---

гаолочки мейн тред чекер, тред санитайзер

---

потокобезопасный массив - запись асинк с барьером, чтение синк (локи, DispatchSemaphore)

---

---

семафор принимает начальное знаечние счётчика. потом вызов ф-ции вейт, проверка сколько потоков ещё обращаются, ожидание до записи в масив, вызов ф-ции сигнал

---

// TODO: what is queue? like manager of tasks, not a thread , even serial queue can send in other threads, FIFO anyway. GCD decides what thread

---

---

---