import CryptoKit
import Foundation
import JinjaCore

/// Extra HA helpers: math, geo, encoding/hash — high-impact for dashboard markdown.
enum HAExtraHelpers {
    static func register(into env: Environment, snapshot: HAStateSnapshot) {
        env["pi"] = .double(Double.pi)
        env["e"] = .double(M_E)
        registerBoth("log", makeLog(), into: env)
        registerBoth("sin", makeNamedMath("sin"), into: env)
        registerBoth("cos", makeNamedMath("cos"), into: env)
        registerBoth("tan", makeNamedMath("tan"), into: env)
        registerBoth("sqrt", makeNamedMath("sqrt"), into: env)
        registerBoth("distance", makeDistance(snapshot: snapshot), into: env)
        registerBoth("closest", makeClosest(snapshot: snapshot), into: env)
        registerBoth("base64_encode", makeBase64Encode(), into: env)
        registerBoth("base64_decode", makeBase64Decode(), into: env)
        registerBoth("md5", makeHash(md5: true), into: env)
        registerBoth("sha256", makeHash(md5: false), into: env)
        registerBoth("urlencode", makeURLEncode(), into: env)
    }

    private static func registerBoth(
        _ name: String,
        _ function: @escaping JinjaFunction,
        into env: Environment
    ) {
        env[name] = .function(function)
        env.registerFilter(name, function)
    }

    private static func makeNamedMath(_ name: String) -> JinjaFunction {
        { args, kwargs, _ in
            guard let number = numberArg(args, kwargs, name: "value", index: 0) else {
                return .null
            }
            switch name {
            case "sin": return .double(sin(number))
            case "cos": return .double(cos(number))
            case "tan": return .double(tan(number))
            case "sqrt": return .double(sqrt(number))
            default: return .null
            }
        }
    }

    private static func makeLog() -> JinjaFunction {
        { args, kwargs, _ in
            guard let value = numberArg(args, kwargs, name: "value", index: 0) else {
                return .null
            }
            let base = numberArg(args, kwargs, name: "base", index: 1) ?? M_E
            guard value > 0, base > 0, base != 1 else { return .null }
            return .double(log(value) / log(base))
        }
    }

