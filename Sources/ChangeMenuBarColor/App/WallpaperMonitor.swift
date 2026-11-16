//
//  WallpaperMonitor.swift
//  ChangeMenuBarColor
//

import Cocoa
import Foundation

/// An observed desktop picture: the URL plus enough of the file's identity that
/// a same-URL content replacement still counts as a change.
struct WallpaperRef: Equatable {
    let url: URL
    let mtime: Date?
    let byteSize: Int?

    init(url: URL) {
        self.url = url
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.mtime = attributes?[.modificationDate] as? Date
        self.byteSize = attributes?[.size] as? Int
    }
}

/// Polls NSWorkspace.desktopImageURL per screen and emits only differences.
/// There is no public wallpaper-change notification, so this observes the only
/// ground truth and leaves all interpretation to the controller.
@MainActor
final class WallpaperMonitor {
    var onObservedChange: ((DisplayID, WallpaperRef) -> Void)?
    var onDisplaysChanged: (() -> Void)?

    private let pollInterval: TimeInterval = 2
    private var timer: Timer?
    private var lastEmitted: [DisplayID: WallpaperRef] = [:]
    private var observers: [NSObjectProtocol] = []
    private let pipeline = WallpaperPipeline()

    func start() {
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollNow()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // The timer runs in .common so it keeps firing while a menu is tracked;
        // both notifications post on the main thread.
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onDisplaysChanged?()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pollNow()
            }
        })

        pollNow()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    func pollNow() {
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let url = pipeline.observedWallpaperURL(for: screen) else {
                continue
            }
            let ref = WallpaperRef(url: url)
            if lastEmitted[id] != ref {
                lastEmitted[id] = ref
                onObservedChange?(id, ref)
            }
        }
    }
}
