import Foundation
import Jinja

/// Builds a Jinja ``Environment`` populated with Home Assistant helpers.
public struct HATemplateEnvironment: Sendable {
    public var snapshot: HAStateSnapshot
    public var limits: HATemplateLimits
    public var extraGlobals: [String: Value]
    public var templateOptions: Template.Options

    public init(
        snapshot: HAStateSnapshot,
        limits: HATemplateLimits = .default,
        extraGlobals: [String: Value] = [:],
        templateOptions: Template.Options = .init(lstripBlocks: true, trimBlocks: true)
    ) {
        self.snapshot = snapshot
        self.limits = limits
        self.extraGlobals = extraGlobals
        self.templateOptions = templateOptions
    }

    /// Creates a fresh Jinja environment with HA globals/filters registered.
    public func makeJinjaEnvironment() -> Environment {
        let env = Environment()
        HAGlobals.register(into: env, snapshot: snapshot, limits: limits)
        HAFilters.register(into: env)
        for (key, value) in extraGlobals {
            env[key] = value
        }
        return env
    }

    /// Rewrites HA callable/filter `states` into `__states__` while keeping
    /// dotted `states.domain.object` access on the nested object.
    /// Also rewrites `range(` to `__safe_range__(` because swift-jinja re-injects
    /// built-in globals when cloning environments, which would clobber overrides.
    public static func preprocess(_ source: String) -> String {
        var result = ""
        result.reserveCapacity(source.count)
        let scalars = Array(source)
        var index = 0
        while index < scalars.count {
            if matchesStatesCallOrFilter(scalars, at: index) {
                result.append("__states__")
                index += "states".count
                continue
            }
            if matchesWordCall(scalars, at: index, word: "range") {
                result.append("__safe_range__")
                index += "range".count
                continue
            }
            result.append(scalars[index])
            index += 1
        }
        return result
    }

    private static func matchesWordCall(_ scalars: [Character], at index: Int, word: String) -> Bool {
        let chars = Array(word)
        guard index + chars.count <= scalars.count else { return false }
        if index > 0 {
            let prev = scalars[index - 1]
            if prev.isLetter || prev.isNumber || prev == "_" || prev == "." {
                return false
            }
        }
        for (offset, char) in chars.enumerated() {
            if scalars[index + offset] != char { return false }
        }
        var cursor = index + chars.count
        while cursor < scalars.count, scalars[cursor].isWhitespace {
            cursor += 1
        }
        return cursor < scalars.count && scalars[cursor] == "("
    }

    private static func matchesStatesCallOrFilter(_ scalars: [Character], at index: Int) -> Bool {
        let word = Array("states")
        guard index + word.count <= scalars.count else { return false }
        if index > 0 {
            let prev = scalars[index - 1]
            if prev.isLetter || prev.isNumber || prev == "_" || prev == "." {
                return false
            }
        }
        for (offset, char) in word.enumerated() {
            if scalars[index + offset] != char { return false }
        }
        let after = index + word.count
        if after < scalars.count {
            let next = scalars[after]
            if next.isLetter || next.isNumber || next == "_" {
                return false
            }
        }
        // Call form: states(
        var cursor = after
        while cursor < scalars.count, scalars[cursor].isWhitespace {
            cursor += 1
        }
        if cursor < scalars.count, scalars[cursor] == "(" {
            return true
        }
        // Filter form: | states
        if index > 0 {
            var back = index - 1
            while back >= 0, scalars[back].isWhitespace {
                back -= 1
            }
            if back >= 0, scalars[back] == "|" {
                return true
            }
        }
        return false
    }
}
