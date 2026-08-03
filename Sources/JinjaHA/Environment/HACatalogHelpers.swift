import CryptoKit
import Foundation
import JinjaCore

/// Catalog-driven HA helpers: encoding, entities/registry, repairs, translations,
/// math extras, functional utilities, and collection set ops.
enum HACatalogHelpers {
    static func register(into env: Environment, snapshot: HAStateSnapshot) {
        // Encoding
        registerBoth("from_hex", makeFromHex(), into: env)
        registerBoth("pack", makePack(), into: env)
        registerBoth("unpack", makeUnpack(), into: env)
        registerBoth("sha1", makeSHA(kind: .sha1), into: env)
        registerBoth("sha512", makeSHA(kind: .sha512), into: env)

        // Entities / registry
        registerBoth("is_hidden_entity", makeIsHiddenEntity(snapshot: snapshot), into: env)
        registerBoth("entity_name", makeEntityName(snapshot: snapshot), into: env)
        registerBoth("integration_entities", makeIntegrationEntities(snapshot: snapshot), into: env)
        registerBoth("config_entry_id", makeConfigEntryID(snapshot: snapshot), into: env)
        registerBoth("config_entry_attr", makeConfigEntryAttr(snapshot: snapshot), into: env)

        // Repairs / translations
        registerBoth("issues", makeIssues(snapshot: snapshot), into: env)
        registerBoth("issue", makeIssue(snapshot: snapshot), into: env)
        registerBoth("state_translated", makeStateTranslated(snapshot: snapshot), into: env)
        registerBoth("state_attr_translated", makeStateAttrTranslated(snapshot: snapshot), into: env)

        // Math extras
        registerBoth("acos", makeNamedUnaryMath("acos"), into: env)
        registerBoth("asin", makeNamedUnaryMath("asin"), into: env)
        registerBoth("atan", makeNamedUnaryMath("atan"), into: env)
        registerBoth("atan2", makeAtan2(), into: env)
        registerBoth("clamp", makeClamp(), into: env)
        registerBoth("remap", makeRemap(), into: env)
        registerBoth("wrap", makeWrap(), into: env)
        registerBoth("bitwise_and", makeBitwise("and"), into: env)
        registerBoth("bitwise_or", makeBitwise("or"), into: env)
        registerBoth("bitwise_xor", makeBitwise("xor"), into: env)
        registerBoth("median", makeMedian(), into: env)
        registerBoth("statistical_mode", makeStatisticalMode(), into: env)

        // Type conversion / strings (HA-flavored)
        registerBoth("bool", makeBool(), into: env)
        registerBoth("add", makeAdd(), into: env)
        registerBoth("multiply", makeMultiply(), into: env)
        registerBoth("ordinal", makeOrdinal(), into: env)

        // Functional
        registerBoth("apply", makeApply(), into: env)
        registerBoth("as_function", makeAsFunction(), into: env)
        registerBoth("zip", makeZip(), into: env)
        registerBoth("version", makeVersion(), into: env)
        registerBoth("ord", makeOrd(), into: env)
        registerBoth("contains", makeContains(), into: env)

        // Collections
        registerBoth("union", makeSetOp(.union), into: env)
        registerBoth("intersect", makeSetOp(.intersect), into: env)
        registerBoth("difference", makeSetOp(.difference), into: env)
        registerBoth("symmetric_difference", makeSetOp(.symmetricDifference), into: env)
        registerBoth("flatten", makeFlatten(), into: env)
        registerBoth("combine", makeCombine(), into: env)
        registerBoth("shuffle", makeShuffle(), into: env)
        registerBoth("merge_response", makeMergeResponse(), into: env)
        registerBoth("set", makeSetConvert(), into: env)
        registerBoth("tuple", makeTupleConvert(), into: env)
    }

    private static func registerBoth(
        _ name: String,
        _ function: @escaping JinjaFunction,
        into env: Environment
    ) {
        env[name] = .function(function)
        env.registerFilter(name, function)
    }

    // MARK: - Encoding

