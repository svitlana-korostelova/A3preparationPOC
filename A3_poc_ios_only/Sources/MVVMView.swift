import SwiftUI

struct MVVMView: View {
    var body: some View {
        Text("Coming soon")
            .foregroundStyle(.secondary)
            .navigationTitle("MVVM")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { MVVMView() }
}
