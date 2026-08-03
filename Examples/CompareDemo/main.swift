import AppKit
import Foundation
import JinjaHA
import JinjaHASwiftUI
import SwiftUI

@main
enum CompareDemo {
    static func main() {
        let args = CommandLine.arguments
        if let exportIndex = args.firstIndex(of: "--export-screenshots") {
            let output: URL
            if args.count > exportIndex + 1, !args[exportIndex + 1].hasPrefix("-") {
                output = URL(fileURLWithPath: args[exportIndex + 1], isDirectory: true)
            } else {
                output = URL(fileURLWithPath: "Docs/screenshots", isDirectory: true)
                    .absoluteURL
            }
            do {
                try ScreenshotExporter.exportAll(to: output)
                print("Wrote CompareDemo screenshots to \(output.path)")
            } catch {
                fputs("Screenshot export failed: \(error)\n", stderr)
                exit(1)
            }
            return
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = DemoAppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class DemoAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = NSHostingView(rootView: CompareRootView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "JinjaHA CompareDemo"
        window.contentView = root
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
