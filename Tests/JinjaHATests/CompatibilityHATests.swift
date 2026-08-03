import Foundation
import JinjaHA
import XCTest

/// HA helper parity goldens under `Compatibility/home-assistant/`.
final class CompatibilityHATests: XCTestCase {
    func testHomeAssistantGoldens() throws {
        let dir = Self.compatibilityDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let jinjaFiles = files
            .filter { $0.pathExtension == "jinja" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(jinjaFiles.isEmpty, "Expected Compatibility/home-assistant fixtures")

        let engine = try TestSupport.makeEngine()
        for jinjaURL in jinjaFiles {
            let expectedURL = jinjaURL.deletingPathExtension().appendingPathExtension("expected.txt")
            let source = try String(contentsOf: jinjaURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)
            let expected = try String(contentsOf: expectedURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)
            let actual = try engine.render(source).trimmingCharacters(in: .newlines)
            XCTAssertEqual(actual, expected, "Mismatch: \(jinjaURL.lastPathComponent)")
        }
    }

    private static func compatibilityDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // JinjaHATests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Compatibility/home-assistant")
    }
}
