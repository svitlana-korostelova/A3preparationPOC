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
