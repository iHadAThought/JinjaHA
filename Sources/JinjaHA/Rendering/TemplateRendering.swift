import Foundation
import Jinja

/// Backend-agnostic async template renderer.
public protocol TemplateRendering: Sendable {
    func render(_ template: String) async throws -> String
}

/// Renders templates locally with ``HATemplateEngine``.
public struct LocalTemplateRenderer: TemplateRendering {
    private let engine: HATemplateEngine
    private let context: [String: Value]

    public init(engine: HATemplateEngine, context: [String: Value] = [:]) {
        self.engine = engine
        self.context = context
    }

    public init(snapshot: HAStateSnapshot, limits: HATemplateLimits = .default) {
        self.engine = HATemplateEngine(snapshot: snapshot, limits: limits)
        self.context = [:]
    }

    public func render(_ template: String) async throws -> String {
        try await engine.renderAsync(template, context: context)
    }
}

/// Tries a primary renderer, then falls back to a secondary on failure.
public struct FallbackTemplateRenderer: TemplateRendering {
    private let primary: any TemplateRendering
    private let fallback: any TemplateRendering
    private let shouldFallback: @Sendable (Error) -> Bool

    public init(
        primary: any TemplateRendering,
        fallback: any TemplateRendering,
        shouldFallback: @escaping @Sendable (Error) -> Bool = { _ in true }
    ) {
        self.primary = primary
        self.fallback = fallback
        self.shouldFallback = shouldFallback
    }

    public func render(_ template: String) async throws -> String {
        do {
            return try await primary.render(template)
        } catch {
            guard shouldFallback(error) else { throw error }
            return try await fallback.render(template)
        }
    }
}
