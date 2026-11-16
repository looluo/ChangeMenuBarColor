//
//  NotchController.swift
//  ChangeMenuBarColor
//

import Cocoa
import Foundation

typealias DisplayID = CGDirectDisplayID

enum NotchIntent: String, Codable {
    case on
    case off
}

/// What we believe is on each display right now.
enum WallpaperState: Equatable {
    case unknown
    case original(WallpaperRef)
    case applied(original: WallpaperRef, output: WallpaperRef)
}

/// Owns the notch intent and the per-display wallpaper state. Every event
/// (toggle, observation, display change, launch) funnels into `reconcile`, and
/// every desktop write in the app flows through `commit`, which records the
/// expected URL so the monitor can tell our own write landing from an external
/// change.
@MainActor
final class NotchController {
    private let pipeline = WallpaperPipeline()
    private var preferences: Preferences

    private(set) var intent: NotchIntent
    private var displays: [DisplayID: WallpaperState] = [:]
    private var pendingOwnWrite: [DisplayID: String] = [:]
    private var inFlight: Set<DisplayID> = []

    static let blackSpec = WallpaperPipeline.StripSpec.solid(color: NSColor(hexString: "#000000")!)

    init(preferences: Preferences) {
        self.preferences = preferences
        self.intent = preferences.notchIntent
    }

    /// Menu action. Persists, then reconciles every display.
    func toggle(to newIntent: NotchIntent) {
        guard newIntent != intent else {
            return
        }
        intent = newIntent
        preferences.notchOn = newIntent == .on
        preferences.save()
        reconcileAll()
    }

    /// Screen set changed (add, remove, reconfigure). Forced because display
    /// geometry can change the menu bar height, so a strip that merely looks
    /// right must still be regenerated.
    func displaysChanged() {
        Log.debug("Displays changed, re-reconciling")
        reconcileAll(forced: true)
    }

    /// Monitor callback. A pending own write that landed is adopted silently;
    /// anything else reconciles.
    func observed(_ ref: WallpaperRef, on id: DisplayID) {
        let expected = pendingOwnWrite[id]
        pendingOwnWrite[id] = nil
        guard expected != ref.url.standardizedFileURL.path else {
            return
        }
        reconcile(id)
    }

    func reconcileAll(forced: Bool = false) {
        let live = Set(NSScreen.screens.compactMap { $0.displayID })
        displays = displays.filter { live.contains($0.key) }
        NSScreen.screens.compactMap { $0.displayID }.forEach { reconcile($0, forced: forced) }
    }

    // The converge function. Running it twice with nothing external changing
    // produces no second write.
    private func reconcile(_ id: DisplayID, forced: Bool = false) {
        guard let screen = Self.screen(withID: id) else {
            displays.removeValue(forKey: id)
            return
        }
        guard let url = pipeline.observedWallpaperURL(for: screen) else {
            Log.debug("Reconciling screen \(id): no observable wallpaper")
            return
        }
        Log.debug("Reconciling screen \(id): observed \(url.path)")

        let ref = WallpaperRef(url: url)
        let observedPath = url.standardizedFileURL.path

        switch intent {
        case .on:
            switch pipeline.classify(url: url) {
            case .ours where !forced:
                // Our strip is on screen. Adopting without a write is what makes
                // relaunching after Exit converge without stacking strips.
                if let original = adoptionOriginal(for: id, screen: screen) {
                    displays[id] = .applied(original: original, output: ref)
                }
            case .ours, .generatedOther, .external:
                // A CLI-generated file means another color was applied while
                // intent is on, and intent on means black; an external file is a
                // new base. Both re-apply from the remembered original.
                commit(.apply(spec: Self.blackSpec), on: id)
            }
        case .off:
            switch displays[id] ?? .unknown {
            case let .applied(original, output):
                switch pipeline.classify(url: url) {
                case .ours where observedPath == output.url.standardizedFileURL.path:
                    commit(.restoreOriginal, on: id)
                case .ours, .generatedOther:
                    // The CLI or another session applied while we are off.
                    // Respect it; never adopt a generated file as an original.
                    displays[id] = .applied(original: original, output: ref)
                case .external:
                    displays[id] = .original(ref)
                }
            case .original, .unknown:
                switch pipeline.classify(url: url) {
                case .ours, .generatedOther:
                    // Intent off means the original wallpaper, including when a
                    // leftover strip from an earlier session is still set.
                    commit(.restoreOriginal, on: id)
                case .external:
                    displays[id] = .original(ref)
                }
            }
        }
    }

    // The only place the app writes the desktop picture.
    private func commit(_ write: DisplayWrite, on id: DisplayID) {
        guard let screen = Self.screen(withID: id), !inFlight.contains(id) else {
            return
        }
        inFlight.insert(id)
        defer { inFlight.remove(id) }

        switch write {
        case let .apply(spec):
            guard let applied = pipeline.prepare(spec: spec, base: .currentDesktop, screen: screen, outputKind: .gui) else {
                Log.error("Could not generate new wallpaper for screen \(id)")
                return
            }
            pendingOwnWrite[id] = applied.output.standardizedFileURL.path
            guard pipeline.install(applied, screen: screen) else {
                pendingOwnWrite[id] = nil
                return
            }
            waitForObservability(of: applied.output, on: screen, id: id)
            displays[id] = .applied(original: WallpaperRef(url: applied.original), output: WallpaperRef(url: applied.output))
        case .restoreOriginal:
            guard let original = pipeline.rememberedOriginal(for: screen) else {
                Log.error("No remembered original wallpaper for screen \(id), cannot restore")
                return
            }
            pendingOwnWrite[id] = original.standardizedFileURL.path
            guard pipeline.restoreOriginal(screen: screen) != nil else {
                pendingOwnWrite[id] = nil
                return
            }
            waitForObservability(of: original, on: screen, id: id)
            if case .applied(_, let output) = displays[id] ?? .unknown {
                pipeline.deleteGenerated(output.url)
            }
            displays[id] = .original(WallpaperRef(url: original))
        }
    }

    // setDesktopImageURL returns before the desktop database settles:
    // desktopImageURL keeps reporting the previous picture for a moment, and a
    // reconcile reading in that window would undo our write as an external
    // change. Block until our URL is actually observable.
    private func waitForObservability(of url: URL, on screen: NSScreen, id: DisplayID) {
        let expected = url.standardizedFileURL.path
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if pipeline.observedWallpaperURL(for: screen)?.standardizedFileURL.path == expected {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        Log.error("The wallpaper set for screen \(id) did not become observable in time")
    }

    private func adoptionOriginal(for id: DisplayID, screen: NSScreen) -> WallpaperRef? {
        if let remembered = pipeline.rememberedOriginal(for: screen) {
            return WallpaperRef(url: remembered)
        }
        if case .applied(let original, _)? = displays[id] {
            return original
        }
        Log.error("The current wallpaper was generated by this tool, but no original wallpaper is remembered for screen \(id)")
        return nil
    }

    static func screen(withID id: DisplayID) -> NSScreen? {
        return NSScreen.screens.first { $0.displayID == id }
    }
}

extension NSScreen {
    var displayID: DisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return DisplayID(truncating: number)
    }
}

private enum DisplayWrite {
    case apply(spec: WallpaperPipeline.StripSpec)
    case restoreOriginal
}
