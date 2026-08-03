import Jinja
import JinjaHA
import XCTest

final class EngineSmokeTests: XCTestCase {
    func testBasicInterpolation() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("Hello {{ 'World' }}!")
        XCTAssertEqual(output, "Hello World!")
    }

    func testTrimAndLstripOptions() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("""
        {% for i in range(2) %}
        - {{ i }}
        {% endfor %}
        """)
        XCTAssertEqual(output, "- 0\n- 1\n")
    }

    func testStatesCallableAndMissingEntity() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render(
            "{{ states('sensor.outdoor_temperature') }} / {{ states('sensor.nope') }}"
        )
        XCTAssertEqual(output, "21.5 / unknown")
    }

    func testStatesFilterForm() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("{{ 'light.kitchen' | states }}")
        XCTAssertEqual(output, "on")
    }

    func testDottedStatesAccess() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("{{ states.light.kitchen.state }}")
        XCTAssertEqual(output, "on")
    }

    func testControlFlowWithHAHelpers() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("""
        {% if is_state('light.kitchen', 'on') %}yes{% else %}no{% endif %}
        """)
        XCTAssertEqual(output, "yes")
    }
}
