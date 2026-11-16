//
//  Preferences.swift
//  ChangeMenuBarColor
//

import Foundation

/// Persisted next to the wallpaper markers in
/// ~/Library/Application Support/ChangeMenuBarColor/preferences.plist, so the
/// bundled app and the bare dev binary resolve the same intent.
struct Preferences: Codable {
    var notchOn: Bool?
    var firstRunCompleted: Bool?

    /// Absent reads as ON: the toggle defaults to on at first launch.
    var notchIntent: NotchIntent {
        return (notchOn ?? true) ? .on : .off
    }

    static var fileURL: URL {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChangeMenuBarColor/preferences.plist")
    }

    static func load() -> Preferences {
        guard let data = try? Data(contentsOf: fileURL) else {
            return Preferences()
        }
        return (try? PropertyListDecoder().decode(Preferences.self, from: data)) ?? Preferences()
    }

    func save() {
        guard let data = try? PropertyListEncoder().encode(self) else {
            Log.error("Cannot encode preferences")
            return
        }
        do {
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            Log.error("Cannot save preferences: \(error.localizedDescription)")
        }
    }
}
