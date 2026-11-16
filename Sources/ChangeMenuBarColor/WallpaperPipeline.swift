import Cocoa
import Files
import Foundation

struct WallpaperPipeline {
    enum StripSpec {
        case solid(color: NSColor)
        case gradient(start: NSColor, end: NSColor)
    }

    enum BaseSource {
        case currentDesktop
        case file(path: String)
    }

    enum WallpaperClass {
        case ours
        case generatedOther
        case external
    }

    enum OutputKind {
        case cli
        case gui

        var filePrefix: String {
            switch self {
            case .cli: return Self.cliFilePrefix
            case .gui: return Self.guiFilePrefix
            }
        }

        static let cliFilePrefix = "wallpaper-screen-adjusted-"
        static let guiFilePrefix = "wallpaper-menubar-"
    }

    struct Applied: Equatable {
        let original: URL
        let output: URL
    }

    @discardableResult
    func apply(spec: StripSpec, base: BaseSource, screen: NSScreen, outputKind: OutputKind = .cli) -> Applied? {
        guard let applied = prepare(spec: spec, base: base, screen: screen, outputKind: outputKind) else {
            return nil
        }
        return install(applied, screen: screen) ? applied : nil
    }

    /// Generate and write the jpg without touching the desktop picture. The GUI
    /// calls this first so it can record the output URL before the desktop write
    /// becomes observable.
    func prepare(spec: StripSpec, base: BaseSource, screen: NSScreen, outputKind: OutputKind) -> Applied? {
        guard let workingDirectory = workingDirectory else {
            Log.error("Cannot access Application Support folder")
            return nil
        }

        guard let loaded = loadWallpaperImage(base: base, screen: screen) else {
            return nil
        }

        guard let resizedWallpaper = loaded.image.crop(size: screen.size) else {
            Log.error("Cannot not resize provided wallpaper to screen size")
            return nil
        }

        let topImage: NSImage?
        switch spec {
        case let .solid(color):
            Log.debug("Generating \(colorName(color)) solid color image")
            topImage = createSolidImage(color: color, width: screen.size.width, height: screen.menuBarHeight)
        case let .gradient(start, end):
            Log.debug("Generating gradient image from \(colorName(start)) to \(colorName(end))")
            topImage = createGradientImage(startColor: start, endColor: end, width: screen.size.width, height: screen.menuBarHeight)
        }
        guard let topImage = topImage, let combined = combineImages(baseImage: resizedWallpaper, addedImage: topImage), let data = combined.jpgData else {
            return nil
        }

        let generatedWallpaperFile = workingDirectory.url.appendingPathComponent("\(outputKind.filePrefix)\(UUID().uuidString).jpg")
        do {
            try? FileManager.default.removeItem(at: generatedWallpaperFile)
            try data.write(to: generatedWallpaperFile)
            Log.debug("Created new wallpaper for the main screen in \(generatedWallpaperFile.absoluteString)")
            return Applied(original: loaded.original, output: generatedWallpaperFile)
        } catch {
            Log.error("Writing new wallpaper file failed with \(error.localizedDescription) for the main screen")
            return nil
        }
    }

    func install(_ applied: Applied, screen: NSScreen) -> Bool {
        guard let workingDirectory = workingDirectory else {
            Log.error("Cannot access Application Support folder")
            return false
        }

        do {
            try NSWorkspace.shared.setDesktopImageURL(applied.output, for: screen, options: [:])
            Log.info("Wallpaper set")
            deleteOldWallpaperFiles(keeping: applied.output, in: workingDirectory)
            return true
        } catch {
            Log.error("Writing new wallpaper file failed with \(error.localizedDescription) for the main screen")
            return false
        }
    }

    @discardableResult
    func restoreOriginal(screen: NSScreen) -> URL? {
        guard let original = rememberedOriginal(for: screen) else {
            return nil
        }
        do {
            try NSWorkspace.shared.setDesktopImageURL(original, for: screen, options: [:])
            Log.debug("Restored original wallpaper \(original.path)")
            return original
        } catch {
            Log.error("Restoring original wallpaper failed with \(error.localizedDescription)")
            return nil
        }
    }

