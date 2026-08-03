import JinjaCore
import XCTest

final class EnvironmentFoundationTests: XCTestCase {
    func testCustomGlobalSurvivesInterpret() throws {
        let env = Environment()
        env.registerGlobal(
            "greet",
            .function { args, _, _ in
                let name: String
                if case let .string(s) = args.first { name = s } else { name = "world" }
                return .string("hi \(name)")
            }
        )
        // Also override a built-in name to prove caller wins.
        env.registerGlobal(
            "range",
            .function { _, _, _ in
                .array([.int(99)])
            }
        )

        let template = try Template("{{ greet('Ada') }}|{{ range(5) | first }}")
        let output = try template.render([:], environment: env)
        XCTAssertEqual(output, "hi Ada|99")
    }

    func testRegisteredFilterOverridesBuiltin() throws {
        let env = Environment()
        env.registerFilter("upper") { args, _, _ in
            .string("CUSTOM")
        }
        let template = try Template("{{ 'hello' | upper }}")
        let output = try template.render([:], environment: env)
        XCTAssertEqual(output, "CUSTOM")
    }

    func testRegisteredTestOverridesBuiltin() throws {
        let env = Environment()
        env.registerTest("number") { _, _, _ in
            .boolean(false)
        }
        let template = try Template("{% if 1 is number %}yes{% else %}no{% endif %}")
        let output = try template.render([:], environment: env)
        XCTAssertEqual(output, "no")
    }

    func testDenyAllLoaderRejectsLoad() {
        let env = Environment()
        XCTAssertThrowsError(try env.loadTemplate(named: "macros.j2")) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.lowercased().contains("deny-all") || message.contains("disabled"))
        }
    }

    func testDictionaryLoaderAllowlist() throws {
        let env = Environment()
        env.loader = DictionaryTemplateLoader([
            "part": "INCLUDED",
        ])
        XCTAssertEqual(try env.loadTemplate(named: "part"), "INCLUDED")
        XCTAssertThrowsError(try env.loadTemplate(named: "missing"))
    }

    func testDefaultAttributePolicyBlocksUnderscoreNames() throws {
        let env = Environment()
        env["obj"] = .object([
            "ok": .string("visible"),
            "_secret": .string("hidden"),
        ])
        let template = try Template("{{ obj.ok }}|{{ obj._secret }}")
        let output = try template.render([:], environment: env)
        // Blocked attribute renders as empty/undefined.
        XCTAssertEqual(output, "visible|")
    }

    func testPermissivePolicyAllowsUnderscoreNames() throws {
        let env = Environment()
        env.attributePolicy = PermissiveAttributePolicy()
        env["obj"] = .object([
            "_secret": .string("hidden"),
        ])
        let template = try Template("{{ obj._secret }}")
        let output = try template.render([:], environment: env)
        XCTAssertEqual(output, "hidden")
    }

    func testDialectVersionConstants() {
        XCTAssertEqual(JinjaCoreInfo.dialectVersion, "3.1")
        XCTAssertGreaterThanOrEqual(JinjaCoreInfo.implementationRevision, 1)
    }

    func testCopyingPreservesRegistries() throws {
        let env = Environment()
        env.registerFilter("shout") { args, _, _ in
            guard case let .string(s) = args.first else { return .string("") }
            return .string(s.uppercased() + "!")
        }
        env.loader = DictionaryTemplateLoader(["x": "y"])

        let copy = Environment(copying: env)
        let template = try Template("{{ 'hey' | shout }}")
        XCTAssertEqual(try template.render([:], environment: copy), "HEY!")
        XCTAssertEqual(try copy.loadTemplate(named: "x"), "y")
    }
}
