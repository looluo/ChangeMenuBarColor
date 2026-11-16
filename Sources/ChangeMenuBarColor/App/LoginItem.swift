import Cocoa
import ServiceManagement

enum LoginItem {
    static func registerOnFirstRun(_ preferences: inout Preferences) {
        // SMAppService happily registers an unbundled binary by executable path,
        // which would put a dev build into the user's login items. Only a real
        // .app bundle is meant to register, and only its first run.
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            Log.debug("Login item registration skipped: not running from an .app bundle")
            return
        }

        guard preferences.firstRunCompleted != true else {
            return
        }
        preferences.firstRunCompleted = true
        preferences.save()

        guard #available(macOS 13, *) else {
            Log.debug("Login item registration skipped: SMAppService requires macOS 13")
            return
        }

        let service = SMAppService.mainApp
        do {
            try service.register()
        } catch {
            if (error as NSError).code != kSMErrorAlreadyRegistered {
                Log.error("Login item registration failed: \(error.localizedDescription). Enable it manually in System Settings → General → Login Items")
                Log.debug("Login item status: \(statusDescription(service.status))")
                return
            }
        }
        Log.debug("Login item status: \(statusDescription(service.status))")
    }

    @available(macOS 13, *)
    static func statusDescription(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: return "enabled"
        case .notRegistered: return "not registered"
        case .requiresApproval: return "requires approval in System Settings → General → Login Items"
        case .notFound: return "not found (an .app bundle is required)"
        @unknown default: return "unknown (\(status.rawValue))"
        }
    }
}
