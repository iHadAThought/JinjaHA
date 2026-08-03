import Foundation
import JinjaHA
import XCTest

/// Optional live comparison against a real HA instance.
/// Skipped unless `HA_URL` and `HA_TOKEN` are set in the environment.
final class LiveParityTests: XCTestCase {
    func testLocalMatchesAPIWhenConfigured() async throws {
        guard let urlString = ProcessInfo.processInfo.environment["HA_URL"],
              let token = ProcessInfo.processInfo.environment["HA_TOKEN"],
              let url = URL(string: urlString),
              !token.isEmpty
        else {
            throw XCTSkip("Set HA_URL and HA_TOKEN to run live parity tests")
        }

        let template = "{{ 1 + 1 }}"
        let api = HAAPITemplateRenderer(baseURL: url, token: token)
        let local = LocalTemplateRenderer(snapshot: HAStateSnapshot())
        let apiResult = try await api.render(template)
        let localResult = try await local.render(template)
        XCTAssertEqual(localResult.trimmingCharacters(in: .whitespacesAndNewlines),
                       apiResult.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
