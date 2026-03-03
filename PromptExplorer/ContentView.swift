import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Prompt Explorer")
                    .font(.largeTitle.bold())

                Text("Welcome to Prompt Explorer")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Prompt Explorer")
        }
    }
}

#Preview {
    ContentView()
}
