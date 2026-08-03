import Foundation
import JinjaCore

/// Home Assistant helpers added in Phase 4 (iif, math/string/regex, floor_entities, …).
enum HAHelpers {
    static func register(into env: Environment, snapshot: HAStateSnapshot) {
        registerBoth("iif", makeIif(), into: env)
        registerBoth("is_number", makeIsNumber(), into: env)
        registerBoth("slugify", makeSlugify(), into: env)
        registerBoth("average", makeAverage(), into: env)
        registerBoth("floor_entities", makeFloorEntities(snapshot: snapshot), into: env)

        registerBoth("regex_match", makeRegexMatch(search: false), into: env)
        registerBoth("regex_search", makeRegexMatch(search: true), into: env)
        registerBoth("regex_replace", makeRegexReplace(), into: env)
        registerBoth("regex_findall", makeRegexFindall(), into: env)
        registerBoth("regex_findall_index", makeRegexFindallIndex(), into: env)

        // Jinja tests used by select()/reject() and `is …`.
        env.registerTest("is_number", makeIsNumber())
        env.registerTest("is_defined", makeIsDefined())
        env.registerTest("defined", makeIsDefined())
        env.registerTest("match", makeRegexMatch(search: false))
        env.registerTest("search", makeRegexMatch(search: true))
    }

    private static func registerBoth(
        _ name: String,
        _ function: @escaping JinjaFunction,
        into env: Environment
    ) {
        env[name] = .function(function)
        env.registerFilter(name, function)
    }

    // MARK: - iif

    /// `iif(condition, if_true=True, if_false=False, if_none=None)`
    /// Filter form: `condition | iif(if_true, if_false, if_none)`
    private static func makeIif() -> JinjaFunction {
        { args, kwargs, _ in
            let condition = try requireValue(args, kwargs, name: "condition", index: 0)
            let ifTrue = optionalValue(args, kwargs, name: "if_true", index: 1) ?? .boolean(true)
            let ifFalse = optionalValue(args, kwargs, name: "if_false", index: 2) ?? .boolean(false)
            let ifNone = optionalValue(args, kwargs, name: "if_none", index: 3)

            if condition.isNull || condition.isUndefined {
                return ifNone ?? ifFalse
            }
            return condition.isTruthy ? ifTrue : ifFalse
        }
    }

    // MARK: - is_defined / is_number

    /// Only `undefined` is "not defined" — `null`/`None` is defined (Jinja semantics).
    private static func makeIsDefined() -> JinjaFunction {
        { args, _, _ in
            guard let first = args.first else { return .boolean(false) }
            return .boolean(!first.isUndefined)
        }
    }

    private static func makeIsNumber() -> JinjaFunction {
        { args, _, _ in
            guard let first = args.first else { return .boolean(false) }
            return .boolean(finiteNumber(from: first) != nil)
        }
    }

    // MARK: - slugify

    private static func makeSlugify() -> JinjaFunction {
        { args, kwargs, _ in
            let raw = try requireValue(args, kwargs, name: "value", index: 0)
            let separator = stringArg(args, kwargs, name: "separator", index: 1) ?? "_"
            let text = raw.description
            return .string(slugify(text, separator: separator))
        }
    }

