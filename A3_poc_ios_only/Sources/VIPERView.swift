import SwiftUI

struct VIPERView: View {
    var body: some View {
        Text("Coming soon")
            .foregroundStyle(.secondary)
            .navigationTitle("VIPER")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { VIPERView() }
}
