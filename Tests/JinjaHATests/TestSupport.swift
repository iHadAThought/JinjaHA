import Foundation
import JinjaHA
import XCTest

enum TestSupport {
    static var fixturesDirectory: URL {
        Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
    }

    static var compatibilityHomeAssistantDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // JinjaHATests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Compatibility/home-assistant")
    }

    /// Pins Work Audit board templates to a fixed calendar day in UTC.
    static var workAuditPinnedNow: Date {
        // 2026-08-02T12:00:00Z — after past shifts / paychecks, before upcoming Aug 10+.
        Date(timeIntervalSince1970: 1_785_672_000)
    }

    static func loadSnapshot(named name: String = "basic") throws -> HAStateSnapshot {
        let url = fixturesDirectory
            .appendingPathComponent("snapshots")
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        var snapshot = try HAStateSnapshot.fromStatesJSON(data)
        if name == "work_audit" {
            snapshot.now = workAuditPinnedNow
            snapshot.timeZoneIdentifier = "UTC"
            return snapshot
        }
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

    static func workAuditTemplateURLs() throws -> [URL] {
        let dir = compatibilityHomeAssistantDirectory
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        return files
            .filter { $0.lastPathComponent.hasPrefix("work_audit_") && $0.pathExtension == "jinja" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