    private static func makeFromHex() -> JinjaFunction {
        { args, kwargs, _ in
            let text = try requireString(args, kwargs, name: "value", index: 0)
                .replacingOccurrences(of: " ", with: "")
            var data = Data()
            var index = text.startIndex
            while index < text.endIndex {
                let next = text.index(index, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
                let byteText = String(text[index..<next])
                guard let byte = UInt8(byteText, radix: 16) else { return .null }
                data.append(byte)
                index = next
            }
            return .string(String(decoding: data, as: UTF8.self))
        }
    }

    private enum SHAKind { case sha1, sha512 }

    private static func makeSHA(kind: SHAKind) -> JinjaFunction {
        { args, kwargs, _ in
            let text = try requireString(args, kwargs, name: "value", index: 0)
            let data = Data(text.utf8)
            switch kind {
            case .sha1:
                let digest = Insecure.SHA1.hash(data: data)
                return .string(digest.map { String(format: "%02x", $0) }.joined())
            case .sha512:
                let digest = SHA512.hash(data: data)
                return .string(digest.map { String(format: "%02x", $0) }.joined())
            }
        }
    }

    /// Minimal Python-struct pack for common formats (`B`, `H`, `I`, `Q`, `f`, `d` + endian).
    private static func makePack() -> JinjaFunction {
        { args, kwargs, _ in
            let format = try requireString(args, kwargs, name: "format_string", index: 1)
            guard args.count >= 1 else { return .null }
            let value = args[0]
            guard let packed = packValue(value, format: format) else { return .null }
            return .string(packed.map { String(format: "%02x", $0) }.joined())
        }
    }

    private static func makeUnpack() -> JinjaFunction {
        { args, kwargs, _ in
            let format = try requireString(args, kwargs, name: "format_string", index: 1)
            let hexOrText = try requireString(args, kwargs, name: "value", index: 0)
            let data: Data
            if hexOrText.allSatisfy({ $0.isHexDigit }) && hexOrText.count % 2 == 0 {
                var bytes = Data()
                var i = hexOrText.startIndex
                while i < hexOrText.endIndex {
                    let j = hexOrText.index(i, offsetBy: 2)
                    bytes.append(UInt8(hexOrText[i..<j], radix: 16) ?? 0)
                    i = j
                }
                data = bytes
            } else {
                data = Data(hexOrText.utf8)
            }
            return unpackValue(data, format: format) ?? .null
        }
    }

    private static func packValue(_ value: Value, format: String) -> Data? {
        let (endian, code) = parseStructFormat(format)
        let number: Double? = {
            switch value {
            case .int(let i): return Double(i)
            case .double(let d): return d
            case .string(let s): return Double(s)
            default: return nil
            }
        }()
        guard let number else { return nil }
        var data = Data()
        switch code {
        case "B":
            data.append(UInt8(clamping: Int(number)))
        case "H":
            var v = UInt16(clamping: Int(number))
            if endian == .big { v = v.bigEndian } else { v = v.littleEndian }
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        case "I":
            var v = UInt32(clamping: Int(number))
            if endian == .big { v = v.bigEndian } else { v = v.littleEndian }
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        case "Q":
            var v = UInt64(clamping: Int(number))
            if endian == .big { v = v.bigEndian } else { v = v.littleEndian }
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        case "f":
            var v = Float(number)
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            if endian == .big { data.reverse() }
        case "d":
            var v = Double(number)
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            if endian == .big { data.reverse() }
        default:
            return nil
        }
        return data
    }

    private static func unpackValue(_ data: Data, format: String) -> Value? {
        let (endian, code) = parseStructFormat(format)
        switch code {
        case "B":
            guard let b = data.first else { return nil }
            return .int(Int(b))
        case "H":
            guard data.count >= 2 else { return nil }
            var v: UInt16 = 0
            _ = withUnsafeMutableBytes(of: &v) { data.copyBytes(to: $0, count: 2) }
            return .int(Int(endian == .big ? UInt16(bigEndian: v) : UInt16(littleEndian: v)))
        case "I":
            guard data.count >= 4 else { return nil }
            var v: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &v) { data.copyBytes(to: $0, count: 4) }
            return .int(Int(endian == .big ? UInt32(bigEndian: v) : UInt32(littleEndian: v)))
        case "Q":
            guard data.count >= 8 else { return nil }
            var v: UInt64 = 0
            _ = withUnsafeMutableBytes(of: &v) { data.copyBytes(to: $0, count: 8) }
            return .int(Int(endian == .big ? UInt64(bigEndian: v) : UInt64(littleEndian: v)))
        default:
            return .string(String(decoding: data, as: UTF8.self))
        }
    }

