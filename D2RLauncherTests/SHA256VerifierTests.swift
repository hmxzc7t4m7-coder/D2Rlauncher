import XCTest
@testable import D2RLauncher

final class SHA256VerifierTests: XCTestCase {
    func testParseChecksumExtractsFirstToken() throws {
        let parsed = SHA256Verifier.parseChecksum("ABCDEF1234567890  d2r-runtime-macos.tar.gz")
        XCTAssertEqual(parsed, "abcdef1234567890")
    }

    func testParseChecksumSupportsAsteriskFormat() throws {
        let parsed = SHA256Verifier.parseChecksum("0123456789abcdef *d2r-runtime-macos.tar.gz")
        XCTAssertEqual(parsed, "0123456789abcdef")
    }

    func testVerifyMatchesKnownHash() throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sha-test-\(UUID().uuidString).txt")
        try "hello".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let expected = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        XCTAssertTrue(try SHA256Verifier.verify(fileURL: tempURL, expectedChecksum: expected))
    }
}
