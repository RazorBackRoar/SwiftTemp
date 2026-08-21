import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no Cmd+Tab entry — unless the
        // user has opted into "Show Dock icon" in Settings.
        let showDockIcon = UserDefaults.standard.bool(forKey: AppSettings.Keys.showDockIcon)
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }
}
