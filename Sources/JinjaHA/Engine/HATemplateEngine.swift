import Foundation
import JinjaCore

/// Local Home Assistant Jinja template engine.
public struct HATemplateEngine: Sendable {
    public var environment: HATemplateEnvironment

    public init(environment: HATemplateEnvironment) {
        self.environment = environment
    }

    public init(
        snapshot: HAStateSnapshot,
        limits: HATemplateLimits = .default,
        extraGlobals: [String: Value] = [:]
    ) {
        self.environment = HATemplateEnvironment(
            snapshot: snapshot,
            limits: limits,
            extraGlobals: extraGlobals
        )
    }

    /// Synchronously render a template against the configured snapshot.
    public func render(_ template: String, context: [String: Value] = [:]) throws -> String {
        let limits = environment.limits
        let byteCount = template.utf8.count
        guard byteCount <= limits.maxTemplateBytes else {
            throw HATemplateError.templateTooLarge(limit: limits.maxTemplateBytes, actual: byteCount)
        }

        let source = HATemplateEnvironment.preprocess(template)
        let compiled: Template
        do {
            compiled = try Template(source, with: environment.templateOptions)
        } catch {
            throw HATemplateError.jinja(String(describing: error))
        }

        let jinjaEnv = environment.makeJinjaEnvironment()
        let output: String
        do {
            output = try compiled.render(context, environment: jinjaEnv)
        } catch let error as HATemplateError {
            throw error
        } catch {
            throw HATemplateError.jinja(scrub(String(describing: error)))
        }

        let outputCount = output.utf8.count
        guard outputCount <= limits.maxOutputBytes else {
            throw HATemplateError.outputTooLarge(limit: limits.maxOutputBytes, actual: outputCount)
        }
        return output
    }

    /// Async render with optional timeout from ``HATemplateLimits/renderTimeout``.
    public func renderAsync(_ template: String, context: [String: Value] = [:]) async throws -> String {
        if let timeout = environment.limits.renderTimeout {
            try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try self.render(template, context: context)
                }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw HATemplateError.renderTimedOut
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } else {
            try render(template, context: context)
        }
    }

    private func scrub(_ message: String) -> String {
        // Avoid leaking tokens if callers embed them in context dumps.
        message.replacingOccurrences(
            of: #"(?i)(bearer\s+|token[\"']?\s*[:=]\s*)[A-Za-z0-9._\-]+"#,
            with: "$1[REDACTED]",
            options: .regularExpression
        )
    }
}
