import Foundation
import Jinja

enum HAGlobals {
    static func register(into env: Environment, snapshot: HAStateSnapshot, limits: HATemplateLimits) {
        env["__states__"] = .function(makeStatesFunction(snapshot: snapshot))
        env["states"] = makeStatesObject(snapshot: snapshot)
        env["is_state"] = .function(makeIsState(snapshot: snapshot))
        env["is_state_attr"] = .function(makeIsStateAttr(snapshot: snapshot))
        env["state_attr"] = .function(makeStateAttr(snapshot: snapshot))
        env["has_value"] = .function(makeHasValue(snapshot: snapshot))
        env["expand"] = .function(makeExpand(snapshot: snapshot))

        env["now"] = .function(makeNow(snapshot: snapshot, utc: false))
        env["utcnow"] = .function(makeNow(snapshot: snapshot, utc: true))
        env["as_timestamp"] = .function(makeAsTimestamp(snapshot: snapshot))
        env["as_datetime"] = .function(makeAsDatetime(snapshot: snapshot))
        env["as_local"] = .function(makeAsLocal(snapshot: snapshot))
        env["as_timedelta"] = .function(makeAsTimedelta())
        env["timedelta"] = .function(makeTimedelta())
        env["time_since"] = .function(makeTimeSince(snapshot: snapshot, until: false))
        env["time_until"] = .function(makeTimeSince(snapshot: snapshot, until: true))
        env["today_at"] = .function(makeTodayAt(snapshot: snapshot))
        env["timestamp_custom"] = .function(makeTimestampCustom(snapshot: snapshot))
        env["timestamp_local"] = .function(makeTimestampLocal(snapshot: snapshot, utc: false))
        env["timestamp_utc"] = .function(makeTimestampLocal(snapshot: snapshot, utc: true))
        env["strptime"] = .function(makeStrptime())

        env["areas"] = .function(makeAreas(snapshot: snapshot))
        env["area_id"] = .function(makeAreaID(snapshot: snapshot))
        env["area_name"] = .function(makeAreaName(snapshot: snapshot))
        env["area_entities"] = .function(makeAreaEntities(snapshot: snapshot))
        env["area_devices"] = .function(makeAreaDevices(snapshot: snapshot))

        env["device_id"] = .function(makeDeviceID(snapshot: snapshot))
        env["device_name"] = .function(makeDeviceName(snapshot: snapshot))
        env["device_entities"] = .function(makeDeviceEntities(snapshot: snapshot))
        env["device_attr"] = .function(makeDeviceAttr(snapshot: snapshot))
        env["is_device_attr"] = .function(makeIsDeviceAttr(snapshot: snapshot))

        env["floors"] = .function(makeFloors(snapshot: snapshot))
        env["floor_id"] = .function(makeFloorID(snapshot: snapshot))
        env["floor_name"] = .function(makeFloorName(snapshot: snapshot))
        env["floor_areas"] = .function(makeFloorAreas(snapshot: snapshot))

        env["labels"] = .function(makeLabels(snapshot: snapshot))
        env["label_id"] = .function(makeLabelID(snapshot: snapshot))
        env["label_name"] = .function(makeLabelName(snapshot: snapshot))
        env["label_entities"] = .function(makeLabelEntities(snapshot: snapshot))
        env["label_devices"] = .function(makeLabelDevices(snapshot: snapshot))
        env["label_areas"] = .function(makeLabelAreas(snapshot: snapshot))

        // Safer range with hard cap (see preprocess → `__safe_range__`).
        env["__safe_range__"] = .function(makeSafeRange(limits: limits))
    }

    // MARK: - States

