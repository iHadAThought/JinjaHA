import Foundation
import JinjaHA
import XCTest

final class FixtureGoldenTests: XCTestCase {
    func testAllGoldenTemplates() throws {
        let templatesDir = TestSupport.fixturesDirectory.appendingPathComponent("templates")
        let files = try FileManager.default.contentsOfDirectory(at: templatesDir, includingPropertiesForKeys: nil)
        let jinjaFiles = files.filter { $0.pathExtension == "jinja" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(jinjaFiles.isEmpty, "Expected golden template fixtures")

        let engine = try TestSupport.makeEngine()
        for jinjaURL in jinjaFiles {
            let expectedURL = jinjaURL.deletingPathExtension().appendingPathExtension("expected.txt")
            let template = try String(contentsOf: jinjaURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)
            let expected = try String(contentsOf: expectedURL, encoding: .utf8)
                .trimmingCharacters(in: .newlines)
            let actual = try engine.render(template).trimmingCharacters(in: .newlines)
            XCTAssertEqual(actual, expected, "Fixture mismatch for \(jinjaURL.lastPathComponent)")
        }
    }
}
