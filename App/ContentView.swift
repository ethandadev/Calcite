import SwiftUI
import CalciteCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "diamond.fill").font(.system(size: 56)).foregroundStyle(.teal)
            Text("Calcite").font(.largeTitle.bold())
            Text("Minecraft Java for iPhone and iPad").foregroundStyle(.secondary)
        }
        .padding()
    }
}
