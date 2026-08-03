import JinjaHA
import JinjaHASwiftUI
import XCTest

@MainActor
final class TemplateRenderModelTests: XCTestCase {
    func testPlainTextPassthrough() async {
        let model = TemplateRenderModel(
            template: "hello",
            renderer: StaticRenderer(result: "unused")
        )
        await model.renderIfNeeded()
        XCTAssertEqual(model.displayText, "hello")
        XCTAssertNil(model.errorMessage)
    }

    func testLastGoodRenderRetainedOnFailure() async {
        let renderer = FlakyRenderer()
        let model = TemplateRenderModel(
            template: "{{ x }}",
            renderer: renderer
        )
        await model.renderIfNeeded()
        XCTAssertEqual(model.displayText, "good")

        renderer.shouldFail = true
        await model.renderIfNeeded()
        XCTAssertEqual(model.displayText, "good")
        XCTAssertNil(model.errorMessage)
    }

    func testErrorWhenNoPriorRender() async {
        let model = TemplateRenderModel(
            template: "{{ x }}",
            renderer: FlakyRenderer(shouldFail: true)
        )
        await model.renderIfNeeded()
        XCTAssertEqual(model.errorMessage, "Template render failed")
        XCTAssertEqual(model.displayText, "{{ x }}")
    }

    func testLoadingPlaceholderBeforeFirstRender() {
        let model = TemplateRenderModel(
            template: "{{ x }}",
            renderer: StaticRenderer(result: "later"),
            placeholderWhileLoading: "…"
        )
        XCTAssertEqual(model.displayText, "…")
    }
}

private struct StaticRenderer: TemplateRendering {
    let result: String
    func render(_ template: String) async throws -> String { result }
}

private final class FlakyRenderer: TemplateRendering, @unchecked Sendable {
    var shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func render(_ template: String) async throws -> String {
        if shouldFail { throw HATemplateError.transport("boom") }
        return "good"
    }
}
