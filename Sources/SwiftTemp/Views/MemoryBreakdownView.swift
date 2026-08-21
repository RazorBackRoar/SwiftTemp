import SwiftUI

struct MemoryBreakdownView: View {
    var body: some View {
        ProcessBreakdownView(
            title: "Memory Breakdown",
            subtitle: "Largest consumers first — right-click a row for Force Quit.",
            systemImage: "memorychip",
            accent: .red,
            load: ProcessBreakdownLoaders.memory
        )
    }
}
