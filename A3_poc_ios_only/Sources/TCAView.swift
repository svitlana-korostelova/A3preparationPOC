import SwiftUI

struct TCAView: View {
    var body: some View {
        Text("Coming soon")
            .foregroundStyle(.secondary)
            .navigationTitle("TCA")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { TCAView() }
}
