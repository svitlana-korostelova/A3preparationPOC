import SwiftUI

// MARK: - Home Screen
// Entry point presenting all concurrency topics.
// Each row navigates to a dedicated demo scene.

struct HomeView: View {
    
    
    var body: some View {
        
        Text("")
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
            .navigationTitle("Concurrency PoC")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    HomeView()
}
