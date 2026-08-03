import Foundation
import JinjaCore

/// A Home Assistant entity state suitable for template evaluation.
public struct HAEntityState: Sendable, Hashable, Codable {
    public var entityID: String
    public var state: String
    public var attributes: [String: HAJSONValue]
    public var lastChanged: Date?
    public var lastUpdated: Date?
    public var contextID: String?

    public init(
        entityID: String,
        state: String,
        attributes: [String: HAJSONValue] = [:],
        lastChanged: Date? = nil,
        lastUpdated: Date? = nil,
        contextID: String? = nil
    ) {
        self.entityID = entityID
        self.state = state
        self.attributes = attributes
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
        self.contextID = contextID
    }

    public var domain: String {
        entityID.split(separator: ".", maxSplits: 1).first.map(String.init) ?? entityID
    }

    public var objectID: String {
        let parts = entityID.split(separator: ".", maxSplits: 1)
        return parts.count == 2 ? String(parts[1]) : entityID
    }

    public var friendlyName: String {
        if case let .string(name) = attributes["friendly_name"] {
            return name
        }
        return objectID.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public var hasValue: Bool {
        state != "unknown" && state != "unavailable"
    }

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
        case contextID = "context_id"
    }

    /// Jinja object representing this entity (`state`, `attributes`, …).
    public func asJinjaValue(timeZone: TimeZone = .current) throws -> Value {
        var attrs = OrderedDictionary<ObjectKey, Value>()
        for key in attributes.keys.sorted() {
            attrs[.string(key)] = try attributes[key]!.asJinjaValue()
        }

        var dict = OrderedDictionary<ObjectKey, Value>()
        dict[.string("entity_id")] = .string(entityID)
        dict[.string("state")] = .string(state)
        dict[.string("domain")] = .string(domain)
        dict[.string("object_id")] = .string(objectID)
        dict[.string("name")] = .string(friendlyName)
        dict[.string("attributes")] = .object(attrs)
        if let lastChanged {
            dict[.string("last_changed")] = .datetime(lastChanged, timeZone: timeZone)
        }
        if let lastUpdated {
            dict[.string("last_updated")] = .datetime(lastUpdated, timeZone: timeZone)
        }
        // HA: `{{ states.domain.object }}` prints the state string while still
        // allowing `.state` / `.attributes` member access.
        return .object(dict, stringRepresentation: state)
    }
}

/// JSON-compatible value used for entity attributes and registry metadata.
public enum HAJSONValue: Sendable, Hashable, Codable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([HAJSONValue])
    case object([String: HAJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([HAJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: HAJSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    public func asJinjaValue() throws -> Value {
        switch self {
        case .null: return .null
        case .bool(let value): return .boolean(value)
        case .int(let value): return .int(value)
        case .double(let value): return .double(value)
        case .string(let value): return .string(value)
        case .array(let values):
            return .array(try values.map { try $0.asJinjaValue() })
        case .object(let object):
            var dict = OrderedDictionary<ObjectKey, Value>()
            for key in object.keys.sorted() {
                dict[.string(key)] = try object[key]!.asJinjaValue()
            }
            return .object(dict)
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        default: return nil
        }
    }
}
