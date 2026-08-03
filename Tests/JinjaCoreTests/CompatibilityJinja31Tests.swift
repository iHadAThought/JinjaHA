import Foundation
import JinjaCore
import XCTest

/// Upstream-shaped goldens under `Compatibility/jinja-3.1/`.
final class CompatibilityJinja31Tests: XCTestCase {
    func testCompatibilityGoldens() throws {
        let dir = Self.compatibilityDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let jinjaFiles = files
            .filter { $0.pathExtension == "jinja" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(jinjaFiles.isEmpty, "Expected Compatibility/jinja-3.1 fixtures")

        for jinjaURL in jinjaFiles {
            let expectedURL = jinjaURL.deletingPathExtension().appendingPathExtension("expected.txt")
            let source = try String(contentsOf: jinjaURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)
            let expected = try String(contentsOf: expectedURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)
            let template = try Template(source)
            let actual = try template.render([:]).trimmingCharacters(in: .newlines)
            XCTAssertEqual(actual, expected, "Mismatch: \(jinjaURL.lastPathComponent)")
        }
    }

    private static func compatibilityDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // JinjaCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Compatibility/jinja-3.1")
    }
}
