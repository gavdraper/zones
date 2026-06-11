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

// A violet -> indigo vertical gradient — deliberately off the flat azure that
// reads as "Trello" — while staying legible when scaled to the 16pt Finder size.
let topColor = NSColor(srgbRed: 0.49, green: 0.36, blue: 1.00, alpha: 1.0)
let bottomColor = NSColor(srgbRed: 0.29, green: 0.19, blue: 0.83, alpha: 1.0)
// Zones render as translucent layout panels; one "active" zone is solid white to
// signal the snap target. Together with the asymmetric tiling this reads as a
// window-management grid, not a column of kanban cards.
let activeZoneFill = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.97)
let idleZoneFill = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.20)
let idleZoneStroke = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.55)
let strokeWidth: CGFloat = 7

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

// Asymmetric tiling: a large primary zone (top-left), a full-height sidebar on
// the right, and a wide bar along the bottom-left. This pinwheel layout is
// unmistakably "screen carved into regions" rather than equal kanban columns.
let sidebarWidth = grid.width * 0.30
let bottomHeight = grid.height * 0.30
let leftWidth = grid.width - sidebarWidth - gap
let primaryHeight = grid.height - bottomHeight - gap
let leftX = grid.minX
let rightX = grid.maxX - sidebarWidth

let primaryTile = NSRect(x: leftX, y: grid.minY + bottomHeight + gap, width: leftWidth, height: primaryHeight)
let sidebarTile = NSRect(x: rightX, y: grid.minY, width: sidebarWidth, height: grid.height)
let bottomTile = NSRect(x: leftX, y: grid.minY, width: leftWidth, height: bottomHeight)

// Idle zones first (translucent fill + stroke), then the solid active zone.
idleZoneFill.set()
idleZoneStroke.setStroke()
for tile in [sidebarTile, bottomTile] {
    let path = roundedPath(tile, radius: tileRadius)
    path.fill()
    path.lineWidth = strokeWidth
    path.stroke()
}

activeZoneFill.set()
roundedPath(primaryTile, radius: tileRadius).fill()

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
