#!/usr/bin/env swift
//
// Renders Resources/AppIcon.icns from scratch so the repo carries no binary blobs.
// Usage: swift Tools/MakeIcon.swift <output.icns>
//

import AppKit
import Foundation

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"

/// Pick the first symbol the running OS actually ships.
func symbol(_ names: [String]) -> NSImage? {
    for name in names {
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            return image
        }
    }
    return nil
}

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = rect.insetBy(dx: size * 0.06, dy: size * 0.06)
    let squircle = NSBezierPath(roundedRect: inset,
                                xRadius: inset.width * 0.225,
                                yRadius: inset.width * 0.225)

    NSGradient(colors: [
        NSColor(calibratedRed: 0.32, green: 0.52, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.72, alpha: 1),
    ])?.draw(in: squircle, angle: -90)

    if let glyph = symbol(["laptopcomputer", "macbook"]) {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.44, weight: .regular)
        let sized = glyph.withSymbolConfiguration(config) ?? glyph

        // Tint in an offscreen image. Filling `.sourceAtop` directly on the icon
        // canvas would repaint the opaque gradient, not just the glyph.
        let tinted = NSImage(size: sized.size)
        tinted.lockFocus()
        sized.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(origin: .zero, size: sized.size).fill(using: .sourceAtop)
        tinted.unlockFocus()

        tinted.draw(in: NSRect(
            x: (size - sized.size.width) / 2,
            y: (size - sized.size.height) / 2,
            width: sized.size.width,
            height: sized.size.height
        ))
    }

    image.unlockFocus()
    return image
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("Clamshell-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// The sizes `iconutil` expects, each at 1x and 2x.
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = CGFloat(base * scale)
        let rendered = render(size: pixels)
        guard let tiff = rendered.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { continue }
        let suffix = scale == 1 ? "" : "@2x"
        let name = "icon_\(base)x\(base)\(suffix).png"
        try? png.write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)

guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil failed\n".data(using: .utf8)!)
    exit(1)
}
print("Wrote \(output)")
