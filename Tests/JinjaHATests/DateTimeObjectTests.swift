import Foundation
import JinjaHA
import XCTest

final class DateTimeObjectTests: XCTestCase {
    func testNowAttributesAndIsoformat() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13:20 UTC
        let snapshot = HAStateSnapshot(
            timeZoneIdentifier: "UTC",
            now: now
        )
        let engine = HATemplateEngine(snapshot: snapshot)
        let hour = try engine.render("{{ now().hour }}")
        let iso = try engine.render("{{ now().isoformat() }}")
        XCTAssertEqual(hour, "22")
        XCTAssertTrue(iso.contains("2023-11-14"), iso)
    }

    func testDatetimeSubtractTotalSeconds() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let changed = Date(timeIntervalSince1970: 1_699_996_400) // 1 hour earlier
        let entity = HAEntityState(
            entityID: "sensor.work",
            state: "on",
            lastChanged: changed,
            lastUpdated: changed
        )
        let snapshot = HAStateSnapshot(
            entities: ["sensor.work": entity],
            timeZoneIdentifier: "UTC",
            now: now
        )
        let engine = HATemplateEngine(snapshot: snapshot)
        let output = try engine.render(
            "{{ (now() - states.sensor.work.last_changed).total_seconds() }}"
        )
        XCTAssertEqual(Double(output) ?? -1, 3600, accuracy: 0.01)
    }

    func testTimedeltaConstructorAndAdd() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = HAStateSnapshot(timeZoneIdentifier: "UTC", now: now)
        let engine = HATemplateEngine(snapshot: snapshot)
        let seconds = try engine.render("{{ timedelta(hours=1).total_seconds() }}")
        XCTAssertEqual(seconds, "3600.0")
        let shifted = try engine.render("{{ (now() - timedelta(hours=1)).timestamp() }}")
        XCTAssertEqual(Double(shifted) ?? 0, 1_699_996_400, accuracy: 0.01)
    }

    func testNowMinusTimedeltaReturnsDatetime() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = HAStateSnapshot(timeZoneIdentifier: "UTC", now: now)
        let engine = HATemplateEngine(snapshot: snapshot)
        let output = try engine.render("{{ (now() - timedelta(hours=1)).timestamp() }}")
        XCTAssertEqual(Double(output) ?? 0, 1_699_996_400, accuracy: 0.01)
    }

    func testCombinedParityStrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let changed = Date(timeIntervalSince1970: 1_699_996_400)
        let entity = HAEntityState(
            entityID: "sensor.work",
            state: "on",
            lastChanged: changed
        )
        let snapshot = HAStateSnapshot(
            entities: ["sensor.work": entity],
            timeZoneIdentifier: "UTC",
            now: now
        )
        let engine = HATemplateEngine(snapshot: snapshot)
        let output = try engine.render(
            "{{ now().hour }}|{{ (now() - states.sensor.work.last_changed).total_seconds() }}|{{ sqrt(16) }}|{{ base64_encode('ab') }}"
        )
        XCTAssertEqual(output, "22|3600.0|4.0|YWI=")
    }

    func testTodayAtReturnsDatetime() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = HAStateSnapshot(timeZoneIdentifier: "UTC", now: now)
        let engine = HATemplateEngine(snapshot: snapshot)
        let hour = try engine.render("{{ today_at('06:30').hour }}")
        let minute = try engine.render("{{ today_at('06:30').minute }}")
        XCTAssertEqual(hour, "6")
        XCTAssertEqual(minute, "30")
    }

    func testRelativeTime() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = HAStateSnapshot(timeZoneIdentifier: "UTC", now: now)
        let engine = HATemplateEngine(snapshot: snapshot)
        let output = try engine.render("{{ relative_time(1699996400) }}")
        XCTAssertTrue(output.contains("hour") || output.contains("minute") || output.contains("second"), output)
    }
}

final class ExtraHelpersTests: XCTestCase {
    func testMathHelpers() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        XCTAssertEqual(try engine.render("{{ sqrt(9) }}"), "3.0")
        XCTAssertEqual(try engine.render("{{ log(100, 10) }}"), "2.0")
        let pi = try engine.render("{{ pi }}")
        XCTAssertTrue(pi.hasPrefix("3.14"), pi)
    }

    func testEncodingHelpers() throws {
        let engine = HATemplateEngine(snapshot: HAStateSnapshot())
        XCTAssertEqual(try engine.render("{{ base64_encode('hi') }}"), "aGk=")
        XCTAssertEqual(try engine.render("{{ base64_decode('aGk=') }}"), "hi")
        XCTAssertEqual(try engine.render("{{ md5('hi') }}"), "49f68a5c8493ec2c0bf489821c21fc3b")
        let sha = try engine.render("{{ sha256('hi') }}")
        XCTAssertEqual(sha.count, 64)
    }

    func testDistanceAndClosest() throws {
        let homeLat = 35.78
        let homeLon = -78.64
        let near = HAEntityState(
            entityID: "device_tracker.near",
            state: "home",
            attributes: [
                "latitude": .double(35.79),
                "longitude": .double(-78.65),
            ]
        )
        let far = HAEntityState(
            entityID: "device_tracker.far",
            state: "not_home",
            attributes: [
                "latitude": .double(40.0),
                "longitude": .double(-74.0),
            ]
        )
        let snapshot = HAStateSnapshot(
            entities: [
                near.entityID: near,
                far.entityID: far,
            ],
            latitude: homeLat,
            longitude: homeLon
        )
        let engine = HATemplateEngine(snapshot: snapshot)
        let distance = try engine.render("{{ distance('device_tracker.near') }}")
        XCTAssertGreaterThan(Double(distance) ?? 0, 0)
        let closest = try engine.render(
            "{{ closest('device_tracker.near', 'device_tracker.far').entity_id }}"
        )
        XCTAssertEqual(closest, "device_tracker.near")
    }
}
