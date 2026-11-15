//
//  File.swift
//  
//
//  Created by Igor Kulman on 21.11.2020.
//

import Foundation
import Cocoa

extension NSScreen {
    var size: CGSize {
        return CGSize(width: frame.size.width * backingScaleFactor, height: frame.size.height * backingScaleFactor)
    }

    var menuBarHeight: CGFloat {
        // Notched displays (macOS 12+): the auxiliary areas beside the camera housing
        // are exactly as tall as the menu bar
        if #available(macOS 12.0, *) {
            if let auxiliaryAreaHeight = auxiliaryTopRightArea?.height ?? auxiliaryTopLeftArea?.height, auxiliaryAreaHeight > 0 {
                let height = auxiliaryAreaHeight * backingScaleFactor
                Log.debug("Using menu bar height \(height) from auxiliary area (notched display)")
                return height
            }
        }

        // Get the height difference between full frame and visible frame
        let calculatedHeight = (frame.size.height - visibleFrame.height - visibleFrame.origin.y) * backingScaleFactor

        // Apply safety limits in points (the value above is in pixels):
        // the menu bar is typically 22-25 points, up to about 40 points with the notch
        let calculatedHeightInPoints = calculatedHeight / backingScaleFactor
        if calculatedHeightInPoints <= 0 || calculatedHeightInPoints > 50 {
            Log.debug("Menu bar height calculation appears incorrect (\(calculatedHeight)), using standard height")
            return 24 * backingScaleFactor // Standard menu bar height
        }

        Log.debug("Using calculated menu bar height: \(calculatedHeight)")
        return calculatedHeight
    }
}
