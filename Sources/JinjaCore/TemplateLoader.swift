import Foundation

/// Loads named templates for `{% include %}` / `{% extends %}` (Phase 2+).
///
/// Default policy is deny-all so apps must opt into filesystem or bundle loading.
public protocol TemplateLoader: Sendable {
    /// Returns the source for `name`, or throws if not allowed / missing.
    func load(name: String) throws -> String
}

/// Rejects every load request.
public struct DenyAllTemplateLoader: TemplateLoader {
    public init() {}

    public func load(name: String) throws -> String {
        throw JinjaError.runtime(
            "Template loading is disabled (deny-all loader): \(name)"
        )
    }
}

/// In-memory allowlisted templates (safe for tests and embedded macros).
public struct DictionaryTemplateLoader: TemplateLoader {
    private let templates: [String: String]

    public init(_ templates: [String: String]) {
        self.templates = templates
    }

    public func load(name: String) throws -> String {
        guard let source = templates[name] else {
            throw JinjaError.runtime("Template not found in allowlist: \(name)")
        }
        return source
    }
}
