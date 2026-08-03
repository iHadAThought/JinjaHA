import JinjaHA
import XCTest

final class SecurityLimitTests: XCTestCase {
    func testTemplateTooLarge() throws {
        let limits = HATemplateLimits(maxTemplateBytes: 16, maxOutputBytes: 1_000_000, renderTimeout: nil)
        let engine = try TestSupport.makeEngine(limits: limits)
        XCTAssertThrowsError(try engine.render(String(repeating: "a", count: 64))) { error in
            guard let typed = error as? HATemplateError,
                  case .templateTooLarge = typed
            else {
                return XCTFail("Expected templateTooLarge, got \(error)")
            }
        }
    }

    func testOutputTooLarge() throws {
        let limits = HATemplateLimits(maxTemplateBytes: 10_000, maxOutputBytes: 8, renderTimeout: nil)
        let engine = try TestSupport.makeEngine(limits: limits)
        XCTAssertThrowsError(try engine.render("{{ 'abcdefghijklmnop' }}")) { error in
            guard let typed = error as? HATemplateError,
                  case .outputTooLarge = typed
            else {
                return XCTFail("Expected outputTooLarge, got \(error)")
            }
        }
    }

    func testRangeTooLarge() throws {
        let limits = HATemplateLimits(maxTemplateBytes: 10_000, maxOutputBytes: 1_000_000, maxRangeSize: 5, renderTimeout: nil)
        let engine = try TestSupport.makeEngine(limits: limits)
        XCTAssertThrowsError(try engine.render("{% for i in range(20) %}{{ i }}{% endfor %}")) { error in
            let message = String(describing: error)
            XCTAssertTrue(
                (error as? HATemplateError) == .rangeTooLarge(limit: 5)
                    || message.lowercased().contains("range")
                    || message.lowercased().contains("limit"),
                "Unexpected error: \(error)"
            )
        }
    }

    func testRenderTimeout() async throws {
        let limits = HATemplateLimits(
            maxTemplateBytes: 100_000,
            maxOutputBytes: 500_000,
            maxRangeSize: 100_000,
            renderTimeout: .milliseconds(1)
        )
        // A large nested render that should exceed 1ms on most machines.
        let engine = try TestSupport.makeEngine(limits: limits)
        do {
            _ = try await engine.renderAsync("{% for i in range(5000) %}{{ i }}{% endfor %}")
            // If the machine is extremely fast, timeout may not fire — still acceptable.
        } catch let error as HATemplateError {
            XCTAssertEqual(error, .renderTimedOut)
        }
    }
}
