import SwiftUI

// MARK: - SwiftUI NavigationSplitView Example
// SwiftUI equivalent of UISplitViewController (iOS 16+). Sidebar + detail.
// Wide screens: both columns side by side. iPhone / compact width: one column at a time.

private struct SplitDemoItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let details: String
}

struct NavigationSplitViewExampleView: View {
    @Environment(\.dismiss) private var dismiss

    private let items = (1...20).map {
        SplitDemoItem(id: $0, title: "Item \($0)", details: "Details for item \($0).")
    }

    @State private var selection: SplitDemoItem.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    // SwiftUI version of topColumnForCollapsingToProposedTopColumn: which column shows when compact.
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            List(items, selection: $selection) { item in
                Text(item.title)
            }
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        } detail: {
            if let item = items.first(where: { $0.id == selection }) {
                Text(item.details)
                    .font(.title2)
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView("Select an item", systemImage: "sidebar.left")
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationSplitViewExampleView()
}
