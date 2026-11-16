//
//  ChangeMenuBarColor+ImageManipulation.swift
//  ChangeMenuBarColor
//
//  Created by Igor Kulman on 19.11.2020.
//

#if canImport(Accessibility)
    import Accessibility
#endif
import Foundation
import Cocoa

func createGradientImage(startColor: NSColor, endColor: NSColor, width: CGFloat, height: CGFloat) -> NSImage? {
    guard let context = createContext(width: width, height: height) else {
        Log.error("Could not create graphical context for gradient image")
        return nil
    }

    context.drawLinearGradient(CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [startColor.cgColor, endColor.cgColor] as CFArray, locations: [0.0, 1.0])!, start: CGPoint(x: 0, y: 0), end: CGPoint(x: width, y: 0), options: [])

    guard let composedImage = context.makeImage() else {
        Log.error("Could not create composed image for gradient image")
        return nil
    }

    return NSImage(cgImage: composedImage, size: CGSize(width: width, height: height))
}

func createSolidImage(color: NSColor, width: CGFloat, height: CGFloat) -> NSImage? {
    guard let context = createContext(width: width, height: height) else {
        Log.error("Could not create graphical context for solid color image")
        return nil
    }

    context.setFillColor(color.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let composedImage = context.makeImage() else {
        Log.error("Could not create composed image for solid color image")
        return nil
    }

    return NSImage(cgImage: composedImage, size: CGSize(width: width, height: height))
}

func combineImages(baseImage: NSImage, addedImage: NSImage) -> NSImage? {
    let width = baseImage.size.width
    let height = baseImage.size.height

    // Compose in sRGB end to end with CoreGraphics. An NSBitmapImageRep in
    // calibratedRGB shifts colors on the JPEG roundtrip: dark colors come out
    // up to ~20% darker than the requested HEX.
    guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else {
        Log.error("Could not create sRGB color space")
        return nil
    }
    guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        Log.error("Could not create graphics context when merging images")
        return nil
    }

    guard let base = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        Log.error("Could not get CGImage of the base wallpaper")
        return nil
    }
    context.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))

    // The added image is created with the correct menu bar height for the screen, use it in full
    // (do not clamp to 24pt: notched displays have a taller menu bar)
    let menuBarHeight = addedImage.size.height
    guard let strip = addedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        Log.error("Could not get CGImage of the menu bar strip")
        return nil
    }
    context.draw(strip, in: CGRect(x: 0, y: height - menuBarHeight, width: width, height: menuBarHeight))

    guard let composed = context.makeImage() else {
        Log.error("Could not create composed image")
        return nil
    }

    return NSImage(cgImage: composed, size: CGSize(width: width, height: height))
}

func createContext(width: CGFloat, height: CGFloat) -> CGContext? {
    return CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
}

func colorName(_ color: NSColor) -> String {
    if #available(OSX 11.0, *) {
        return AXNameFromColor(color.cgColor)
    } else {
        return color.description
    }
}
