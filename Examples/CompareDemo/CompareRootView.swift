import JinjaHA
import JinjaHASwiftUI
import SwiftUI

struct CompareRootView: View {
    @State private var scenario: DemoData.Scenario = .states
    @State private var nativeOutput: String = DemoData.render(.states)
    @State private var exportMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("JinjaHA CompareDemo")
                    .font(.title2.weight(.semibold))
                Spacer()
                Picker("Scenario", selection: $scenario) {
                    ForEach(DemoData.Scenario.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                .onChange(of: scenario) { _, newValue in
                    nativeOutput = DemoData.render(newValue)
                }

                Button("Export PNGs") {
                    exportScreenshots()
                }
            }

            Text("Left: native `HATemplateEngine` → `Text`. Right: JinjaHASwiftUI (`HATemplateText` / `HATemplateMarkdown`).")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                pane(title: "Native engine") {
                    Text(nativeOutput)
                        .font(.body.monospaced())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                pane(title: scenario.usesMarkdown ? "SwiftUI markdown" : "SwiftUI text") {
                    Group {
                        if scenario.usesMarkdown {
                            HATemplateMarkdown(
                                template: scenario.template,
                                renderer: DemoData.renderer,
                                refreshToken: scenario.id
                            )
                        } else {
                            HATemplateText(
                                template: scenario.template,
                                renderer: DemoData.renderer,
                                refreshToken: scenario.id
                            )
                        }
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }

            DisclosureGroup("Template source") {
                ScrollView {
                    Text(scenario.template)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 140)
            }

            if let exportMessage {
                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 860, minHeight: 520)
    }

    private func pane<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func exportScreenshots() {
        let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Docs/screenshots", isDirectory: true)
        do {
            try ScreenshotExporter.exportAll(to: dir)
            exportMessage = "Exported screenshots to \(dir.path)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}
