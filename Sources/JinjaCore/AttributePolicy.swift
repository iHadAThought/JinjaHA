import Foundation

/// Controls which attributes may be read on values during template execution.
///
/// Mirrors the intent of Pallets Jinja sandbox fixes (e.g. 3.1.5 / 3.1.6 around
/// unsafe attribute / `|attr` escape paths) in a Swift-appropriate form.
public protocol AttributePolicy: Sendable {
    /// Returns whether `name` may be accessed on `value`.
    func allowsAccess(to name: String, on value: Value) -> Bool
}

/// Default policy: block private / dunder-style names (prefix `_`).
public struct DefaultAttributePolicy: AttributePolicy {
    public init() {}

    public func allowsAccess(to name: String, on value: Value) -> Bool {
        if name.hasPrefix("_") { return false }
        return true
    }
}

/// Permissive policy for trusted templates only.
public struct PermissiveAttributePolicy: AttributePolicy {
    public init() {}

    public func allowsAccess(to name: String, on value: Value) -> Bool { true }
}
