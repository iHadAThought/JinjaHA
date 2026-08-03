import SwiftUI
import JinjaHA

/// Renders a Jinja template to plain SwiftUI `Text`.
public struct HATemplateText: View {
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
            Text(model.displayText)
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
}
