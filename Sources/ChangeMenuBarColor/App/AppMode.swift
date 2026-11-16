import Foundation

enum AppMode {
    static var isGUI: Bool {
        if ProcessInfo.processInfo.environment["CMBC_MODE"] == "gui" {
            return true
        }
        return Bundle.main.bundlePath.hasSuffix(".app")
    }
}
