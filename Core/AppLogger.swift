import Foundation

@MainActor
final class AppLogger: ObservableObject {
    enum Level: String {
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        case debug = "DEBUG"
    }

    @Published private(set) var lines: [String] = []

    private let maxLines: Int

    init(maxLines: Int = 2_000) {
        self.maxLines = maxLines
    }

    func log(_ level: Level = .info, _ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] \(message)"
        lines.append(line)

        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func recentLines(limit: Int) -> String {
        guard limit > 0 else { return "" }
        return lines.suffix(limit).joined(separator: "\n")
    }
}
