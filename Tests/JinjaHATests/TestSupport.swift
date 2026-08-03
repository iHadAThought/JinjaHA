import Foundation
import JinjaHA
import XCTest

enum TestSupport {
    static var fixturesDirectory: URL {
        Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
    }

    static func loadSnapshot(named name: String = "basic") throws -> HAStateSnapshot {
        let url = fixturesDirectory
            .appendingPathComponent("snapshots")
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        var snapshot = try HAStateSnapshot.fromStatesJSON(data)
        snapshot.areas = [
            HAArea(areaID: "kitchen", name: "Kitchen", floorID: "downstairs", labels: ["main"])
        ]
        snapshot.devices = [
            HADevice(
                id: "dev_kitchen_light",
                name: "Kitchen Light Device",
                areaID: "kitchen",
                manufacturer: "Example",
                model: "Bulb",
                labels: ["lighting"],
                entities: ["light.kitchen"]
            )
        ]
        snapshot.floors = [HAFloor(floorID: "downstairs", name: "Downstairs")]
        snapshot.labels = [
            HALabel(labelID: "lighting", name: "Lighting"),
            HALabel(labelID: "main", name: "Main"),
        ]
        snapshot.now = Date(timeIntervalSince1970: 1_700_000_000)
        snapshot.timeZoneIdentifier = "UTC"
        return snapshot
    }

    static func makeEngine(snapshot: HAStateSnapshot? = nil, limits: HATemplateLimits = .default) throws -> HATemplateEngine {
        HATemplateEngine(snapshot: try snapshot ?? loadSnapshot(), limits: limits)
    }
}
