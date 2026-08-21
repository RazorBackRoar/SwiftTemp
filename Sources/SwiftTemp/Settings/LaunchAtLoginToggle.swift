import ServiceManagement
import SwiftUI

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = Self.isRegistered
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Launch at login", isOn: $isEnabled)
                .onChange(of: isEnabled) {
                    applyChange()
                }
            Text(helperText)
                .font(.caption)
                .foregroundStyle(errorMessage == nil ? Color.secondary : Color.red)
        }
    }

    private static var isRegistered: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    private var helperText: String {
        if let errorMessage {
            return errorMessage
        }
        if SMAppService.mainApp.status == .requiresApproval {
            return "Approval is required in System Settings → General → Login Items."
        }
        return "Available when running the installed SwiftTemp.app."
    }

    private func applyChange() {
        errorMessage = nil
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLogger.system.error("Launch-at-login change failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            isEnabled = Self.isRegistered
        }
    }
}