    private static func makeDistance(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let points = try resolveLatLonArgs(args, kwargs, snapshot: snapshot)
            guard points.count >= 2 else { return .null }
            let km = haversineKm(
                lat1: points[0].0, lon1: points[0].1,
                lat2: points[1].0, lon2: points[1].1
            )
            return .double(km)
        }
    }

    private static func makeClosest(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            // closest(entity_id | lat, lon?, …) — HA: closest(State, …) or closest(lat, lon, entities)
            // Support: closest('device_tracker.x') relative to home, or closest(lat, lon, entity_id…)
            let home = homeCoordinate(snapshot)
            var origin: (Double, Double)?
            var entityIDs: [String] = []

            if args.count >= 2,
               numberArg(args, kwargs, name: "lat", index: 0) != nil,
               numberArg(args, kwargs, name: "lon", index: 1) != nil
            {
                origin = (numberArg(args, kwargs, name: "lat", index: 0)!, numberArg(args, kwargs, name: "lon", index: 1)!)
                for value in args.dropFirst(2) {
                    if case .string(let id) = value { entityIDs.append(id) }
                    else if case .array(let list) = value {
                        entityIDs.append(contentsOf: list.compactMap(\.stringValue))
                    }
                }
            } else if let first = args.first, case .string(let id) = first {
                origin = home
                entityIDs = [id]
                for value in args.dropFirst() {
                    if case .string(let more) = value { entityIDs.append(more) }
                    else if case .array(let list) = value {
                        entityIDs.append(contentsOf: list.compactMap(\.stringValue))
                    }
                }
            } else {
                return .null
            }

            guard let origin else { return .null }
            var bestID: String?
            var bestDistance = Double.infinity
            for id in entityIDs {
                guard let entity = snapshot.entity(id: id),
                      let lat = coordinate(from: entity, key: "latitude"),
                      let lon = coordinate(from: entity, key: "longitude")
                else { continue }
                let d = haversineKm(lat1: origin.0, lon1: origin.1, lat2: lat, lon2: lon)
                if d < bestDistance {
                    bestDistance = d
                    bestID = id
                }
            }
            guard let bestID, let entity = snapshot.entity(id: bestID) else { return .null }
            return try entity.asJinjaValue(timeZone: snapshot.timeZone)
        }
    }

    private static func makeBase64Encode() -> JinjaFunction {
        { args, kwargs, _ in
            let text = try requireString(args, kwargs, name: "value", index: 0)
            let data = Data(text.utf8)
            return .string(data.base64EncodedString())
        }
    }

    private static func makeBase64Decode() -> JinjaFunction {
        { args, kwargs, _ in
            let text = try requireString(args, kwargs, name: "value", index: 0)
            guard let data = Data(base64Encoded: text),
                  let decoded = String(data: data, encoding: .utf8)
            else {
                return .null
            }
            return .string(decoded)
        }
    }

    private static func makeHash(md5: Bool) -> JinjaFunction {
        { args, kwargs, _ in
            let text = try requireString(args, kwargs, name: "value", index: 0)
            let data = Data(text.utf8)
            if md5 {
                let digest = Insecure.MD5.hash(data: data)
                return .string(digest.map { String(format: "%02x", $0) }.joined())
            }
            let digest = SHA256.hash(data: data)
            return .string(digest.map { String(format: "%02x", $0) }.joined())
        }
    }

    private static func makeURLEncode() -> JinjaFunction {
        { args, kwargs, _ in
            let text = try requireString(args, kwargs, name: "value", index: 0)
            let encoded =
                text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            return .string(encoded)
        }
    }

    // MARK: - Geo helpers

    private static func homeCoordinate(_ snapshot: HAStateSnapshot) -> (Double, Double)? {
        guard let lat = snapshot.latitude, let lon = snapshot.longitude else { return nil }
        return (lat, lon)
    }

    private static func coordinate(from entity: HAEntityState, key: String) -> Double? {
        switch entity.attributes[key] {
        case .double(let value): return value
        case .int(let value): return Double(value)
        case .string(let text): return Double(text)
        default: return nil
        }
    }

    private static func resolveLatLonArgs(
        _ args: [Value],
        _ kwargs: [String: Value],
        snapshot: HAStateSnapshot
    ) throws -> [(Double, Double)] {
        var points: [(Double, Double)] = []
        if args.isEmpty {
            if let home = homeCoordinate(snapshot) { points.append(home) }
            return points
        }
        // distance(entity_a, entity_b) or distance(lat1, lon1, lat2, lon2) or distance(entity)
        if args.count == 1, case .string(let id) = args[0], let entity = snapshot.entity(id: id) {
            if let home = homeCoordinate(snapshot),
               let lat = coordinate(from: entity, key: "latitude"),
               let lon = coordinate(from: entity, key: "longitude")
            {
                return [home, (lat, lon)]
            }
            return []
        }
        if args.count >= 2, case .string(let a) = args[0], case .string(let b) = args[1],
           let ea = snapshot.entity(id: a), let eb = snapshot.entity(id: b),
           let lat1 = coordinate(from: ea, key: "latitude"),
           let lon1 = coordinate(from: ea, key: "longitude"),
           let lat2 = coordinate(from: eb, key: "latitude"),
           let lon2 = coordinate(from: eb, key: "longitude")
        {
            return [(lat1, lon1), (lat2, lon2)]
        }
        if args.count >= 4,
           let lat1 = numberArg(args, kwargs, name: "lat1", index: 0),
           let lon1 = numberArg(args, kwargs, name: "lon1", index: 1),
           let lat2 = numberArg(args, kwargs, name: "lat2", index: 2),
           let lon2 = numberArg(args, kwargs, name: "lon2", index: 3)
        {
            return [(lat1, lon1), (lat2, lon2)]
        }
        return points
    }

    private static func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180
        let a = sin(Δφ / 2) * sin(Δφ / 2)
            + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
}

private extension Value {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}
