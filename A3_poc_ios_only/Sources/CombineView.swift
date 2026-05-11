import SwiftUI
import Combine

// ════════════════════════════════════════════════════════════════════════════
// Combine Demo
//
// Combine is Apple's declarative reactive framework for processing values
// over time. Key concepts demonstrated here:
//   • PassthroughSubject  – manually push values into a pipeline
//   • CurrentValueSubject – like PassthroughSubject but holds current value
//   • @Published + sink   – observe property changes reactively
//   • Operators           – map, filter, debounce, removeDuplicates
//   • combineLatest       – merge two publishers into one stream
// ════════════════════════════════════════════════════════════════════════════

// MARK: - ViewModel (owns Combine subscriptions)

// Keeping subscriptions in an ObservableObject means they live as long as
// the view model and are cancelled automatically on deinit.
@MainActor
final class CombineViewModel: ObservableObject {

    // ── Published outputs consumed by the view ────────────────────────────
    @Published private(set) var log: [String] = []

    // Used by the "Operators" demo: typed text → filtered/debounced results
    @Published var searchText: String = ""
    @Published private(set) var searchResult: String = "—"

    // ── Private state ─────────────────────────────────────────────────────
    private var cancellables = Set<AnyCancellable>()

    // ─────────────────────────────────────────────────────────────────────
    // DEMO 1 – PassthroughSubject
    //
    // A subject is both a Publisher and a Subscriber.
    // PassthroughSubject<Output, Failure> emits only values sent after
    // subscription; it has no memory of previous values.
    // ─────────────────────────────────────────────────────────────────────
    func runPassthroughSubject() {
        log.append("── PassthroughSubject ──")

        // 1. Create a subject that emits Strings and never fails.
        let subject = PassthroughSubject<String, Never>()

        // 2. Subscribe – sink receives each emitted value.
        //    store(in:) keeps the subscription alive until cancellables is deallocated.
        subject
            .sink { [weak self] value in
                self?.log.append("  received: \"\(value)\"")
            }
            .store(in: &cancellables)

        // 3. Push values into the pipeline imperatively.
        subject.send("Hello")
        subject.send("from")
        subject.send("Combine")

        // 4. send(completion:) signals no more values will come.
        subject.send(completion: .finished)
        log.append("  completion sent ✓")
    }

    // ─────────────────────────────────────────────────────────────────────
    // DEMO 2 – CurrentValueSubject
    //
    // Like PassthroughSubject but stores the latest value.
    // New subscribers immediately receive the current value on subscription.
    // ─────────────────────────────────────────────────────────────────────
    func runCurrentValueSubject() {
        log.append("── CurrentValueSubject ──")

        // 1. Create with an initial value.
        let counter = CurrentValueSubject<Int, Never>(0)
        log.append("  initial value: \(counter.value)")

        // 2. First subscriber – will see 0 immediately, then updates.
        counter
            .sink { [weak self] value in
                self?.log.append("  subscriber A → \(value)")
            }
            .store(in: &cancellables)

        // 3. Update the value – all existing subscribers are notified.
        counter.send(1)
        counter.send(2)

        // 4. Second subscriber connects AFTER some values were sent.
        //    It immediately receives the current value (2), not 0 or 1.
        counter
            .sink { [weak self] value in
                self?.log.append("  subscriber B (late) → \(value)")
            }
            .store(in: &cancellables)

        counter.send(3)
        log.append("  CurrentValueSubject demo done ✓")
    }

