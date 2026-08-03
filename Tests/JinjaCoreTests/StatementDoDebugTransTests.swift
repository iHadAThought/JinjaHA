import Foundation
import JinjaCore
import XCTest

final class StatementDoDebugTransTests: XCTestCase {
    func testDoEvaluatesWithoutOutput() throws {
        let env = Environment()
        let simple = try Template("{% set x = 1 %}{% do x %}done")
        XCTAssertEqual(try simple.render([:], environment: env), "done")
    }

    func testDebugDumpsKeys() throws {
        let env = Environment(initial: ["sensor": .string("on")])
        let template = try Template("{% debug %}")
        let out = try template.render([:], environment: env)
        XCTAssertTrue(out.contains("sensor"), out)
        XCTAssertTrue(out.contains("debug:"), out)
    }

    func testTransPassThroughAndCatalog() throws {
        let env = Environment()
        env.translationCatalog = ["Hello": "Bonjour"]
        XCTAssertEqual(
            try Template("{% trans %}Hello{% endtrans %}").render([:], environment: env),
            "Bonjour"
        )
        XCTAssertEqual(
            try Template("{% trans %}World{% endtrans %}").render([:], environment: env),
            "World"
        )
    }

    func testTransPlaceholders() throws {
        let env = Environment()
        env.translationCatalog = ["Hello %(user)s!": "Bonjour %(user)s!"]
        XCTAssertEqual(
            try Template("{% trans user='Ada' %}Hello {{ user }}!{% endtrans %}").render(
                [:],
                environment: env
            ),
            "Bonjour Ada!"
        )
    }
}