    private enum Endian { case big, little, native }

    private static func parseStructFormat(_ format: String) -> (Endian, String) {
        var endian: Endian = .native
        var code = format
        if let first = format.first {
            switch first {
            case ">": endian = .big; code = String(format.dropFirst())
            case "<": endian = .little; code = String(format.dropFirst())
            case "=", "@": endian = .native; code = String(format.dropFirst())
            case "!": endian = .big; code = String(format.dropFirst())
            default: break
            }
        }
        return (endian, code)
    }

    // MARK: - Entities

    private static func makeIsHiddenEntity(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let id = try requireString(args, kwargs, name: "entity_id", index: 0)
            return .boolean(snapshot.entityMeta[id]?.hidden == true)
        }
    }

    private static func makeEntityName(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let id = try requireString(args, kwargs, name: "entity_id", index: 0)
            if let name = snapshot.entityMeta[id]?.name ?? snapshot.entityMeta[id]?.originalName {
                return .string(name)
            }
            if let entity = snapshot.entity(id: id) {
                return .string(entity.friendlyName)
            }
            return .null
        }
    }

    private static func makeIntegrationEntities(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let key = try requireString(args, kwargs, name: "entity_id", index: 0)
            // HA accepts integration domain or config entry id.
            let ids = snapshot.entityMeta.values
                .filter { $0.platform == key || $0.configEntryID == key }
                .map(\.entityID)
                .sorted()
            if !ids.isEmpty {
                return .array(ids.map(Value.string))
            }
            // Fallback: match entity domain prefix when meta missing.
            let byDomain = snapshot.entities.keys
                .filter { $0.hasPrefix(key + ".") }
                .sorted()
            return .array(byDomain.map(Value.string))
        }
    }

    private static func makeConfigEntryID(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let id = try requireString(args, kwargs, name: "entity_id", index: 0)
            if let entry = snapshot.entityMeta[id]?.configEntryID {
                return .string(entry)
            }
            return .null
        }
    }

    private static func makeConfigEntryAttr(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let entryID = try requireString(args, kwargs, name: "config_entry_id", index: 0)
            let name = try requireString(args, kwargs, name: "name", index: 1)
            guard let entry = snapshot.configEntries[entryID] else { return .null }
            switch name {
            case "domain": return .string(entry.domain)
            case "title": return entry.title.map(Value.string) ?? .null
            case "unique_id": return entry.uniqueID.map(Value.string) ?? .null
            default:
                if let attr = entry.attributes[name] {
                    return try attr.asJinjaValue()
                }
                return .null
            }
        }
    }

    // MARK: - Repairs / translations

    private static func makeIssues(snapshot: HAStateSnapshot) -> JinjaFunction {
        { _, _, _ in
            .array(snapshot.repairIssues.map { issue in
                var dict = OrderedDictionary<ObjectKey, Value>()
                dict[.string("domain")] = .string(issue.domain)
                dict[.string("issue_id")] = .string(issue.issueID)
                if let severity = issue.severity {
                    dict[.string("severity")] = .string(severity)
                }
                dict[.string("is_fixable")] = .boolean(issue.isFixable)
                return .object(dict)
            })
        }
    }

    private static func makeIssue(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let domain = try requireString(args, kwargs, name: "domain", index: 0)
            let issueID = try requireString(args, kwargs, name: "issue_id", index: 1)
            guard let issue = snapshot.repairIssues.first(where: {
                $0.domain == domain && $0.issueID == issueID
            }) else { return .null }
            var dict = OrderedDictionary<ObjectKey, Value>()
            dict[.string("domain")] = .string(issue.domain)
            dict[.string("issue_id")] = .string(issue.issueID)
            if let severity = issue.severity {
                dict[.string("severity")] = .string(severity)
            }
            dict[.string("is_fixable")] = .boolean(issue.isFixable)
            return .object(dict)
        }
    }

    private static func makeStateTranslated(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let id = try requireString(args, kwargs, name: "entity_id", index: 0)
            let state = snapshot.stateString(for: id)
            let domain = id.split(separator: ".", maxSplits: 1).first.map(String.init) ?? id
            let key = "component.\(domain).entity_component.\(state).name"
            if let translated = snapshot.translationStrings[key] {
                return .string(translated)
            }
            if let translated = snapshot.translationStrings[state] {
                return .string(translated)
            }
            return .string(state)
        }
    }

    private static func makeStateAttrTranslated(snapshot: HAStateSnapshot) -> JinjaFunction {
        { args, kwargs, _ in
            let id = try requireString(args, kwargs, name: "entity_id", index: 0)
            let attr = try requireString(args, kwargs, name: "attr", index: 1)
            guard let entity = snapshot.entity(id: id),
                  let value = entity.attributes[attr]
            else { return .null }
            let text = try value.asJinjaValue().description
            if let translated = snapshot.translationStrings["\(id).\(attr).\(text)"]
                ?? snapshot.translationStrings[text]
            {
                return .string(translated)
            }
            return .string(text)
        }
    }

    // MARK: - Math

    private static func makeNamedUnaryMath(_ name: String) -> JinjaFunction {
        { args, kwargs, _ in
            guard let number = numberArg(args, kwargs, name: "value", index: 0) else {
                return .null
            }
            switch name {
            case "acos": return .double(acos(number))
            case "asin": return .double(asin(number))
            case "atan": return .double(atan(number))
            default: return .null
            }
        }
    }

    private static func makeAtan2() -> JinjaFunction {
        { args, kwargs, _ in
            guard let y = numberArg(args, kwargs, name: "y", index: 0),
                  let x = numberArg(args, kwargs, name: "x", index: 1)
            else { return .null }
            return .double(atan2(y, x))
        }
    }

    private static func makeClamp() -> JinjaFunction {
        { args, kwargs, _ in
            guard let value = numberArg(args, kwargs, name: "value", index: 0) else {
                return .null
            }
            let minV = numberArg(args, kwargs, name: "min", index: 1) ?? -.infinity
            let maxV = numberArg(args, kwargs, name: "max", index: 2) ?? .infinity
            return .double(min(max(value, minV), maxV))
        }
    }

    /// HA `wrap(value, min_value, max_value)` — half-open range `[min, max)`.
    private static func makeWrap() -> JinjaFunction {
        { args, kwargs, _ in
            guard let value = coerceDouble(args, kwargs, name: "value", index: 0),
                  let minV = coerceDouble(args, kwargs, name: "min_value", index: 1)
                    ?? coerceDouble(args, kwargs, name: "min", index: 1),
                  let maxV = coerceDouble(args, kwargs, name: "max_value", index: 2)
                    ?? coerceDouble(args, kwargs, name: "max", index: 2)
            else { return .null }
            let span = maxV - minV
            guard span > 0 else { return .null }
            var offset = (value - minV).truncatingRemainder(dividingBy: span)
            if offset < 0 { offset += span }
            return .double(offset + minV)
        }
    }

    /// HA `remap(value, in_min, in_max, out_min, out_max, steps=0, edges='none')`.
    private static func makeRemap() -> JinjaFunction {
        { args, kwargs, _ in
            guard var value = coerceDouble(args, kwargs, name: "value", index: 0),
                  let inMin = coerceDouble(args, kwargs, name: "in_min", index: 1),
                  let inMax = coerceDouble(args, kwargs, name: "in_max", index: 2),
                  let outMin = coerceDouble(args, kwargs, name: "out_min", index: 3),
                  let outMax = coerceDouble(args, kwargs, name: "out_max", index: 4)
            else { return .null }

            let inSpan = inMax - inMin
            guard inSpan != 0 else { return .null }

            let edges = (stringArg(args, kwargs, name: "edges", index: 6) ?? "none").lowercased()
            switch edges {
            case "clamp":
                value = min(max(value, min(inMin, inMax)), max(inMin, inMax))
            case "wrap":
                var offset = (value - inMin).truncatingRemainder(dividingBy: inSpan)
                if offset < 0 { offset += abs(inSpan) }
                value = offset + inMin
            case "mirror":
                let lo = min(inMin, inMax)
                let hi = max(inMin, inMax)
                let span = hi - lo
                if span > 0 {
                    var offset = (value - lo).truncatingRemainder(dividingBy: 2 * span)
                    if offset < 0 { offset += 2 * span }
                    value = offset <= span ? lo + offset : hi - (offset - span)
                }
            default:
                break
            }

            var mapped = outMin + ((value - inMin) / inSpan) * (outMax - outMin)
            let steps = Int(coerceDouble(args, kwargs, name: "steps", index: 5) ?? 0)
            if steps > 0 {
                let outSpan = outMax - outMin
                let stepSize = outSpan / Double(steps)
                let index = ((mapped - outMin) / stepSize).rounded()
                mapped = outMin + index * stepSize
            }
            return .double(mapped)
        }
    }

    /// HA `bool(value, default=…)`.
    private static func makeBool() -> JinjaFunction {
        { args, kwargs, _ in
            let value = try requireValue(args, kwargs, name: "value", index: 0)
            let defaultValue = optionalValue(args, kwargs, name: "default", index: 1)
            if let parsed = parseHABool(value) {
                return .boolean(parsed)
            }
            if let defaultValue { return defaultValue }
            throw HATemplateError.jinja("Value cannot be converted to bool")
        }
    }

    /// HA `add(value, amount, default=…)`.
    private static func makeAdd() -> JinjaFunction {
        { args, kwargs, _ in
            let value = try requireValue(args, kwargs, name: "value", index: 0)
            guard let amount = coerceDouble(args, kwargs, name: "amount", index: 1) else {
                throw HATemplateError.jinja("add() requires a numeric amount")
            }
            let defaultValue = optionalValue(args, kwargs, name: "default", index: 2)
            guard let number = coerceDoubleValue(value) else {
                if let defaultValue { return defaultValue }
                throw HATemplateError.jinja("Value cannot be converted for add()")
            }
            return .double(number + amount)
        }
    }

    /// HA `multiply(value, amount, default=…)`.
    private static func makeMultiply() -> JinjaFunction {
        { args, kwargs, _ in
            let value = try requireValue(args, kwargs, name: "value", index: 0)
            guard let amount = coerceDouble(args, kwargs, name: "amount", index: 1) else {
                throw HATemplateError.jinja("multiply() requires a numeric amount")
            }
            let defaultValue = optionalValue(args, kwargs, name: "default", index: 2)
            guard let number = coerceDoubleValue(value) else {
                if let defaultValue { return defaultValue }
                throw HATemplateError.jinja("Value cannot be converted for multiply()")
            }
            return .double(number * amount)
        }
    }

    /// HA `ordinal(value)` → `1st`, `2nd`, `3rd`, `11th`, …
    private static func makeOrdinal() -> JinjaFunction {
        { args, kwargs, _ in
            let value = try requireValue(args, kwargs, name: "value", index: 0)
            let number: Int
            switch value {
            case .int(let i):
                number = i
            case .double(let d):
                number = Int(d)
            case .string(let s):
                guard let parsed = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    return .string(s)
                }
                number = parsed
            default:
                return .string(value.description)
            }
            let absN = abs(number)
            let mod100 = absN % 100
            let suffix: String
            if (11...13).contains(mod100) {
                suffix = "th"
            } else {
                switch absN % 10 {
                case 1: suffix = "st"
                case 2: suffix = "nd"
                case 3: suffix = "rd"
                default: suffix = "th"
                }
            }
            return .string("\(number)\(suffix)")
        }
    }

    private static func makeBitwise(_ name: String) -> JinjaFunction {
        { args, kwargs, _ in
            guard let a = intArg(args, kwargs, index: 0),
                  let b = intArg(args, kwargs, index: 1)
            else { return .null }
            switch name {
            case "and": return .int(a & b)
            case "or": return .int(a | b)
            case "xor": return .int(a ^ b)
            default: return .null
            }
        }
    }

    private static func makeMedian() -> JinjaFunction {
        { args, kwargs, _ in
            var numbers: [Double] = []
            if let first = args.first, case .array(let items) = first {
                numbers = items.compactMap(doubleValue)
            } else {
                numbers = args.compactMap(doubleValue)
            }
            guard !numbers.isEmpty else { return .null }
            let sorted = numbers.sorted()
            let mid = sorted.count / 2
            if sorted.count % 2 == 0 {
                return .double((sorted[mid - 1] + sorted[mid]) / 2)
            }
            return .double(sorted[mid])
        }
    }

    private static func makeStatisticalMode() -> JinjaFunction {
        { args, _, _ in
            let items: [Value]
            if let first = args.first, case .array(let list) = first {
                items = list
            } else {
                items = args
            }
            guard !items.isEmpty else { return .null }
            var counts: [String: (Value, Int)] = [:]
            for item in items {
                let key = item.description
                let prior = counts[key]?.1 ?? 0
                counts[key] = (item, prior + 1)
            }
            let best = counts.values.max(by: { $0.1 < $1.1 })
            return best?.0 ?? .null
        }
    }

    // MARK: - Functional

    /// HA `as_function(macro)` — macros that accept a `returns` callback become callables.
    private static func makeAsFunction() -> JinjaFunction {
        { args, _, env in
            guard let first = args.first, case .macro(let macro) = first else {
                return .null
            }

            let wrapped: JinjaFunction = { callArgs, callKwargs, callEnv in
                final class ReturnBox: @unchecked Sendable {
                    var value: Value = .null
                    var didReturn = false
                }
                let box = ReturnBox()
                let returnsFn: JinjaFunction = { returnArgs, _, _ in
                    if let value = returnArgs.first {
                        box.value = value
                        box.didReturn = true
                    }
                    return .string("")
                }

                var kwargs = callKwargs
                var positional = callArgs
                if macro.parameters.contains("returns") {
                    kwargs["returns"] = .function(returnsFn)
                } else {
                    positional.append(.function(returnsFn))
                }

                _ = try Interpreter.callMacro(
                    macro: macro,
                    arguments: positional,
                    keywordArguments: kwargs,
                    env: callEnv
                )
                return box.didReturn ? box.value : .null
            }

            return .function(wrapped)
        }
    }

    private static func makeApply() -> JinjaFunction {
        { args, kwargs, env in
            guard args.count >= 2 else { return .null }
            let value = args[0]
            let fn = args[1]
            let rest = Array(args.dropFirst(2))
            switch fn {
            case .function(let call):
                return try call([value] + rest, kwargs, env)
            case .macro(let macro):
                // Convenience: apply(value, macro) via as_function semantics.
                guard case .function(let wrapped) = try makeAsFunction()([.macro(macro)], [:], env) else {
                    return .null
                }
                return try wrapped([value] + rest, kwargs, env)
            case .string(let name):
                if let filter = env.filters[name] {
                    return try filter([value] + rest, kwargs, env)
                }
                if case .function(let call) = env[name] {
                    return try call([value] + rest, kwargs, env)
                }
                return .null
            default:
                return .null
            }
        }
    }

    private static func makeZip() -> JinjaFunction {
        { args, _, _ in
            let arrays: [[Value]] = args.compactMap {
                if case .array(let items) = $0 { return items }
                return nil
            }
            guard !arrays.isEmpty else { return .array([]) }
            let count = arrays.map(\.count).min() ?? 0
            var result: [Value] = []
            for i in 0..<count {
                result.append(.array(arrays.map { $0[i] }))
            }
            return .array(result)
        }
    }

    private static func makeVersion() -> JinjaFunction {
        { args, kwargs, _ in
            let text = try requireString(args, kwargs, name: "value", index: 0)
            let parts = text.split(separator: ".").compactMap { Int($0) }
            var dict = OrderedDictionary<ObjectKey, Value>()
            dict[.string("major")] = .int(parts.count > 0 ? parts[0] : 0)
            dict[.string("minor")] = .int(parts.count > 1 ? parts[1] : 0)
            dict[.string("patch")] = .int(parts.count > 2 ? parts[2] : 0)
            dict[.string("string")] = .string(text)
            return .object(dict, stringRepresentation: text)
        }
    }

    private static func makeOrd() -> JinjaFunction {
        { args, kwargs, _ in
            let text = try requireString(args, kwargs, name: "value", index: 0)
            guard let scalar = text.unicodeScalars.first else { return .null }
            return .int(Int(scalar.value))
        }
    }

    private static func makeContains() -> JinjaFunction {
        { args, kwargs, _ in
            guard args.count >= 2 else { return .boolean(false) }
            let container = args[0]
            let needle = args[1]
            switch container {
            case .string(let s):
                return .boolean(s.contains(needle.description))
            case .array(let items):
                return .boolean(items.contains { $0.isEquivalent(to: needle) || $0.description == needle.description })
            case .object(let dict, _, _):
                if case .string(let key) = needle {
                    return .boolean(dict[.string(key)] != nil)
                }
                return .boolean(dict.values.contains { $0.isEquivalent(to: needle) })
            default:
                return .boolean(false)
            }
        }
    }

    // MARK: - Collections

    private enum SetOp { case union, intersect, difference, symmetricDifference }

    private static func makeSetOp(_ op: SetOp) -> JinjaFunction {
        { args, _, _ in
            let left = Set(listDescriptions(args.first))
            let right = Set(listDescriptions(args.count > 1 ? args[1] : nil))
            let result: Set<String>
            switch op {
            case .union: result = left.union(right)
            case .intersect: result = left.intersection(right)
            case .difference: result = left.subtracting(right)
            case .symmetricDifference: result = left.symmetricDifference(right)
            }
            return .array(result.sorted().map(Value.string))
        }
    }

    private static func makeFlatten() -> JinjaFunction {
        { args, kwargs, _ in
            let levels = intArg(args, kwargs, index: 1) ?? Int.max
            guard let first = args.first else { return .array([]) }
            return .array(flattenValue(first, levels: levels))
        }
    }

    private static func flattenValue(_ value: Value, levels: Int) -> [Value] {
        guard levels > 0, case .array(let items) = value else { return [value] }
        return items.flatMap { flattenValue($0, levels: levels - 1) }
    }

    private static func makeCombine() -> JinjaFunction {
        { args, _, _ in
            var result = OrderedDictionary<ObjectKey, Value>()
            for arg in args {
                guard case .object(let dict, _, _) = arg else { continue }
                for (key, value) in dict {
                    result[key] = value
                }
            }
            return .object(result)
        }
    }

    private static func makeShuffle() -> JinjaFunction {
        { args, _, _ in
            guard case .array(let items) = args.first else { return .array([]) }
            return .array(items.shuffled())
        }
    }

    private static func makeMergeResponse() -> JinjaFunction {
        { args, _, _ in
            var result: [Value] = []
            for arg in args {
                switch arg {
                case .array(let items):
                    result.append(contentsOf: items)
                case .object(let dict, _, _):
                    // HA merge_response flattens service-call style maps of lists.
                    for value in dict.values {
                        if case .array(let items) = value {
                            result.append(contentsOf: items)
                        } else {
                            result.append(value)
                        }
                    }
                default:
                    result.append(arg)
                }
            }
            return .array(result)
        }
    }

    private static func makeSetConvert() -> JinjaFunction {
        { args, _, _ in
            let items = listDescriptions(args.first)
            return .array(Array(Set(items)).sorted().map(Value.string))
        }
    }

    private static func makeTupleConvert() -> JinjaFunction {
        { args, _, _ in
            if case .array(let items) = args.first {
                return .array(items)
            }
            return .array(args)
        }
    }

    // MARK: - Helpers

    private static func optionalValue(
        _ args: [Value],
        _ kwargs: [String: Value],
        name: String,
        index: Int
    ) -> Value? {
        if index < args.count { return args[index] }
        return kwargs[name]
    }

    private static func coerceDouble(
        _ args: [Value],
        _ kwargs: [String: Value],
        name: String,
        index: Int
    ) -> Double? {
        if index < args.count { return coerceDoubleValue(args[index]) }
        if let value = kwargs[name] { return coerceDoubleValue(value) }
        return nil
    }

    private static func coerceDoubleValue(_ value: Value) -> Double? {
        switch value {
        case .int(let i): return Double(i)
        case .double(let d): return d
        case .string(let s):
            return Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private static func parseHABool(_ value: Value) -> Bool? {
        switch value {
        case .boolean(let b):
            return b
        case .int(let i):
            if i == 1 { return true }
            if i == 0 { return false }
            return nil
        case .double(let d):
            if d == 1 { return true }
            if d == 0 { return false }
            return nil
        case .string(let s):
            switch s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "on", "enable", "1":
                return true
            case "false", "no", "off", "disable", "0":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func intArg(_ args: [Value], _ kwargs: [String: Value], index: Int) -> Int? {
        if args.count > index {
            switch args[index] {
            case .int(let i): return i
            case .double(let d): return Int(d)
            case .string(let s): return Int(s)
            default: break
            }
        }
        return nil
    }

    private static func doubleValue(_ value: Value) -> Double? {
        switch value {
        case .int(let i): return Double(i)
        case .double(let d): return d
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    private static func listDescriptions(_ value: Value?) -> [String] {
        guard let value else { return [] }
        if case .array(let items) = value {
            return items.map(\.description)
        }
        return [value.description]
    }
}