    private static func makeStatesFunction(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, _ in
            if args.isEmpty {
                let values = try snapshot.entities.values
                    .sorted { $0.entityID < $1.entityID }
                    .map { try $0.asJinjaValue() }
                return .array(values)
            }
            let entityID = try requireString(args, kwargs, name: "entity_id", index: 0)
            let withUnit = boolArg(args, kwargs, name: "with_unit", index: 1) ?? false
            let rounded = boolArg(args, kwargs, name: "rounded", index: 2)
            guard let entity = snapshot.entity(id: entityID) else {
                return .string("unknown")
            }
            var text = entity.state
            if rounded == true || (withUnit && rounded == nil), let number = Double(entity.state) {
                text = String(format: "%g", (number * 100).rounded() / 100)
            }
            if withUnit, case let .string(unit) = entity.attributes["unit_of_measurement"] {
                text += " \(unit)"
            }
            return .string(text)
        }
    }

    private static func makeStatesObject(snapshot: HAStateSnapshot) -> Value {
        var byDomain = OrderedDictionary<ObjectKey, Value>()
        let grouped = Dictionary(grouping: snapshot.entities.values, by: \.domain)
        for domain in grouped.keys.sorted() {
            var entities = OrderedDictionary<ObjectKey, Value>()
            for entity in grouped[domain]!.sorted(by: { $0.objectID < $1.objectID }) {
                // Store state string at leaf so `{{ states.sensor.temp }}` prints the state.
                // Nested attributes remain available via a companion object under `__entity__`
                // is awkward — instead attach common fields as object and rely on `.state`.
                // Prefer object with CustomStringConvertible limitation: use object.
                if let value = try? entity.asJinjaValue() {
                    entities[.string(entity.objectID)] = value
                }
            }
            byDomain[.string(domain)] = .object(entities)
        }
        return .object(byDomain)
    }

    private static func makeIsState(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, _ in
            let entityID = try requireString(args, kwargs, name: "entity_id", index: 0)
            let expected = try requireValue(args, kwargs, name: "state", index: 1)
            let actual = snapshot.stateString(for: entityID)
            switch expected {
            case .string(let value):
                return .boolean(actual == value)
            case .array(let values):
                let matches = values.contains { value in
                    if case .string(let s) = value { return s == actual }
                    return value.description == actual
                }
                return .boolean(matches)
            default:
                return .boolean(actual == expected.description)
            }
        }
    }

    private static func makeIsStateAttr(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, _ in
            let entityID = try requireString(args, kwargs, name: "entity_id", index: 0)
            let attr = try requireString(args, kwargs, name: "name", index: 1)
            let expected = try requireValue(args, kwargs, name: "value", index: 2)
            guard let entity = snapshot.entity(id: entityID),
                  let attribute = entity.attributes[attr]
            else {
                return .boolean(false)
            }
            let actual = try attribute.asJinjaValue()
            return .boolean(actual.isEquivalent(to: expected) || actual.description == expected.description)
        }
    }

    private static func makeStateAttr(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, _ in
            let entityID = try requireString(args, kwargs, name: "entity_id", index: 0)
            let attr = try requireString(args, kwargs, name: "name", index: 1)
            guard let entity = snapshot.entity(id: entityID),
                  let attribute = entity.attributes[attr]
            else {
                return .null
            }
            return try attribute.asJinjaValue()
        }
    }

    private static func makeHasValue(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, _ in
            let entityID = try requireString(args, kwargs, name: "entity_id", index: 0)
            guard let entity = snapshot.entity(id: entityID) else {
                return .boolean(false)
            }
            return .boolean(entity.hasValue)
        }
    }

    private static func makeExpand(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            var entityIDs: [String] = []
            for arg in args {
                switch arg {
                case .string(let id):
                    entityIDs.append(contentsOf: expandOne(id, snapshot: snapshot))
                case .array(let values):
                    for value in values {
                        if case .string(let id) = value {
                            entityIDs.append(contentsOf: expandOne(id, snapshot: snapshot))
                        } else if case .object(let obj) = value,
                                  case .string(let id) = obj[.string("entity_id")] {
                            entityIDs.append(contentsOf: expandOne(id, snapshot: snapshot))
                        }
                    }
                case .object(let obj):
                    if case .string(let id) = obj[.string("entity_id")] {
                        entityIDs.append(contentsOf: expandOne(id, snapshot: snapshot))
                    }
                default:
                    break
                }
            }
            let unique = Array(Set(entityIDs)).sorted()
            let values = try unique.compactMap { snapshot.entity(id: $0) }.map { try $0.asJinjaValue() }
            return .array(values)
        }
    }

    private static func expandOne(_ id: String, snapshot: HAStateSnapshot) -> [String] {
        guard let entity = snapshot.entity(id: id) else { return [id] }
        if entity.domain == "group", case let .array(members) = entity.attributes["entity_id"] {
            return members.compactMap(\.stringValue).flatMap { expandOne($0, snapshot: snapshot) }
        }
        if case let .array(members) = entity.attributes["entity_id"] {
            let nested = members.compactMap(\.stringValue)
            if !nested.isEmpty { return nested.flatMap { expandOne($0, snapshot: snapshot) } }
        }
        return [id]
    }

    // MARK: - Datetime

    private static func makeNow(snapshot: HAStateSnapshot, utc: Bool) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { _, _, _ in
            .string(formatDate(snapshot.currentDate, timeZone: utc ? TimeZone(secondsFromGMT: 0)! : snapshot.timeZone))
        }
    }

    private static func makeAsTimestamp(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            guard let first = args.first, let date = parseDate(first, snapshot: snapshot) else {
                return .null
            }
            return .double(date.timeIntervalSince1970)
        }
    }

    private static func makeAsDatetime(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            guard let first = args.first, let date = parseDate(first, snapshot: snapshot) else {
                return .null
            }
            return .string(formatDate(date, timeZone: snapshot.timeZone))
        }
    }

    private static func makeAsLocal(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            guard let first = args.first, let date = parseDate(first, snapshot: snapshot) else {
                return .null
            }
            return .string(formatDate(date, timeZone: snapshot.timeZone))
        }
    }

    private static func makeAsTimedelta() -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            guard let first = args.first else { return .null }
            switch first {
            case .string(let text):
                return .double(parseISO8601Duration(text) ?? 0)
            case .int(let value):
                return .double(Double(value))
            case .double(let value):
                return .double(value)
            default:
                return .null
            }
        }
    }

    private static func makeTimedelta() -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, _ in
            let days = numberArg(args, kwargs, name: "days", index: 0) ?? 0
            let seconds = numberArg(args, kwargs, name: "seconds", index: 1) ?? 0
            let microseconds = numberArg(args, kwargs, name: "microseconds", index: 2) ?? 0
            let milliseconds = numberArg(args, kwargs, name: "milliseconds", index: 3) ?? 0
            let minutes = numberArg(args, kwargs, name: "minutes", index: 4) ?? 0
            let hours = numberArg(args, kwargs, name: "hours", index: 5) ?? 0
            let weeks = numberArg(args, kwargs, name: "weeks", index: 6) ?? 0
            let total =
                weeks * 604_800
                + days * 86_400
                + hours * 3_600
                + minutes * 60
                + seconds
                + milliseconds / 1000
                + microseconds / 1_000_000
            return .double(total)
        }
    }

    private static func makeTimeSince(snapshot: HAStateSnapshot, until: Bool) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            guard let first = args.first, let date = parseDate(first, snapshot: snapshot) else {
                return .string("")
            }
            let now = snapshot.currentDate
            let interval = until ? date.timeIntervalSince(now) : now.timeIntervalSince(date)
            return .string(humanize(abs(interval)))
        }
    }

    private static func makeTodayAt(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let timeText = (args.first.flatMap { value -> String? in
                if case .string(let s) = value { return s }
                return nil
            }) ?? "00:00"
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = snapshot.timeZone
            let parts = timeText.split(separator: ":").map(String.init)
            let hour = Int(parts.count > 0 ? parts[0] : "0") ?? 0
            let minute = Int(parts.count > 1 ? parts[1] : "0") ?? 0
            let second = Int(parts.count > 2 ? parts[2] : "0") ?? 0
            let now = snapshot.currentDate
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute
            components.second = second
            let date = calendar.date(from: components) ?? now
            return .string(formatDate(date, timeZone: snapshot.timeZone))
        }
    }

    private static func makeTimestampCustom(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, _ in
            guard let first = args.first, let date = parseDate(first, snapshot: snapshot) else {
                return .null
            }
            let format = stringArg(args, kwargs, name: "format", index: 1) ?? "%Y-%m-%d %H:%M:%S"
            let local = boolArg(args, kwargs, name: "local", index: 2) ?? true
            let tz = local ? snapshot.timeZone : TimeZone(secondsFromGMT: 0)!
            return .string(strftime(format, date: date, timeZone: tz))
        }
    }

    private static func makeTimestampLocal(snapshot: HAStateSnapshot, utc: Bool) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            guard let first = args.first, let date = parseDate(first, snapshot: snapshot) else {
                return .null
            }
            let tz = utc ? TimeZone(secondsFromGMT: 0)! : snapshot.timeZone
            return .string(formatDate(date, timeZone: tz))
        }
    }

    private static func makeStrptime() -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            guard args.count >= 2,
                  case .string(let text) = args[0],
                  case .string(let format) = args[1]
            else {
                return .null
            }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = pythonFormatToDateFormat(format)
            guard let date = formatter.date(from: text) else { return .null }
            return .string(ISO8601DateFormatter().string(from: date))
        }
    }

    // MARK: - Areas / devices / floors / labels

    private static func makeAreas(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { _, _, _ in .array(snapshot.areas.map { .string($0.areaID) }) }
    }

    private static func makeAreaID(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "value", index: 0)
            if let area = snapshot.areas.first(where: { $0.areaID == lookup || $0.name == lookup || $0.aliases.contains(lookup) }) {
                return .string(area.areaID)
            }
            if let entity = snapshot.entity(id: lookup),
               case let .string(areaID) = entity.attributes["area_id"] {
                return .string(areaID)
            }
            if let device = snapshot.devices.first(where: { $0.id == lookup || $0.displayName == lookup }),
               let areaID = device.areaID {
                return .string(areaID)
            }
            return .null
        }
    }

    private static func makeAreaName(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "value", index: 0)
            if let area = snapshot.areas.first(where: { $0.areaID == lookup || $0.name == lookup }) {
                return .string(area.name)
            }
            return .null
        }
    }

    private static func makeAreaEntities(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let areaID = try requireString(args, [:], name: "area_id", index: 0)
            let deviceEntityIDs = Set(
                snapshot.devices.filter { $0.areaID == areaID }.flatMap(\.entities)
            )
            let fromAttrs = snapshot.entities.values.compactMap { entity -> String? in
                if case let .string(id) = entity.attributes["area_id"], id == areaID {
                    return entity.entityID
                }
                return nil
            }
            let all = Array(deviceEntityIDs.union(fromAttrs)).sorted()
            return .array(all.map(Value.string))
        }
    }

    private static func makeAreaDevices(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let areaID = try requireString(args, [:], name: "area_id", index: 0)
            let ids = snapshot.devices.filter { $0.areaID == areaID }.map(\.id).sorted()
            return .array(ids.map(Value.string))
        }
    }

    private static func makeDeviceID(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "value", index: 0)
            if let device = snapshot.devices.first(where: { $0.id == lookup || $0.displayName == lookup }) {
                return .string(device.id)
            }
            if let device = snapshot.devices.first(where: { $0.entities.contains(lookup) }) {
                return .string(device.id)
            }
            return .null
        }
    }

    private static func makeDeviceName(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "value", index: 0)
            if let device = snapshot.devices.first(where: { $0.id == lookup || $0.entities.contains(lookup) }) {
                return .string(device.displayName)
            }
            return .null
        }
    }

    private static func makeDeviceEntities(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "device_id", index: 0)
            let entities = snapshot.devices.first(where: { $0.id == lookup })?.entities.sorted() ?? []
            return .array(entities.map(Value.string))
        }
    }

    private static func makeDeviceAttr(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let deviceID = try requireString(args, [:], name: "device_or_entity_id", index: 0)
            let attr = try requireString(args, [:], name: "attr_name", index: 1)
            guard let device = snapshot.devices.first(where: { $0.id == deviceID || $0.entities.contains(deviceID) }) else {
                return .null
            }
            switch attr {
            case "manufacturer": return device.manufacturer.map(Value.string) ?? .null
            case "model": return device.model.map(Value.string) ?? .null
            case "name": return .string(device.displayName)
            case "area_id": return device.areaID.map(Value.string) ?? .null
            default: return .null
            }
        }
    }

    private static func makeIsDeviceAttr(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, env in
            let value = try makeDeviceAttr(snapshot: snapshot)(Array(args.prefix(2)), kwargs, env)
            let expected = try requireValue(args, kwargs, name: "value", index: 2)
            return .boolean(value.isEquivalent(to: expected) || value.description == expected.description)
        }
    }

    private static func makeFloors(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { _, _, _ in .array(snapshot.floors.map { .string($0.floorID) }) }
    }

    private static func makeFloorID(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "value", index: 0)
            if let floor = snapshot.floors.first(where: { $0.floorID == lookup || $0.name == lookup }) {
                return .string(floor.floorID)
            }
            if let area = snapshot.areas.first(where: { $0.areaID == lookup || $0.name == lookup }),
               let floorID = area.floorID {
                return .string(floorID)
            }
            return .null
        }
    }

    private static func makeFloorName(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "value", index: 0)
            if let floor = snapshot.floors.first(where: { $0.floorID == lookup || $0.name == lookup }) {
                return .string(floor.name)
            }
            return .null
        }
    }

    private static func makeFloorAreas(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let floorID = try requireString(args, [:], name: "floor_id", index: 0)
            let ids = snapshot.areas.filter { $0.floorID == floorID }.map(\.areaID).sorted()
            return .array(ids.map(Value.string))
        }
    }

    private static func makeLabels(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { _, _, _ in .array(snapshot.labels.map { .string($0.labelID) }) }
    }

    private static func makeLabelID(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "value", index: 0)
            if let label = snapshot.labels.first(where: { $0.labelID == lookup || $0.name == lookup }) {
                return .string(label.labelID)
            }
            return .null
        }
    }

    private static func makeLabelName(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let lookup = try requireString(args, [:], name: "value", index: 0)
            if let label = snapshot.labels.first(where: { $0.labelID == lookup || $0.name == lookup }) {
                return .string(label.name)
            }
            return .null
        }
    }

    private static func makeLabelEntities(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let labelID = try requireString(args, [:], name: "label_id", index: 0)
            let ids = snapshot.entities.values.compactMap { entity -> String? in
                if case let .array(labels) = entity.attributes["labels"],
                   labels.contains(where: { $0.stringValue == labelID }) {
                    return entity.entityID
                }
                return nil
            }.sorted()
            return .array(ids.map(Value.string))
        }
    }

    private static func makeLabelDevices(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let labelID = try requireString(args, [:], name: "label_id", index: 0)
            let ids = snapshot.devices.filter { $0.labels.contains(labelID) }.map(\.id).sorted()
            return .array(ids.map(Value.string))
        }
    }

    private static func makeLabelAreas(snapshot: HAStateSnapshot) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, _, _ in
            let labelID = try requireString(args, [:], name: "label_id", index: 0)
            let ids = snapshot.areas.filter { $0.labels.contains(labelID) }.map(\.areaID).sorted()
            return .array(ids.map(Value.string))
        }
    }

    private static func makeSafeRange(limits: HATemplateLimits) -> @Sendable ([Value], [String: Value], Environment) throws -> Value {
        { args, kwargs, env in
            let builtIn = try Globals.range(args, kwargs, env)
            guard case .array(let values) = builtIn else { return builtIn }
            if values.count > limits.maxRangeSize {
                throw HATemplateError.rangeTooLarge(limit: limits.maxRangeSize)
            }
            return builtIn
        }
    }
}

