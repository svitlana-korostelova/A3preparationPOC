import SwiftUI

struct CleanArchitectureView: View {
    var body: some View {
        Text("Coming soon")
            .foregroundStyle(.secondary)
            .navigationTitle("Clean Architecture")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { CleanArchitectureView() }
}
