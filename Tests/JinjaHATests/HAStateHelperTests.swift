import JinjaHA
import XCTest

final class HAStateHelperTests: XCTestCase {
    func testIsStateFalseSafeForMissing() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("{{ is_state('light.ghost', 'on') }}")
        XCTAssertEqual(output, "false")
    }

    func testIsStateListMatch() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("{{ is_state('light.kitchen', ['on', 'home']) }}")
        XCTAssertEqual(output, "true")
    }

    func testStateAttrAndHasValue() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render(
            "{{ state_attr('light.kitchen', 'brightness') }}|{{ has_value('binary_sensor.front_door') }}|{{ has_value('sensor.missing_like') }}"
        )
        XCTAssertEqual(output, "180|true|false")
    }

    func testExpandGroup() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("{% for s in expand('group.lights') %}{{ s.entity_id }};{% endfor %}")
        XCTAssertEqual(output, "light.kitchen;")
    }

    func testAreaHelpers() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render(
            "{{ area_name('kitchen') }}|{{ area_id('Kitchen') }}|{{ area_devices('kitchen') | join(',') }}"
        )
        XCTAssertEqual(output, "Kitchen|kitchen|dev_kitchen_light")
    }

    func testDeviceHelpers() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render(
            "{{ device_name('light.kitchen') }}|{{ device_attr('light.kitchen', 'manufacturer') }}"
        )
        XCTAssertEqual(output, "Kitchen Light Device|Example")
    }

    func testDatetimeHelpers() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render(
            "{{ as_timestamp(1700000000) }}|{{ timedelta(hours=1).total_seconds() }}"
        )
        XCTAssertEqual(output, "1700000000.0|3600.0")
    }

    func testTodayAtAndTimeSince() throws {
        let engine = try TestSupport.makeEngine()
        let output = try engine.render("{{ time_since(1699996400) }}")
        XCTAssertTrue(output.contains("hour") || output.contains("minute") || output.contains("second"))
    }

    func testSnapshotMergeAndRegistryDecode() throws {
        let base = HAStateSnapshot(entities: [
            "sensor.temp": HAEntityState(entityID: "sensor.temp", state: "22")
        ])
        let metaJSON = Data("""
        [{"entity_id":"sensor.temp","platform":"mqtt","config_entry_id":"e1","hidden_by":"user","name":"Temp"}]
        """.utf8)
        let entriesJSON = Data("""
        [{"entry_id":"e1","domain":"mqtt","title":"MQTT"}]
        """.utf8)
        let snapshot = try base
            .merging(entityMeta: HAStateSnapshot.entityMetaFromRegistryJSON(metaJSON))
            .merging(configEntries: HAStateSnapshot.configEntriesFromJSON(entriesJSON))
            .merging(repairIssues: [
                HARepairIssue(domain: "mqtt", issueID: "bad", severity: "warning")
            ])
            .withHomeLocation(latitude: 1, longitude: 2)

        XCTAssertEqual(snapshot.entityMeta["sensor.temp"]?.hidden, true)
        XCTAssertEqual(snapshot.configEntries["e1"]?.domain, "mqtt")
        XCTAssertEqual(snapshot.repairIssues.count, 1)
        XCTAssertEqual(snapshot.latitude, 1)

        let engine = HATemplateEngine(snapshot: snapshot)
        XCTAssertEqual(try engine.render("{{ is_hidden_entity('sensor.temp') }}"), "true")
        XCTAssertEqual(try engine.render("{{ config_entry_attr('e1', 'domain') }}"), "mqtt")
    }
}
