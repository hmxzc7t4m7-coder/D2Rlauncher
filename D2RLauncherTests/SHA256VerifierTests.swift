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
}
