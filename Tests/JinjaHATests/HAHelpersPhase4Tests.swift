import JinjaCore
import JinjaHA
import XCTest

final class HAHelpersPhase4Tests: XCTestCase {
    func testIifFunctionAndFilter() throws {
        let engine = try TestSupport.makeEngine()
        XCTAssertEqual(
            try engine.render("{{ iif(true, 'yes', 'no') }}"),
            "yes"
        )
        XCTAssertEqual(
            try engine.render("{{ iif(false, 'yes', 'no') }}"),
            "no"
        )
        XCTAssertEqual(
            try engine.render("{{ is_state('light.kitchen', 'on') | iif('open', 'closed') }}"),
            "open"
        )
        XCTAssertEqual(
            try engine.render("{{ none | iif('t', 'f', 'n') }}"),
            "n"
        )
    }

    func testIsNumber() throws {
        let engine = try TestSupport.makeEngine()
        XCTAssertEqual(try engine.render("{{ is_number('21.5') }}"), "true")
        XCTAssertEqual(try engine.render("{{ is_number('unavailable') }}"), "false")
        XCTAssertEqual(try engine.render("{% if '19.8' is is_number %}y{% else %}n{% endif %}"), "y")
        XCTAssertEqual(
            try engine.render(
                "{{ ['21.5', 'unavailable', '19.8'] | select('is_number') | list | join(',') }}"
            ),
            "21.5,19.8"
        )
    }

    func testIsDefinedDoesNotTreatNullAsUndefined() throws {
        let engine = try TestSupport.makeEngine()
        XCTAssertEqual(
            try engine.render("{% if none is defined %}defined{% else %}missing{% endif %}"),
            "defined"
        )
        XCTAssertEqual(
            try engine.render("{% if missing_var is defined %}defined{% else %}missing{% endif %}"),
            "missing"
        )
        XCTAssertEqual(
            try engine.render("{{ none is is_defined }}"),
            "true"
        )
    }

    func testSlugify() throws {
        let engine = try TestSupport.makeEngine()
        XCTAssertEqual(try engine.render("{{ slugify('Hello World!') }}"), "hello_world")
        XCTAssertEqual(try engine.render("{{ 'Living Room Light' | slugify('-') }}"), "living-room-light")
        XCTAssertEqual(try engine.render("{{ slugify('Café Room') }}"), "cafe_room")
    }

    func testAverage() throws {
        let engine = try TestSupport.makeEngine()
        let multi = try engine.render("{{ average(21.5, 22.0, 19.8) }}")
        XCTAssertEqual(Double(multi)!, 21.1, accuracy: 0.0001)
        let filtered = try engine.render("{{ [21.5, 22.0, 19.8] | average }}")
        XCTAssertEqual(Double(filtered)!, 21.1, accuracy: 0.0001)
        XCTAssertEqual(try engine.render("{{ [] | average(default=0) }}"), "0")
    }

    func testFloorEntities() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("{{ floor_entities('downstairs') | join(',') }}")
        XCTAssertEqual(output, "light.kitchen")
        XCTAssertEqual(
            try engine.render("{{ 'Downstairs' | floor_entities | join(',') }}"),
            "light.kitchen"
        )
    }

    func testRegexHelpers() throws {
        let engine = try TestSupport.makeEngine()
        XCTAssertEqual(try engine.render("{{ regex_match('light.kitchen', 'light\\\\.') }}"), "true")
        XCTAssertEqual(try engine.render("{{ regex_match('sensor.temp', 'light\\\\.') }}"), "false")
        XCTAssertEqual(try engine.render("{{ regex_search('abXYcd', 'XY') }}"), "true")
        XCTAssertEqual(
            try engine.render("{{ regex_replace('a-b-c', '-', '_') }}"),
            "a_b_c"
        )
        XCTAssertEqual(
            try engine.render("{{ regex_findall('a1b2c3', '[0-9]') | join(',') }}"),
            "1,2,3"
        )
        XCTAssertEqual(
            try engine.render("{{ regex_findall_index('a1b2c3', '[0-9]', 1) }}"),
            "2"
        )
        XCTAssertEqual(
            try engine.render(
                "{{ ['light.kitchen', 'sensor.temp'] | select('match', 'light\\\\.') | list | join(',') }}"
            ),
            "light.kitchen"
        )
    }

    func testLabelsOverload() throws {
        let engine = try TestSupport.makeEngine()
        let all = try engine.render("{{ labels() | join(',') }}")
        XCTAssertTrue(all.contains("lighting"))
        XCTAssertTrue(all.contains("main"))
        XCTAssertEqual(
            try engine.render("{{ labels('dev_kitchen_light') | join(',') }}"),
            "lighting"
        )
        XCTAssertEqual(
            try engine.render("{{ labels('kitchen') | join(',') }}"),
            "main"
        )
    }
}
