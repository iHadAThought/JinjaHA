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

    func testVersionAndContains() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        XCTAssertEqual(try engine.render("{{ version('2024.12.1').major }}"), "2024")
        XCTAssertEqual(try engine.render("{{ contains(['a','b'], 'a') }}"), "true")
    }
}
