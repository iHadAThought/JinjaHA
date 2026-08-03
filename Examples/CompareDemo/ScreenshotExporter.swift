import AppKit
import Foundation
import SwiftUI

/// Renders static side-by-side panes (pre-evaluated) so exports don't race async SwiftUI tasks.
enum ScreenshotExporter {
    @MainActor
    static func exportAll(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for scenario in DemoData.Scenario.allCases {
            let output = DemoData.render(scenario)
            let view = ScreenshotCard(
                scenarioTitle: scenario.title,
                template: scenario.template,
                nativeOutput: output,
                swiftUIOutput: output,
                markdown: scenario.usesMarkdown
            )
            .frame(width: 920, height: 520)

            let data = try renderPNG(view: view, scale: 2)
            let fileURL = directory.appendingPathComponent(scenario.screenshotFilename)
            try data.write(to: fileURL, options: .atomic)
        }
    }

    @MainActor
    private static func renderPNG(view: some View, scale: CGFloat) throws -> Data {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let nsImage = renderer.nsImage else {
            throw ExportError.rendererFailed
        }
        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            throw ExportError.pngEncodingFailed
        }
        return png
    }

    enum ExportError: Error, LocalizedError {
        case rendererFailed
        case pngEncodingFailed

        var errorDescription: String? {
            switch self {
            case .rendererFailed: return "ImageRenderer produced no image"
            case .pngEncodingFailed: return "Failed to encode PNG"
            }
        }
    }
}

private struct ScreenshotCard: View {
    let scenarioTitle: String
    let template: String
    let nativeOutput: String
    let swiftUIOutput: String
    let markdown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("JinjaHA CompareDemo")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(scenarioTitle)
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }

            Text("Native engine vs SwiftUI presentation — same local snapshot")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 14) {
                column(title: "Native engine", body: nativeOutput, mono: true)
                column(
                    title: markdown ? "SwiftUI markdown" : "SwiftUI text",
                    body: swiftUIOutput,
                    mono: !markdown
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Template")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(template.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func column(title: String, body: String, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Group {
                if markdown, title.contains("markdown"),
                   let attributed = try? AttributedString(
                    markdown: body,
                    options: .init(interpretedSyntax: .full)
                   ) {
                    Text(attributed)
                } else {
                    Text(body)
                        .font(mono ? .body.monospaced() : .body)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
