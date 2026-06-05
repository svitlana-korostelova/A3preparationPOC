import SwiftUI

// ════════════════════════════════════════════════════════════════════════════
// Dependency Injection Demo
//
// Demonstrates a lightweight DI container with three capabilities:
//   • register        – factory registration (new instance on every resolve)
//   • registerSingleton – one shared instance for the app lifetime
//   • resolve         – returns a registered service by its protocol type
//   • @Dependency     – property wrapper that auto-resolves from the container
// ════════════════════════════════════════════════════════════════════════════

// MARK: - DI Container

/// Lightweight service locator / DI container.
/// Not thread-safe by design — wrap with a lock for production use.
final class DIContainer {
    static let shared = DIContainer()
    private init() {}

    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]

    /// Registers a factory closure. Every `resolve` call produces a new instance.
    func register<T>(_ type: T.Type, _ factory: @escaping () -> T) {
        factories[key(for: type)] = factory
    }

    /// Registers a singleton. The factory is called once; every `resolve` returns the same object.
    func registerSingleton<T>(_ type: T.Type, _ factory: @escaping () -> T) {
        singletons[key(for: type)] = factory()
    }

    /// Returns the registered instance for `type`. Crashes early if nothing is registered.
    func resolve<T>(_ type: T.Type = T.self) -> T {
        let k = key(for: type)
        if let singleton = singletons[k] as? T { return singleton }
        guard let factory = factories[k], let instance = factory() as? T else {
            fatalError("DIContainer: no registration for \(T.self)")
        }
        return instance
    }

    func reset() {
        factories.removeAll()
        singletons.removeAll()
    }

    private func key<T>(for type: T.Type) -> String { String(describing: type) }
}

// MARK: - @Dependency property wrapper

/// Resolves the service type from the shared DIContainer on every access.
@propertyWrapper
struct Dependency<T> {
    var wrappedValue: T { DIContainer.shared.resolve(T.self) }
}

// MARK: - Example protocols & implementations

protocol AnalyticsService {
    var instanceId: String { get }
    func track(_ event: String) -> String
}

final class FirebaseAnalytics: AnalyticsService {
    let instanceId = "Firebase-" + UUID().uuidString.prefix(4)
    func track(_ event: String) -> String { "[\(instanceId)] tracked: \(event)" }
}

protocol DatabaseService {
    var instanceId: String { get }
    func fetch(_ query: String) -> String
}

final class SQLiteDatabase: DatabaseService {
    let instanceId = "SQLite-" + UUID().uuidString.prefix(4)
    func fetch(_ query: String) -> String { "[\(instanceId)] fetched: \(query)" }
}

// MARK: - Consumer that uses @Dependency

final class ReportViewModel {
    @Dependency var analytics: AnalyticsService
    @Dependency var database: DatabaseService

    func generateReport() -> [String] {
        [
            analytics.track("report_opened"),
            database.fetch("SELECT * FROM reports"),
            analytics.track("report_generated"),
        ]
    }
}

// MARK: - View

struct DependencyInjectionView: View {
    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("Register & Resolve", color: .blue)   { runRegisterDemo() }
                    demoButton("Singleton",          color: .purple) { runSingletonDemo() }
                    demoButton("@Dependency in VM",  color: .green)  { runPropertyWrapperDemo() }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()
            logView
        }
        .navigationTitle("Dependency Injection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") { log.removeAll() }
            }
        }
    }

    // MARK: - Demo 1 – register / resolve (factory: new instance each time)

    private func runRegisterDemo() {
        DIContainer.shared.reset()
        append("── DEMO 1: register / resolve ──────────────────")
        DIContainer.shared.register(AnalyticsService.self) { FirebaseAnalytics() }
        append("✅ AnalyticsService registered as factory")

        let a1 = DIContainer.shared.resolve(AnalyticsService.self)
        let a2 = DIContainer.shared.resolve(AnalyticsService.self)
        append(a1.track("app_launch"))
        append(a2.track("screen_view"))
        append("a1.instanceId → \(a1.instanceId)")
        append("a2.instanceId → \(a2.instanceId)")
        let same = a1.instanceId == a2.instanceId
        append(same ? "⚠️  Same instance (unexpected)" : "✅ Different instances — factory works")
    }

    // MARK: - Demo 2 – registerSingleton (same instance on every resolve)

    private func runSingletonDemo() {
        DIContainer.shared.reset()
        append("── DEMO 2: registerSingleton ────────────────────")
        DIContainer.shared.registerSingleton(DatabaseService.self) { SQLiteDatabase() }
        append("✅ DatabaseService registered as singleton")

        let d1 = DIContainer.shared.resolve(DatabaseService.self)
        let d2 = DIContainer.shared.resolve(DatabaseService.self)
        append(d1.fetch("SELECT * FROM users"))
        append(d2.fetch("SELECT * FROM orders"))
        append("d1.instanceId → \(d1.instanceId)")
        append("d2.instanceId → \(d2.instanceId)")
        let same = d1.instanceId == d2.instanceId
        append(same ? "✅ Same instance — singleton works" : "❌ Different instances (unexpected)")
    }

    // MARK: - Demo 3 – @Dependency property wrapper inside a ViewModel

    private func runPropertyWrapperDemo() {
        DIContainer.shared.reset()
        append("── DEMO 3: @Dependency property wrapper ─────────")
        DIContainer.shared.registerSingleton(AnalyticsService.self) { FirebaseAnalytics() }
        DIContainer.shared.register(DatabaseService.self)            { SQLiteDatabase() }
        append("✅ Services registered")

        let vm = ReportViewModel()
        append("📦 ReportViewModel created — no manual injection")
        append("   @Dependency resolves lazily on first access")
        vm.generateReport().forEach { append("   " + $0) }
        append("✅ Both services injected automatically")
    }

    // MARK: - UI helpers

    private func demoButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func append(_ line: String) { log.append(line) }

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
}

#Preview {
    NavigationStack { DependencyInjectionView() }
}