    static func slugify(_ text: String, separator: String = "_") -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        var result = ""
        var pendingSeparator = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingSeparator, !result.isEmpty {
                    result += separator
                }
                pendingSeparator = false
                result += String(scalar).lowercased()
            } else {
                pendingSeparator = true
            }
        }
        return result
    }

    // MARK: - average

    private static func makeAverage() -> JinjaFunction {
        { args, kwargs, _ in
            let defaultValue = kwargs["default"]
            var numbers: [Double] = []

            if args.count == 1, case let .array(items) = args[0] {
                for item in items {
                    guard let number = finiteNumber(from: item) else {
                        if let defaultValue { return defaultValue }
                        throw HATemplateError.jinja("average() requires numeric values")
                    }
                    numbers.append(number)
                }
            } else {
                for arg in args {
                    guard let number = finiteNumber(from: arg) else {
                        if let defaultValue { return defaultValue }
                        throw HATemplateError.jinja("average() requires numeric values")
                    }
                    numbers.append(number)
                }
            }

            guard !numbers.isEmpty else {
                if let defaultValue { return defaultValue }
                throw HATemplateError.jinja("average() of empty sequence")
            }
            let mean = numbers.reduce(0, +) / Double(numbers.count)
            return .double(mean)
        }
    }

    // MARK: - floor_entities

    private static func makeFloorEntities(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let lookup = try requireString(args, kwargs, name: "floor_id_or_name", index: 0)
            let floorID: String
            if let floor = snapshot.floors.first(where: { $0.floorID == lookup || $0.name == lookup }) {
                floorID = floor.floorID
            } else {
                return .array([])
            }
            let areaIDs = Set(snapshot.areas.filter { $0.floorID == floorID }.map(\.areaID))
            var entityIDs = Set<String>()
            for areaID in areaIDs {
                let deviceEntityIDs = snapshot.devices.filter { $0.areaID == areaID }.flatMap(\.entities)
                entityIDs.formUnion(deviceEntityIDs)
                for entity in snapshot.entities.values {
                    if case let .string(id) = entity.attributes["area_id"], id == areaID {
                        entityIDs.insert(entity.entityID)
                    }
                }
            }
            return .array(entityIDs.sorted().map(Value.string))
        }
    }

    // MARK: - Regex

    private static func makeRegexMatch(search: Bool) -> JinjaFunction {
        { args, kwargs, _ in
            let value = try requireValue(args, kwargs, name: "value", index: 0).description
            let pattern = try requireString(args, kwargs, name: "find", index: 1)
            let ignoreCase = boolArg(args, kwargs, name: "ignorecase", index: 2) ?? false
            let regex = try compileRegex(pattern, ignoreCase: ignoreCase)
            let range = NSRange(value.startIndex..., in: value)
            guard let match = regex.firstMatch(in: value, options: [], range: range) else {
                return .boolean(false)
            }
            if search {
                return .boolean(true)
            }
            // regex_match / match: must match at the beginning
            return .boolean(match.range.location == 0)
        }
    }

    private static func makeRegexReplace() -> JinjaFunction {
        { args, kwargs, _ in
            let value = try requireValue(args, kwargs, name: "value", index: 0).description
            let pattern = try requireString(args, kwargs, name: "find", index: 1)
            let replacement = try requireString(args, kwargs, name: "replace", index: 2)
            let ignoreCase = boolArg(args, kwargs, name: "ignorecase", index: 3) ?? false
            let regex = try compileRegex(pattern, ignoreCase: ignoreCase)
            let range = NSRange(value.startIndex..., in: value)
            let result = regex.stringByReplacingMatches(
                in: value,
                options: [],
                range: range,
                withTemplate: replacement
            )
            return .string(result)
        }
    }

    private static func makeRegexFindall() -> JinjaFunction {
        { args, kwargs, _ in
            let value = try requireValue(args, kwargs, name: "value", index: 0).description
            let pattern = try requireString(args, kwargs, name: "find", index: 1)
            let ignoreCase = boolArg(args, kwargs, name: "ignorecase", index: 2) ?? false
            let matches = try findAllMatches(in: value, pattern: pattern, ignoreCase: ignoreCase)
            return .array(matches.map(Value.string))
        }
    }

    private static func makeRegexFindallIndex() -> JinjaFunction {
        { args, kwargs, _ in
            let value = try requireValue(args, kwargs, name: "value", index: 0).description
            let pattern = try requireString(args, kwargs, name: "find", index: 1)
            let index = Int(numberArg(args, kwargs, name: "index", index: 2) ?? 0)
            let ignoreCase = boolArg(args, kwargs, name: "ignorecase", index: 3) ?? false
            let matches = try findAllMatches(in: value, pattern: pattern, ignoreCase: ignoreCase)
            guard index >= 0, index < matches.count else {
                return .string("")
            }
            return .string(matches[index])
        }
    }

    private static func compileRegex(_ pattern: String, ignoreCase: Bool) throws -> NSRegularExpression {
        var options: NSRegularExpression.Options = []
        if ignoreCase { options.insert(.caseInsensitive) }
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            throw HATemplateError.jinja("Invalid regular expression: \(pattern)")
        }
    }

    private static func findAllMatches(in value: String, pattern: String, ignoreCase: Bool) throws -> [String] {
        let regex = try compileRegex(pattern, ignoreCase: ignoreCase)
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, options: [], range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: value) else { return nil }
            if match.numberOfRanges > 1, let groupRange = Range(match.range(at: 1), in: value) {
                return String(value[groupRange])
            }
            return String(value[swiftRange])
        }
    }

    // MARK: - Shared

    private static func optionalValue(
        _ args: [Value],
        _ kwargs: [String: Value],
        name: String,
        index: Int
    ) -> Value? {
        if index < args.count { return args[index] }
        return kwargs[name]
    }

    private static func finiteNumber(from value: Value) -> Double? {
        switch value {
        case .int(let int):
            return Double(int)
        case .double(let double):
            return double.isFinite ? double : nil
        case .string(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let double = Double(trimmed), double.isFinite else { return nil }
            return double
        case .boolean:
            return nil
        default:
            return nil
        }
    }
}
