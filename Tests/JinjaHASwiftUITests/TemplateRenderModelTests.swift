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

    func testNeedsTemplateDetection() {
        let jinja = TemplateRenderModel(template: "{{ x }}", renderer: StaticRenderer(result: ""))
        XCTAssertTrue(jinja.needsTemplate)
        let plain = TemplateRenderModel(template: "plain", renderer: StaticRenderer(result: ""))
        XCTAssertFalse(plain.needsTemplate)
        let statement = TemplateRenderModel(
            template: "{% if true %}x{% endif %}",
            renderer: StaticRenderer(result: "")
        )
        XCTAssertTrue(statement.needsTemplate)
    }

    func testRerenderAfterTemplateChange() async {
        let renderer = CountingRenderer(result: "v1")
        let model = TemplateRenderModel(template: "{{ a }}", renderer: renderer)
        await model.renderIfNeeded()
        XCTAssertEqual(model.displayText, "v1")
        XCTAssertEqual(renderer.calls, 1)

        renderer.result = "v2"
        model.template = "{{ b }}"
        await model.renderIfNeeded()
        XCTAssertEqual(model.displayText, "v2")
        XCTAssertEqual(renderer.calls, 2)
    }

    func testCancelledFirstRenderKeepsPlaceholder() async {
        let model = TemplateRenderModel(
            template: "{{ x }}",
            renderer: SlowRenderer(result: "late", delayNanoseconds: 400_000_000),
            placeholderWhileLoading: "…"
        )
        let task = Task { await model.renderIfNeeded() }
        try? await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()
        await task.value
        XCTAssertEqual(model.displayText, "…")
        XCTAssertNil(model.errorMessage)
    }

    func testCancelledRerenderKeepsLastGood() async {
        let renderer = SlowThenFastRenderer()
        let model = TemplateRenderModel(template: "{{ x }}", renderer: renderer)
        await model.renderIfNeeded()
        XCTAssertEqual(model.displayText, "first")

        renderer.delayNext = true
        let task = Task { await model.renderIfNeeded() }
        try? await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()
        await task.value
        XCTAssertEqual(model.displayText, "first")
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

private final class CountingRenderer: TemplateRendering, @unchecked Sendable {
    var result: String
    private(set) var calls = 0

    init(result: String) {
        self.result = result
    }

    func render(_ template: String) async throws -> String {
        calls += 1
        return result
    }
}

private final class SlowRenderer: TemplateRendering, @unchecked Sendable {
    let result: String
    let delayNanoseconds: UInt64

    init(result: String, delayNanoseconds: UInt64) {
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func render(_ template: String) async throws -> String {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
        return result
    }
}

private final class SlowThenFastRenderer: TemplateRendering, @unchecked Sendable {
    var delayNext = false
    private var didFirst = false

    func render(_ template: String) async throws -> String {
        if !didFirst {
            didFirst = true
            return "first"
        }
        if delayNext {
            try await Task.sleep(nanoseconds: 400_000_000)
            try Task.checkCancellation()
            return "second"
        }
        return "second"
    }
}
