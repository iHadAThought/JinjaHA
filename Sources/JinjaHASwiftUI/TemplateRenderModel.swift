import Foundation
import JinjaHA
import Observation

/// Observable render pipeline with last-good-render semantics.
@MainActor
@Observable
public final class TemplateRenderModel {
    public private(set) var rendered: String?
    public private(set) var errorMessage: String?
    public private(set) var isRendering = false

    public var template: String
    public var refreshToken: String
    public var placeholderWhileLoading: String

    private let renderer: any TemplateRendering

    public init(
        template: String,
        renderer: any TemplateRendering,
        refreshToken: String = "",
        placeholderWhileLoading: String = "Rendering…"
    ) {
        self.template = template
        self.renderer = renderer
        self.refreshToken = refreshToken
        self.placeholderWhileLoading = placeholderWhileLoading
    }

    public var needsTemplate: Bool {
        template.contains("{{") || template.contains("{%")
    }

    /// Text shown in the UI — never flashes raw Jinja while a prior good render exists.
    public var displayText: String {
        if !needsTemplate {
            return template
        }
        if let rendered {
            return rendered
        }
        if isRendering || errorMessage == nil {
            return placeholderWhileLoading
        }
        return template
    }

    public func renderIfNeeded() async {
        guard needsTemplate else {
            rendered = template
            errorMessage = nil
            return
        }
        isRendering = true
        defer { isRendering = false }
        do {
            let text = try await renderer.render(template)
            guard !Task.isCancelled else { return }
            rendered = text
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            if rendered == nil {
                errorMessage = "Template render failed"
            }
        }
    }
}
