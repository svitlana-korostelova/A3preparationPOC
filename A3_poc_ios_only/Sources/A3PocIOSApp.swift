import SwiftUI

@main
struct A3PocIOSApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ArchitectureHomeView()
                    .tabItem {
                        Label("Architecture", systemImage: "building.columns")
                    }

                HomeView()
                    .tabItem {
                        Label("Concurrency", systemImage: "arrow.triangle.branch")
                    }
            }
        }
    }
}
