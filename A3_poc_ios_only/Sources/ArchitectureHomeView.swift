import SwiftUI

// MARK: - Architecture Home Screen
// Lists all architecture pattern topics; each row navigates to its demo scene.

struct ArchitectureHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Architecture Patterns")) {

                    NavigationLink(destination: MVVMView()) {
                        Label("MVVM", systemImage: "rectangle.3.group")
                    }

                    NavigationLink(destination: VIPERView()) {
                        Label("VIPER", systemImage: "diamond")
                    }

                    NavigationLink(destination: TCAView()) {
                        Label("TCA – The Composable Architecture", systemImage: "square.stack.3d.up")
                    }

                    NavigationLink(destination: CleanArchitectureView()) {
                        Label("Clean Architecture", systemImage: "circle.hexagonpath")
                    }

                    NavigationLink(destination: DependencyInjectionView()) {
                        Label("Dependency Injection", systemImage: "puzzlepiece.extension")
                    }
                }
            }
            .navigationTitle("Architecture")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    ArchitectureHomeView()
}
