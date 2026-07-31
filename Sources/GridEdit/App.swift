import AppKit

enum AppInfo {
    /// The app's short version (from Info.plist), with any leading "v" stripped.
    /// Falls back to "dev" when run without a bundle (e.g. `swift run`).
    static var version: String {
        normalize((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev")
    }

    static func normalize(_ raw: String) -> String {
        raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
    }
}

/// AppKit-hosted entry point. NSDocument drives the app lifecycle:
/// NSDocumentController owns Open / Open Recent / untitled-document flow,
/// so the delegate stays thin.
@main
enum GridEditMain {
    /// `NSApplication.delegate` is a weak reference — the delegate must be owned here.
    private static var delegate: AppDelegate?

    static func main() {
        // `brew test` and release verification call `grid-edit --version`;
        // answer on stdout and exit before any AppKit machinery starts.
        if CommandLine.arguments.contains("--version") {
            print("grid-edit \(AppInfo.version)")
            exit(0)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.mainMenu = MainMenu.build()
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
