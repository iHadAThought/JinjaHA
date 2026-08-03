import JinjaCore
import XCTest

final class SandboxPolicyTests: XCTestCase {
    func testAttrFilterHonorsDefaultPolicy() throws {
        let env = Environment()
        env["obj"] = .object([
            "ok": .string("visible"),
            "_secret": .string("hidden"),
        ])
        let template = try Template("{{ obj | attr('ok') }}|{{ obj | attr('_secret') }}")
        XCTAssertEqual(try template.render([:], environment: env), "visible|")
    }

    func testAttrFilterWithPermissivePolicy() throws {
        let env = Environment()
        env.attributePolicy = PermissiveAttributePolicy()
        env["obj"] = .object([
            "_secret": .string("hidden"),
        ])
        let template = try Template("{{ obj | attr('_secret') }}")
        XCTAssertEqual(try template.render([:], environment: env), "hidden")
    }

    func testCallableTest() throws {
        let env = Environment()
        env["fn"] = .function { _, _, _ in .string("x") }
        env["obj"] = .object([:], call: { _, _, _ in .string("y") })
        let template = try Template("{{ fn is callable }}|{{ obj is callable }}|{{ 1 is callable }}")
        XCTAssertEqual(try template.render([:], environment: env), "true|true|false")
    }
}
