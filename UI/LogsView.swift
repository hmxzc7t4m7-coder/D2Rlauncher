import SwiftUI

struct LogsView: View {
    @ObservedObject var logger: AppLogger

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(logger.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(line)
                    }
                }
                .onChange(of: logger.lines.count) {
                    guard let last = logger.lines.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minHeight: 220)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.88))
        )
        .foregroundStyle(.green)
    }
}
