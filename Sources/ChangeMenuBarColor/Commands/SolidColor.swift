//
//  SolidColor.swift
//  ArgumentParser
//
//  Created by Igor Kulman on 19.11.2020.
//

import ArgumentParser
import Cocoa
import Foundation

final class SolidColor: Command, ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "SolidColor",
        abstract: "Adds solid color rectangle"
    )

    @Argument(help: "HEX color to use for the menu bar")
    private var color: String

    @Argument(help: "Wallpaper to use. If not provided the current macOS wallpaper will be used")
    private var wallpaper: String?

    @Flag(help: "Flag to set wallpaper for all displays not just the main display")
    private var allDisplays: Bool = false

    override var useAllDisplays: Bool {
        return allDisplays
    }

    override var base: WallpaperPipeline.BaseSource {
        return wallpaper.map { .file(path: $0) } ?? .currentDesktop
    }

    override func spec() -> WallpaperPipeline.StripSpec? {
        guard let color: NSColor = NSColor(hexString: self.color) else {
            Log.error("Invalid HEX color provided. Make sure it includes the '#' symbol, e.g: #FF0000")
            return nil
        }
        return .solid(color: color)
    }
}
