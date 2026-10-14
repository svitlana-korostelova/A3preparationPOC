import SwiftUI

// MARK: - Examples Home Screen
// Lists UIKit interop examples; each row navigates to its demo scene.

struct ExamplesHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("UIKit Examples")) {
                    NavigationLink {
                        ProfileViewControllerRepresentable()
                            .toolbar(.hidden, for: .navigationBar)
                            .ignoresSafeArea()
                    } label: {
                        Label("Example1 – Custom VC Transition", systemImage: "rectangle.on.rectangle.angled")
                    }

                    NavigationLink(destination: SplitViewExampleScreen()) {
                        Label("UISplitViewController – List & Detail", systemImage: "sidebar.left")
                    }

                    NavigationLink(destination: CoreAnimationView()) {
                        Label("Core Animation – Progress Ring & Spring", systemImage: "circle.dashed")
                    }
                }

                Section(header: Text("SwiftUI Examples")) {
                    NavigationLink(destination: NavigationSplitViewExampleView()) {
                        Label("NavigationSplitView – Sidebar & Detail", systemImage: "sidebar.squares.left")
                    }
                }
            }
            .navigationTitle("Examples")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    ExamplesHomeView()
}
