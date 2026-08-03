import Foundation
import JinjaCore

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
}
