#!/usr/bin/env swift
// Renders the Zones app icon master PNG (1024x1024).
//
// The motif is a FancyZones-style priority grid — one tall zone on the left and
// two stacked zones on the right — which is exactly what Zones does: snap windows
// into named layout regions. Drawn with AppKit so there is no external tooling or
// asset dependency; Scripts/make-icon.sh turns the master into an .icns.
//
// Usage: swift Scripts/make-icon.swift <output.png>   (defaults to ./icon-1024.png)

import AppKit
import Foundation

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"

// MARK: - Palette

// A blue -> indigo vertical gradient reads as "system utility" and stays legible
// when scaled down to the 16pt Finder size.
let topColor = NSColor(srgbRed: 0.32, green: 0.55, blue: 1.00, alpha: 1.0)
let bottomColor = NSColor(srgbRed: 0.20, green: 0.33, blue: 0.86, alpha: 1.0)
let zoneFill = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.96)

// MARK: - Geometry

// Apple ships app art inset within the 1024 canvas (~100px margins) so the
// squircle never touches the edge. Corner radius ~22.37% of the squircle side.
let margin: CGFloat = 100
let squircle = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
let cornerRadius = squircle.width * 0.2237

// The zone grid sits inset within the squircle.
let gridInset: CGFloat = 118
let grid = squircle.insetBy(dx: gridInset, dy: gridInset)
let gap: CGFloat = 30
let tileRadius: CGFloat = 34

func roundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

// MARK: - Render

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Transparent canvas outside the squircle.
NSColor.clear.set()
NSRect(x: 0, y: 0, width: size, height: size).fill()

// Squircle background gradient.
let background = roundedPath(squircle, radius: cornerRadius)
background.addClip()
NSGradient(starting: topColor, ending: bottomColor)!
    .draw(in: squircle, angle: -90)
NSGraphicsContext.current?.cgContext.resetClip()

// Zone tiles: left column full height; right column split top/bottom.
let columnWidth = (grid.width - gap) / 2
let rowHeight = (grid.height - gap) / 2

let leftTile = NSRect(x: grid.minX, y: grid.minY, width: columnWidth, height: grid.height)
let rightX = grid.minX + columnWidth + gap
let rightTop = NSRect(x: rightX, y: grid.minY + rowHeight + gap, width: columnWidth, height: rowHeight)
let rightBottom = NSRect(x: rightX, y: grid.minY, width: columnWidth, height: rowHeight)

zoneFill.set()
for tile in [leftTile, rightTop, rightBottom] {
    roundedPath(tile, radius: tileRadius).fill()
}

NSGraphicsContext.restoreGraphicsState()

// MARK: - Write PNG

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
do {
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath) (\(Int(size))x\(Int(size)))")
} catch {
    FileHandle.standardError.write("Failed to write \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}
