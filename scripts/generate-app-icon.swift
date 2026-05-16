#!/usr/bin/env swift
// Regenerates the app icon PNG assets from an SF Symbol.
//
// Usage:  swift scripts/generate-app-icon.swift
//
// Writes the 7 unique pixel sizes (16, 32, 64, 128, 256, 512, 1024) into
// ClaudeUsage/ClaudeUsage/Assets.xcassets/AppIcon.appiconset/, and rewrites
// Contents.json to reference them.

import AppKit
import Foundation

let symbolName  = "gauge.with.dots.needle.50percent"
let outputDir   = "ClaudeUsage/ClaudeUsage/Assets.xcassets/AppIcon.appiconset"
let background  = NSColor(red: 0.40, green: 0.32, blue: 0.92, alpha: 1.0) // indigo/violet
let symbolColor = NSColor.white

let pixelSizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]

// 10 appiconset slots → file mapping.
let slots: [(size: String, scale: String, pixel: Int)] = [
    ("16x16",   "1x",  16),
    ("16x16",   "2x",  32),
    ("32x32",   "1x",  32),
    ("32x32",   "2x",  64),
    ("128x128", "1x",  128),
    ("128x128", "2x",  256),
    ("256x256", "1x",  256),
    ("256x256", "2x",  512),
    ("512x512", "1x",  512),
    ("512x512", "2x",  1024),
]

func renderIcon(pixels: Int) -> NSImage {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let cornerRadius = size * 0.22
    let bgPath = NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )
    background.setFill()
    bgPath.fill()

    let symbolPointSize = size * 0.55
    let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .medium)
        .applying(.init(paletteColors: [symbolColor]))

    guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else {
        fputs("warning: could not load SF Symbol \(symbolName)\n", stderr)
        return image
    }

    let symbolSize = symbol.size
    let drawRect = NSRect(
        x: (size - symbolSize.width) / 2,
        y: (size - symbolSize.height) / 2,
        width:  symbolSize.width,
        height: symbolSize.height
    )
    symbol.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    return image
}

func savePNG(_ image: NSImage, pixels: Int, to dir: String) {
    let filename = "icon-\(pixels).png"
    let url = URL(fileURLWithPath: dir).appendingPathComponent(filename)
    guard
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
        let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    else {
        fputs("error: could not encode PNG for \(filename)\n", stderr)
        return
    }
    try? png.write(to: url)
    print("wrote \(filename) (\(pixels)x\(pixels))")
}

let fileManager = FileManager.default
try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for pixels in pixelSizes {
    let image = renderIcon(pixels: pixels)
    savePNG(image, pixels: pixels, to: outputDir)
}

// Rewrite Contents.json
struct ImageEntry: Codable {
    let filename: String
    let idiom: String
    let scale: String
    let size: String
}
struct Info: Codable { let author: String; let version: Int }
struct Contents: Codable { let images: [ImageEntry]; let info: Info }

let entries = slots.map {
    ImageEntry(filename: "icon-\($0.pixel).png", idiom: "mac", scale: $0.scale, size: $0.size)
}
let contents = Contents(
    images: entries,
    info: Info(author: "xcode", version: 1)
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(contents)
try data.write(to: URL(fileURLWithPath: outputDir).appendingPathComponent("Contents.json"))
print("rewrote Contents.json")
