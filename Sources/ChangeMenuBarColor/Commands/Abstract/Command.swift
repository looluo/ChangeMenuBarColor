//
//  Command.swift
//  ChangeMenuBarColor
//
//  Created by Igor Kulman on 19.11.2020.
//

import Cocoa
import Foundation

class Command {
    func spec() -> WallpaperPipeline.StripSpec? {
        fatalError("Override for each type")
    }

    var useAllDisplays: Bool {
        fatalError("Override for each type")
    }

    var base: WallpaperPipeline.BaseSource {
        fatalError("Override for each type")
    }

    func run() {
        Log.info("Starting up\n")

        let screens: [NSScreen] = useAllDisplays ? NSScreen.screens : [NSScreen.main].compactMap({ $0 })

        guard !screens.isEmpty else {
            Log.error("Could not detect any screens")
            return
        }

        let pipeline = WallpaperPipeline()

        for (index, screen) in screens.enumerated() {
            guard let spec = spec(), pipeline.apply(spec: spec, base: base, screen: screen) != nil else {
                Log.error("Could not generate new wallpaper screen \(index)")
                continue
            }
        }

        Log.info("\nAll done!")
    }
}
