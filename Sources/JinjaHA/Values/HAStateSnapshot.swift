import Foundation

/// Immutable snapshot of HA world state used during template evaluation.
///
/// Apps populate this from WebSocket `get_states` / `state_changed` and registry
/// responses. The library does not own the HA connection.
public struct HAStateSnapshot: Sendable, Hashable, Codable {
    public var entities: [String: HAEntityState]
    public var areas: [HAArea]
    public var devices: [HADevice]
    public var floors: [HAFloor]
    public var labels: [HALabel]
    public var timeZoneIdentifier: String
    public var now: Date?

    public init(
        entities: [String: HAEntityState] = [:],
        areas: [HAArea] = [],
        devices: [HADevice] = [],
        floors: [HAFloor] = [],
        labels: [HALabel] = [],
        timeZoneIdentifier: String = TimeZone.current.identifier,
        now: Date? = nil
    ) {
        self.entities = entities
        self.areas = areas
        self.devices = devices
        self.floors = floors
        self.labels = labels
        self.timeZoneIdentifier = timeZoneIdentifier
        self.now = now
    }

    public func entity(id entityID: String) -> HAEntityState? {
        entities[entityID]
    }

    public func stateString(for entityID: String) -> String {
        entities[entityID]?.state ?? "unknown"
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    public var currentDate: Date {
        now ?? Date()
    }

    public static func fromStatesJSON(_ data: Data) throws -> HAStateSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date")
        }
        let list = try decoder.decode([HAEntityState].self, from: data)
        var map: [String: HAEntityState] = [:]
        for entity in list {
            map[entity.entityID] = entity
        }
        return HAStateSnapshot(entities: map)
    }
}

public struct HAArea: Sendable, Hashable, Codable {
    public var areaID: String
    public var name: String
    public var floorID: String?
    public var labels: [String]
    public var aliases: [String]

    public init(
        areaID: String,
        name: String,
        floorID: String? = nil,
        labels: [String] = [],
        aliases: [String] = []
    ) {
        self.areaID = areaID
        self.name = name
        self.floorID = floorID
        self.labels = labels
        self.aliases = aliases
    }

    enum CodingKeys: String, CodingKey {
        case areaID = "area_id"
        case name
        case floorID = "floor_id"
        case labels
        case aliases
    }
}

public struct HADevice: Sendable, Hashable, Codable {
    public var id: String
    public var name: String?
    public var nameByUser: String?
    public var areaID: String?
    public var manufacturer: String?
    public var model: String?
    public var labels: [String]
    public var entities: [String]

    public init(
        id: String,
        name: String? = nil,
        nameByUser: String? = nil,
        areaID: String? = nil,
        manufacturer: String? = nil,
        model: String? = nil,
        labels: [String] = [],
        entities: [String] = []
    ) {
        self.id = id
        self.name = name
        self.nameByUser = nameByUser
        self.areaID = areaID
        self.manufacturer = manufacturer
        self.model = model
        self.labels = labels
        self.entities = entities
    }

    public var displayName: String {
        nameByUser ?? name ?? id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameByUser = "name_by_user"
        case areaID = "area_id"
        case manufacturer
        case model
        case labels
        case entities
    }
}

public struct HAFloor: Sendable, Hashable, Codable {
    public var floorID: String
    public var name: String
    public var level: Int?

    public init(floorID: String, name: String, level: Int? = nil) {
        self.floorID = floorID
        self.name = name
        self.level = level
    }

    enum CodingKeys: String, CodingKey {
        case floorID = "floor_id"
        case name
        case level
    }
}

public struct HALabel: Sendable, Hashable, Codable {
    public var labelID: String
    public var name: String

    public init(labelID: String, name: String) {
        self.labelID = labelID
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case labelID = "label_id"
        case name
    }
}
