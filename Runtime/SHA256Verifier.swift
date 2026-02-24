import CryptoKit
import Foundation

struct SHA256Verifier {
    static func parseChecksum(_ rawValue: String) -> String? {
        let token = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace || $0 == "*" })
            .first
        return token.map(String.init)?.lowercased()
    }

    static func sha256Hex(forFileAt url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func verify(fileURL: URL, expectedChecksum: String) throws -> Bool {
        let normalizedExpected = expectedChecksum.lowercased()
        let actual = try sha256Hex(forFileAt: fileURL)
        return actual == normalizedExpected
    }
}
