import JinjaCore
import JinjaHA
import XCTest

final class ValueModelPhase3Tests: XCTestCase {
    func testStatesCallableWithoutPreprocess() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render(
            "{{ states('sensor.outdoor_temperature') }} / {{ states('sensor.nope') }}"
        )
        XCTAssertEqual(output, "21.5 / unknown")
    }

    func testStatesFilterWithoutPreprocess() throws {
        let engine = try TestSupport.makeEngine()
        XCTAssertEqual(try engine.render("{{ 'light.kitchen' | states }}"), "on")
    }

    func testDottedStatesMemberAccess() throws {
        let engine = try TestSupport.makeEngine()
        XCTAssertEqual(try engine.render("{{ states.light.kitchen.state }}"), "on")
    }

    func testEntityObjectStringifiesToState() throws {
        let engine = try TestSupport.makeEngine()
        // HA prints the state when the entity object is rendered directly.
        XCTAssertEqual(try engine.render("{{ states.light.kitchen }}"), "on")
        XCTAssertEqual(
            try engine.render("{{ states.sensor.outdoor_temperature }}"),
            "21.5"
        )
    }

    func testStatesIsCallable() throws {
        let env = HATemplateEnvironment(
            snapshot: try TestSupport.loadSnapshot()
        ).makeJinjaEnvironment()
        XCTAssertTrue(env["states"].isCallable)
        XCTAssertTrue(env["states"].isObject)
    }

    func testCallableObjectInJinjaCore() throws {
        let env = Environment()
        env["dual"] = .object(
            [.string("x"): .int(1)],
            call: { args, _, _ in
                .string("called:\(args.first?.description ?? "")")
            }
        )
        let template = try Template("{{ dual.x }}/{{ dual('z') }}")
        XCTAssertEqual(try template.render([:], environment: env), "1/called:z")
    }

    func testObjectStringRepresentation() throws {
        let env = Environment()
        env["entity"] = .object(
            [.string("state"): .string("on")],
            stringRepresentation: "on"
        )
        let template = try Template("{{ entity }}|{{ entity.state }}")
        XCTAssertEqual(try template.render([:], environment: env), "on|on")
    }
}
