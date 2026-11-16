//
//  AppMode.swift
//  ChangeMenuBarColor
//

import Foundation

enum AppMode {
    /// GUI when launched from an .app bundle or with CMBC_MODE=gui (dev path).
    /// A bare binary with no env var stays CLI, so `ChangeMenuBarColor` alone
    /// still prints help and exits, as before.
    static var isGUI: Bool {
        if ProcessInfo.processInfo.environment["CMBC_MODE"] == "gui" {
            return true
        }
        return Bundle.main.bundlePath.hasSuffix(".app")
    }
}
