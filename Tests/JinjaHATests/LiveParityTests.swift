import Foundation
import JinjaHA
import XCTest

/// Optional live comparison against a real HA instance.
/// Skipped unless `HA_URL` and `HA_TOKEN` are set in the environment.
final class LiveParityTests: XCTestCase {
    func testWorkAuditTemplatesLocalMatchesAPIWhenConfigured() async throws {
        guard let urlString = ProcessInfo.processInfo.environment["HA_URL"],
              let token = ProcessInfo.processInfo.environment["HA_TOKEN"],
              let baseURL = URL(string: urlString),
              !token.isEmpty
        else {
            throw XCTSkip("Set HA_URL and HA_TOKEN to run live parity tests")
        }

        // Prefer live `/api/states` so local and HA see the same world; fall back to fixture.
        let snapshot: HAStateSnapshot
        if let liveData = try? await Self.fetchStatesJSON(baseURL: baseURL, token: token),
           let live = try? HAStateSnapshot.fromStatesJSON(liveData)
        {
            snapshot = live
        } else {
            snapshot = try TestSupport.loadSnapshot(named: "work_audit")
        }

        let local = LocalTemplateRenderer(snapshot: snapshot)
        let api = HAAPITemplateRenderer(baseURL: baseURL, token: token)
        let templates = try TestSupport.workAuditTemplateURLs()
        XCTAssertFalse(templates.isEmpty, "Expected work_audit_*.jinja fixtures")

        for templateURL in templates {
            let source = try String(contentsOf: templateURL, encoding: .utf8)
            let apiResult = try await api.render(source)
            let localResult = try await local.render(source)
            XCTAssertEqual(
                Self.normalizeParity(localResult),
                Self.normalizeParity(apiResult),
                "Parity mismatch: \(templateURL.lastPathComponent)"
            )
        }
    }

    func testHelperCatalogStripLocalMatchesAPIWhenConfigured() async throws {
        guard let urlString = ProcessInfo.processInfo.environment["HA_URL"],
              let token = ProcessInfo.processInfo.environment["HA_TOKEN"],
              let baseURL = URL(string: urlString),
              !token.isEmpty
        else {
            throw XCTSkip("Set HA_URL and HA_TOKEN to run live parity tests")
        }

        let snapshot: HAStateSnapshot
        if let liveData = try? await Self.fetchStatesJSON(baseURL: baseURL, token: token),
           let live = try? HAStateSnapshot.fromStatesJSON(liveData)
        {
            snapshot = live
        } else {
            snapshot = HAStateSnapshot()
        }

        let local = LocalTemplateRenderer(snapshot: snapshot)
        let api = HAAPITemplateRenderer(baseURL: baseURL, token: token)
        let strip = """
        {{ tau }}|{{ clamp(12, 0, 10) }}|{{ wrap(12, 0, 10) }}|{{ remap(50, 0, 100, 0, 10) }}|{{ bool('yes') }}|{{ '2' | add(3) }}|{{ 1 | ordinal }}|{{ version('2024.12') >= '2024.1' }}|{{ statistical_mode([1,2,2]) }}
        """
        let apiResult = try await api.render(strip)
        let localResult = try await local.render(strip)
        XCTAssertEqual(
            Self.normalizeParity(localResult),
            Self.normalizeParity(apiResult),
            "Helper catalog strip mismatch"
        )
    }

    private static func fetchStatesJSON(baseURL: URL, token: String) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HATemplateError.invalidURL
        }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix("/api") {
            path += "/states"
        } else if !path.hasSuffix("/api/states") {
            path += "/api/states"
        }
        components.path = path
        guard let url = components.url else {
            throw HATemplateError.invalidURL
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HATemplateError.api(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                message: "Failed to fetch /api/states"
            )
        }
        return data
    }

    private static func normalizeParity(_ text: String) -> String {
        text
            .replacingOccurrences(of: "True", with: "true")
            .replacingOccurrences(of: "False", with: "false")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

/// Local fixture renders for Work Audit board templates (no HA required).
final class WorkAuditFixtureTests: XCTestCase {
    func testWorkAuditTemplatesRenderAgainstFixture() throws {
        let engine = try TestSupport.makeEngine(snapshot: TestSupport.loadSnapshot(named: "work_audit"))
        let templates = try TestSupport.workAuditTemplateURLs()
        XCTAssertEqual(templates.count, 5, "Expected five Work Audit markdown card templates")

        for templateURL in templates {
            let source = try String(contentsOf: templateURL, encoding: .utf8)
            let output = try engine.render(source)
            XCTAssertFalse(
                output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Empty render: \(templateURL.lastPathComponent)"
            )
            XCTAssertFalse(
                output.contains("Waiting for WhenToWork data."),
                "Fixture entities missing for \(templateURL.lastPathComponent)"
            )
            XCTAssertFalse(
                output.contains("No paycheck audits yet."),
                "Paycheck fixture missing for \(templateURL.lastPathComponent)"
            )
        }
    }

    func testDateIsoformatAndStrftimeForBoardPatterns() throws {
        let engine = try TestSupport.makeEngine(snapshot: TestSupport.loadSnapshot(named: "work_audit"))
        XCTAssertEqual(try engine.render("{{ now().date().isoformat() }}"), "2026-08-02")
        let stamped = try engine.render(
            "{{ ('2026-07-10T09:00:00' | as_datetime).strftime('%a %b %-d') }}"
        )
        XCTAssertEqual(stamped, "Fri Jul 10")
        let clock = try engine.render(
            "{{ ('2026-07-10T09:00:00' | as_datetime).strftime('%-I:%M %p') }}"
        )
        // Apple DateFormatter may still zero-pad hours; accept either form.
        XCTAssertTrue(clock == "9:00 AM" || clock == "09:00 AM", clock)
        XCTAssertEqual(try engine.render("{{ '%.1f' | format(8) }}"), "8.0")
        XCTAssertEqual(try engine.render("{{ '%+.2f' | format(-0.5) }}"), "-0.50")
    }
}