// MARK: - Argument helpers

func requireValue(_ args: [Value], _ kwargs: [String: Value], name: String, index: Int) throws -> Value {
    if index < args.count { return args[index] }
    if let value = kwargs[name] { return value }
    throw HATemplateError.jinja("Missing argument '\(name)'")
}

func requireString(_ args: [Value], _ kwargs: [String: Value], name: String, index: Int) throws -> String {
    let value = try requireValue(args, kwargs, name: name, index: index)
    if case .string(let string) = value { return string }
    throw HATemplateError.jinja("Argument '\(name)' must be a string")
}

func stringArg(_ args: [Value], _ kwargs: [String: Value], name: String, index: Int) -> String? {
    if index < args.count, case .string(let string) = args[index] { return string }
    if case .string(let string) = kwargs[name] { return string }
    return nil
}

func boolArg(_ args: [Value], _ kwargs: [String: Value], name: String, index: Int) -> Bool? {
    let value: Value?
    if index < args.count { value = args[index] }
    else { value = kwargs[name] }
    guard let value else { return nil }
    if case .boolean(let bool) = value { return bool }
    return nil
}

func numberArg(_ args: [Value], _ kwargs: [String: Value], name: String, index: Int) -> Double? {
    let value: Value?
    if index < args.count { value = args[index] }
    else { value = kwargs[name] }
    guard let value else { return nil }
    switch value {
    case .int(let int): return Double(int)
    case .double(let double): return double
    default: return nil
    }
}

