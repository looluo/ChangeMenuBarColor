import Cocoa

// restore_wallpaper.swift — restores every screen's desktop picture from the
// original-wallpaper-<displayID>.txt markers written by ChangeMenuBarColor.

let fm = FileManager.default
let folder = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("ChangeMenuBarColor")
guard let markers = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
    print("no ChangeMenuBarColor folder; nothing to restore")
    exit(1)
}

var restored = 0
for screen in NSScreen.screens {
    guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
          let marker = markers.first(where: { $0.lastPathComponent == "original-wallpaper-\(id.stringValue).txt" }),
          let contents = try? String(contentsOf: marker, encoding: .utf8) else { continue }
    let url = URL(fileURLWithPath: contents.trimmingCharacters(in: .whitespacesAndNewlines))
    do {
        try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        restored += 1
        print("restored \(screen.localizedName) from \(url.path)")
    } catch {
        print("FAILED to restore \(screen.localizedName): \(error.localizedDescription)")
    }
}
print("restored \(restored) screen(s)")
exit(restored > 0 ? 0 : 1)
