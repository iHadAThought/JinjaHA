import Foundation
import JinjaHA
import XCTest

final class CatalogHelpersTests: XCTestCase {
    func testEncodingAndMath() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        XCTAssertEqual(try engine.render("{{ clamp(12, 0, 10) }}"), "10.0")
        XCTAssertEqual(try engine.render("{{ bitwise_and(12, 5) }}"), "4")
        XCTAssertEqual(try engine.render("{{ median([1, 3, 2]) }}"), "2.0")
        XCTAssertEqual(try engine.render("{{ ord('A') }}"), "65")
        let sha1 = try engine.render("{{ sha1('hi') }}")
        XCTAssertEqual(sha1.count, 40)
        let hex = try engine.render("{{ from_hex('6869') }}")
        XCTAssertEqual(hex, "hi")
    }

    func testSetOpsAndZip() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        XCTAssertEqual(
            try engine.render("{{ union(['a','b'], ['b','c']) | sort | join(',') }}"),
            "a,b,c"
        )
        XCTAssertEqual(
            try engine.render("{{ zip([1,2], ['a','b']) | length }}"),
            "2"
        )
        XCTAssertEqual(
            try engine.render("{{ flatten([[1],[2,3]]) | join(',') }}"),
            "1,2,3"
        )
    }

    func testRegistryAndRepairs() throws {
        let snapshot = HAStateSnapshot(
            entities: [
                "sensor.temp": HAEntityState(
                    entityID: "sensor.temp",
                    state: "on",
                    attributes: ["friendly_name": .string("Temp")]
                )
            ],
            entityMeta: [
                "sensor.temp": HAEntityMeta(
                    entityID: "sensor.temp",
                    platform: "mqtt",
                    configEntryID: "entry1",
                    hidden: true,
                    name: "Kitchen Temp"
                )
            ],
            configEntries: [
                "entry1": HAConfigEntry(entryID: "entry1", domain: "mqtt", title: "MQTT")
            ],
            repairIssues: [
                HARepairIssue(domain: "mqtt", issueID: "bad", severity: "warning", isFixable: true)
            ],
            translationStrings: [
                "on": "Allumé",
                "component.sensor.entity_component.on.name": "On (fr)",
            ]
        )
        let engine = HATemplateEngine(snapshot: snapshot)
        XCTAssertEqual(try engine.render("{{ is_hidden_entity('sensor.temp') }}"), "true")
        XCTAssertEqual(try engine.render("{{ entity_name('sensor.temp') }}"), "Kitchen Temp")
        XCTAssertEqual(try engine.render("{{ config_entry_id('sensor.temp') }}"), "entry1")
        XCTAssertEqual(try engine.render("{{ config_entry_attr('entry1', 'domain') }}"), "mqtt")
        XCTAssertTrue(try engine.render("{{ issues() | length }}").contains("1"))
        XCTAssertEqual(try engine.render("{{ state_translated('sensor.temp') }}"), "On (fr)")
    }

    func testPackUnpackRoundTrip() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        let packed = try engine.render("{{ 259 | pack('>H') }}")
        XCTAssertEqual(packed, "0103")
        let unpacked = try engine.render("{{ '0103' | unpack('>H') }}")
        XCTAssertEqual(unpacked, "259")
    }

    func testAsFunctionAndStatisticalMode() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        let doubled = try engine.render(
            """
            {% macro macro_double(value, returns) %}{{ returns(value * 2) }}{% endmacro %}
            {{ as_function(macro_double)(5) }}
            """
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(doubled, "10")

        let mapped = try engine.render(
            """
            {% macro macro_double(value, returns) %}{{ returns(value * 2) }}{% endmacro %}
            {% set double = as_function(macro_double) %}
            {{ [1, 2, 3] | map('apply', double) | list | join(',') }}
            """
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(mapped, "2,4,6")

        XCTAssertEqual(try engine.render("{{ statistical_mode([1, 2, 2, 3]) }}"), "2")
    }

    func testPhase1CatalogLeftovers() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        XCTAssertTrue(try engine.render("{{ tau }}").hasPrefix("6.28"))
        XCTAssertEqual(try engine.render("{{ wrap(12, 0, 10) }}"), "2.0")
        XCTAssertEqual(try engine.render("{{ remap(50, 0, 100, 0, 10) }}"), "5.0")
        XCTAssertEqual(try engine.render("{{ remap(120, 0, 100, 0, 10, edges='clamp') }}"), "10.0")
        XCTAssertEqual(try engine.render("{{ bool('yes') }}"), "true")
        XCTAssertEqual(try engine.render("{{ 'off' | bool }}"), "false")
        XCTAssertEqual(try engine.render("{{ bool('maybe', default=false) }}"), "false")
        XCTAssertEqual(try engine.render("{{ '21.5' | add(2.5) }}"), "24.0")
        XCTAssertEqual(try engine.render("{{ 'bad' | add(1, default=0) }}"), "0")
        XCTAssertEqual(try engine.render("{{ '4' | multiply(2.5) }}"), "10.0")
        XCTAssertEqual(try engine.render("{{ 1 | ordinal }}"), "1st")
        XCTAssertEqual(try engine.render("{{ 11 | ordinal }}, {{ 22 | ordinal }}"), "11th, 22nd")
        XCTAssertEqual(try engine.render("{{ 4 is even }}"), "true")
        XCTAssertEqual(try engine.render("{{ 5 is odd }}"), "true")
        XCTAssertEqual(try engine.render("{{ 9 is divisibleby(3) }}"), "true")
        XCTAssertEqual(try engine.render("{{ 1536 | filesizeformat }}"), "1.5 kB")
        XCTAssertEqual(try engine.render("{{ 'on' | bool | iif('yes', 'no') }}"), "yes")
        XCTAssertEqual(try engine.render("{{ state_attr is defined }}"), "true")
    }

    func testVersionAndContains() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        XCTAssertEqual(try engine.render("{{ version('2024.12.1').major }}"), "2024")
        XCTAssertEqual(try engine.render("{{ contains(['a','b'], 'a') }}"), "true")
        XCTAssertEqual(try engine.render("{{ version('2024.12') >= '2024.1' }}"), "true")
        XCTAssertEqual(try engine.render("{{ version('2023.12') < '2024.1' }}"), "true")
    }

    func testPhase2PackVersionTrans() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        XCTAssertEqual(try engine.render("{{ (-5) | pack('<h') | unpack('<h') }}"), "-5")
        XCTAssertEqual(
            try engine.render("{{ [1, 2] | pack('>HH') | unpack('>HH') | join(',') }}"),
            "1,2"
        )
        XCTAssertEqual(try engine.render("{{ as_datetime('nope', default='fallback') }}"), "fallback")

        let env = HATemplateEngine(
            snapshot: HAStateSnapshot(translationStrings: [
                "Hello %(user)s!": "Bonjour %(user)s!"
            ])
        )
        XCTAssertEqual(
            try env.render("{% trans user='Ada' %}Hello {{ user }}!{% endtrans %}"),
            "Bonjour Ada!"
        )
    }
}
