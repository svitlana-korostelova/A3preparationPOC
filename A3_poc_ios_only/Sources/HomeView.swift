import SwiftUI

// MARK: - Concurrency Home Screen
// Lists all concurrency topics; each row navigates to its demo scene.

struct HomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Concurrency Topics")) {

                    NavigationLink(destination: GCDView()) {
                        Label("GCD – Grand Central Dispatch", systemImage: "arrow.triangle.branch")
                    }

                    NavigationLink(destination: OperationQueueView()) {
                        Label("OperationQueue", systemImage: "list.bullet.rectangle")
                    }

                    NavigationLink(destination: SemaphoreView()) {
                        Label("Semaphores", systemImage: "light.beacon.max")
                    }

                    NavigationLink(destination: LocksView()) {
                        Label("Locks", systemImage: "lock.shield")
                    }

                    NavigationLink(destination: StructuredConcurrencyView()) {
                        Label("Structured Concurrency", systemImage: "square.3.layers.3d.top.filled")
                    }

                    NavigationLink(destination: PThreadsView()) {
                        Label("POSIX Threads (pthreads)", systemImage: "cpu")
                    }

                    NavigationLink(destination: CombineView()) {
                        Label("Combine", systemImage: "dot.radiowaves.left.and.right")
                    }
                }
            }
            .navigationTitle("Concurrency")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    HomeView()
}