func parseDate(_ value: Value, snapshot: HAStateSnapshot) -> Date? {
    switch value {
    case .int(let int):
        return Date(timeIntervalSince1970: TimeInterval(int))
    case .double(let double):
        return Date(timeIntervalSince1970: double)
    case .string(let string):
        if let double = Double(string) {
            return Date(timeIntervalSince1970: double)
        }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: string) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        // Treat bare datetime-looking strings as local.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = snapshot.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: string)
    default:
        return nil
    }
}

func formatDate(_ date: Date, timeZone: TimeZone) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = timeZone
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

func humanize(_ interval: TimeInterval) -> String {
    let seconds = Int(interval.rounded())
    if seconds < 60 { return "\(seconds) seconds" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes) minutes" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours) hours" }
    let days = hours / 24
    return "\(days) days"
}

func parseISO8601Duration(_ text: String) -> Double? {
    // Minimal ISO8601 duration parser: PT#H#M#S / P#DT#H#M#S
    guard text.hasPrefix("P") else { return nil }
    var total: Double = 0
    var number = ""
    var inTime = false
    for char in text.dropFirst() {
        if char == "T" {
            inTime = true
            continue
        }
        if char.isNumber || char == "." {
            number.append(char)
            continue
        }
        guard let value = Double(number) else { return nil }
        number = ""
        switch char {
        case "D": total += value * 86_400
        case "H": total += value * 3_600
        case "M": total += inTime ? value * 60 : value * 2_592_000
        case "S": total += value
        case "W": total += value * 604_800
        default: return nil
        }
    }
    return total
}

func pythonFormatToDateFormat(_ format: String) -> String {
    format
        .replacingOccurrences(of: "%Y", with: "yyyy")
        .replacingOccurrences(of: "%m", with: "MM")
        .replacingOccurrences(of: "%d", with: "dd")
        .replacingOccurrences(of: "%H", with: "HH")
        .replacingOccurrences(of: "%M", with: "mm")
        .replacingOccurrences(of: "%S", with: "ss")
}

func strftime(_ format: String, date: Date, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = pythonFormatToDateFormat(format)
    return formatter.string(from: date)
}