    // ─────────────────────────────────────────────────────────────────────
    // DEMO 3 – @Published + map + filter
    //
    // @Published wraps a property and exposes it as a Publisher.
    // Combine operators transform the stream before values reach subscribers.
    // ─────────────────────────────────────────────────────────────────────
    func runPublishedOperators() {
        log.append("── @Published + Operators ──")

        // Local observable object to demonstrate @Published.
        final class Counter: ObservableObject {
            @Published var count: Int = 0
        }
        let model = Counter()

        // 1. Observe $count (the projected publisher), apply operators:
        //    • map  – multiply the count
        //    • filter – only let even results through
        model.$count
            .map { $0 * 10 }
            .filter { $0 % 20 == 0 }          // passes 0, 20, 40, 60 …
            .sink { [weak self] value in
                self?.log.append("  filtered value: \(value)")
            }
            .store(in: &cancellables)

        // 2. Drive the counter; only even multiples of 10 will appear.
        for i in 0...5 { model.count = i }
        log.append("  Operators demo done ✓")
    }

    // ─────────────────────────────────────────────────────────────────────
    // DEMO 4 – combineLatest
    //
    // combineLatest merges two publishers: whenever EITHER emits a new value,
    // it forwards the latest value from BOTH as a tuple.
    // Classic use-case: form validation (enable submit when both fields valid).
    // ─────────────────────────────────────────────────────────────────────
    func runCombineLatest() {
        log.append("── combineLatest ──")

        let username = PassthroughSubject<String, Never>()
        let password = PassthroughSubject<String, Never>()

        // 1. Combine the two streams; result emits only after BOTH have emitted once.
        username
            .combineLatest(password)
            .map { user, pass -> String in
                // 2. Simple "form validation" logic inline.
                let userOK = user.count >= 3
                let passOK = pass.count >= 6
                return userOK && passOK ? "✅ Form valid" : "❌ Form invalid"
            }
            .sink { [weak self] status in
                self?.log.append("  \(status)")
            }
            .store(in: &cancellables)

        // 3. Simulate user typing in both fields.
        username.send("Jo")          // too short → no output yet (password hasn't sent)
        password.send("abc")         // password sends → both available: invalid
        username.send("Joe")         // username updates → still invalid (pass too short)
        password.send("secret123")   // password updates → both valid now
        log.append("  combineLatest demo done ✓")
    }

    // ─────────────────────────────────────────────────────────────────────
    // DEMO 5 – debounce + removeDuplicates (live search simulation)
    //
    // debounce waits for a pause in events before forwarding the latest one.
    // removeDuplicates suppresses consecutive identical values.
    // These two operators together model a typical search-as-you-type field.
    // ─────────────────────────────────────────────────────────────────────
    func setupSearchPipeline() {
        // $searchText is the @Published property bound to the TextField in the view.
        $searchText
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .map { query -> String in
                guard !query.isEmpty else { return "—" }
                // Simulated local search result.
                return "Results for: \"\(query)\" (\(query.count * 3) items)"
            }
            .assign(to: &$searchResult)
            // assign(to:) automatically manages lifetime when assigning to @Published.
    }

    // MARK: - Helpers
    func clearLog() { log.removeAll() }
}

// MARK: - View

struct CombineView: View {

    @StateObject private var vm = CombineViewModel()

    var body: some View {
        VStack(spacing: 0) {

            // ── Button grid ───────────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    demoButton("PassthroughSubject", color: .blue)   { vm.runPassthroughSubject() }
                    demoButton("CurrentValueSubject", color: .purple) { vm.runCurrentValueSubject() }
                    demoButton("@Published + Ops",    color: .orange) { vm.runPublishedOperators() }
                    demoButton("combineLatest",        color: .green)  { vm.runCombineLatest() }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)

            Divider()

            // ── Live search (debounce demo) ────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("debounce + removeDuplicates (search simulation)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Type to search…", text: $vm.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)

                Text(vm.searchResult)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.teal)
                    .padding(.horizontal)
            }
            .padding(.vertical, 10)

            Divider()

            // ── Log output ────────────────────────────────────────────────
            logView
        }
        .navigationTitle("Combine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") { vm.clearLog() }
            }
        }
        .onAppear { vm.setupSearchPipeline() }
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
                    ForEach(Array(vm.log.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .id(index)
                    }
                }
                .padding()
            }
            .onChange(of: vm.log.count) { _, _ in
                if let last = vm.log.indices.last {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { CombineView() }
}