    func deleteGenerated(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func classify(url: URL) -> WallpaperClass {
        guard let workingDirectory = workingDirectory else {
            return .external
        }
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(workingDirectory.url.standardizedFileURL.path + "/") else {
            return .external
        }
        return url.lastPathComponent.hasPrefix(OutputKind.guiFilePrefix) ? .ours : .generatedOther
    }

    func observedWallpaperURL(for screen: NSScreen) -> URL? {
        NSWorkspace.shared.desktopImageURL(for: screen)
    }

    func rememberedOriginal(for screen: NSScreen) -> URL? {
        guard let marker = originalWallpaperMarkerURL(for: screen),
              let contents = try? String(contentsOf: marker, encoding: .utf8),
              let path = contents.split(separator: "\n").first, !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: String(path))
    }

    private func loadWallpaperImage(base: BaseSource, screen: NSScreen) -> (image: NSImage, original: URL)? {
        if case let .file(path) = base {
            guard let wallpaper = NSImage(contentsOfFile: path) else {
                Log.error("Cannot read the provided wallpaper file as image. Check if the path is correct and if it is a valid image file")
                return nil
            }

            Log.debug("Loaded \(path) to be used as wallpaper image")
            rememberOriginalWallpaper(URL(fileURLWithPath: path), for: screen)
            return (wallpaper, URL(fileURLWithPath: path))
        }

        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            Log.error("Cannot read the currently set macOS wallpaper. Try providing a specific wallpaper as a parameter instead.")
            return nil
        }

        // The currently set wallpaper might be a file generated by a previous run of this tool.
        // Always build on top of the remembered original wallpaper instead, so repeated runs
        // do not stack color strips on top of each other and do not re-encode the image again and again.
        if isGeneratedWallpaper(url) {
            if let original = rememberedOriginal(for: screen), let image = NSImage(contentsOf: original) {
                image.adjustSize()
                Log.debug("Current wallpaper was generated by this tool, using the remembered original wallpaper \(original.path)")
                return (image, original)
            }

            Log.error("The current wallpaper was generated by this tool, but the original wallpaper it modified is not remembered. Set any wallpaper in System Settings (or pass a wallpaper file as a parameter) and run again.")
            return nil
        }

        rememberOriginalWallpaper(url, for: screen)

        guard let image = NSImage(contentsOf: url) else {
            Log.error("Cannot read the currently set macOS wallpaper. Try providing a specific wallpaper as a parameter instead.")
            return nil
        }

        image.adjustSize()
        Log.debug("Using currently set macOS wallpaper \(url.path)")

        return (image, url)
    }

    private var workingDirectory: Folder? {
        guard let supportFiles = try? Folder.library?.subfolder(at: "Application Support") else {
            return nil
        }
        return try? supportFiles.createSubfolderIfNeeded(at: "ChangeMenuBarColor")
    }

    private func originalWallpaperMarkerURL(for screen: NSScreen) -> URL? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return workingDirectory?.url.appendingPathComponent("original-wallpaper-\(displayID.stringValue).txt")
    }

    private func rememberOriginalWallpaper(_ url: URL, for screen: NSScreen) {
        guard let marker = originalWallpaperMarkerURL(for: screen) else {
            return
        }
        try? url.path.write(toFile: marker.path, atomically: true, encoding: .utf8)
    }

    private func isGeneratedWallpaper(_ url: URL) -> Bool {
        guard let workingDirectory = workingDirectory else {
            return false
        }
        return url.standardizedFileURL.path.hasPrefix(workingDirectory.url.standardizedFileURL.path + "/")
    }

    private func deleteOldWallpaperFiles(keeping current: URL, in folder: Folder) {
        let inUse = Set(NSScreen.screens.compactMap { NSWorkspace.shared.desktopImageURL(for: $0)?.standardizedFileURL.path } + [current.standardizedFileURL.path])
        let oldWallpaperFiles = folder.files.filter { $0.extension == "jpg" && !inUse.contains($0.url.standardizedFileURL.path) }
        guard !oldWallpaperFiles.isEmpty else {
            return
        }

        Log.info("Deleting old wallpaper files from previous runs")
        oldWallpaperFiles.forEach {
            try? $0.delete()
        }
    }
}
