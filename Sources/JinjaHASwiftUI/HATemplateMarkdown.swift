import SwiftUI
import JinjaHA

/// Renders a Jinja template to markdown (`AttributedString`), including tables.
public struct HATemplateMarkdown: View {
    private let template: String
    private let refreshToken: String
    @State private var model: TemplateRenderModel

    public init(
        template: String,
        renderer: any TemplateRendering,
        refreshToken: String = "",
        placeholderWhileLoading: String = "Rendering…"
    ) {
        self.template = template
        self.refreshToken = refreshToken
        _model = State(
            initialValue: TemplateRenderModel(
                template: template,
                renderer: renderer,
                refreshToken: refreshToken,
                placeholderWhileLoading: placeholderWhileLoading
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(markdownAttributed)
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: "\(refreshToken)-\(template.hashValue)") {
            model.template = template
            model.refreshToken = refreshToken
            await model.renderIfNeeded()
        }
    }

    private var markdownAttributed: AttributedString {
        let text = model.displayText
        if let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .full)
        ) {
            return parsed
        }
        if let parsed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(text)
    }
}
