import Testing
import CoreGraphics
@testable import ZonesCore

@Suite("Zone navigation")
struct ZoneNavigatorTests {

    private let display = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    // MARK: - currentZone (best overlap)

    @Test("Current zone is the one the window overlaps most")
    func currentZoneByOverlap() {
        let layout = LayoutTemplate.columns(3)
        // A window sitting squarely in the right column.
        let window = CGRect(x: 1300, y: 100, width: 500, height: 800)
        let zone = ZoneNavigator.currentZone(forWindowFrame: window, layout: layout, displayBounds: display)
        #expect(zone?.id == 2)
    }

    @Test("Current zone picks the larger overlap when a window straddles two zones")
    func currentZoneStraddling() {
        let layout = LayoutTemplate.columns(2)
        // Mostly in the left half (640 wide spans x 0..640; left zone is 0..960).
        let window = CGRect(x: 0, y: 0, width: 640, height: 1080)
        let zone = ZoneNavigator.currentZone(forWindowFrame: window, layout: layout, displayBounds: display)
        #expect(zone?.id == 0)
    }

    @Test("Current zone is nil when the window overlaps no zone")
    func currentZoneNoOverlap() {
        let layout = LayoutTemplate.columns(2)
        let window = CGRect(x: -2000, y: 0, width: 100, height: 100)
        let zone = ZoneNavigator.currentZone(forWindowFrame: window, layout: layout, displayBounds: display)
        #expect(zone == nil)
    }

    // MARK: - adjacentZone in columns

    @Test("Right/left move across columns")
    func columnsHorizontal() {
        let layout = LayoutTemplate.columns(3)
        let left = layout.zones[0]
        let middle = layout.zones[1]
        let right = layout.zones[2]

        #expect(ZoneNavigator.adjacentZone(from: left, direction: .right, in: layout)?.id == 1)
        #expect(ZoneNavigator.adjacentZone(from: middle, direction: .right, in: layout)?.id == 2)
        #expect(ZoneNavigator.adjacentZone(from: right, direction: .left, in: layout)?.id == 1)
        #expect(ZoneNavigator.adjacentZone(from: middle, direction: .left, in: layout)?.id == 0)
    }

    @Test("No neighbour past the edge of a column layout")
    func columnsEdges() {
        let layout = LayoutTemplate.columns(3)
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[0], direction: .left, in: layout) == nil)
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[2], direction: .right, in: layout) == nil)
        // Full-height columns have no vertical neighbour.
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[1], direction: .up, in: layout) == nil)
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[1], direction: .down, in: layout) == nil)
    }

    // MARK: - adjacentZone in a 2x2 grid (row-major: 0=TL,1=TR,2=BL,3=BR)

    @Test("Grid navigation moves to the orthogonally adjacent cell")
    func gridNavigation() {
        let layout = LayoutTemplate.grid(rows: 2, columns: 2)
        let topLeft = layout.zones[0]

        #expect(ZoneNavigator.adjacentZone(from: topLeft, direction: .right, in: layout)?.id == 1)
        #expect(ZoneNavigator.adjacentZone(from: topLeft, direction: .down, in: layout)?.id == 2)
        #expect(ZoneNavigator.adjacentZone(from: topLeft, direction: .left, in: layout) == nil)
        #expect(ZoneNavigator.adjacentZone(from: topLeft, direction: .up, in: layout) == nil)

        let bottomRight = layout.zones[3]
        #expect(ZoneNavigator.adjacentZone(from: bottomRight, direction: .up, in: layout)?.id == 1)
        #expect(ZoneNavigator.adjacentZone(from: bottomRight, direction: .left, in: layout)?.id == 2)
    }

    @Test("Diagonal cells are not treated as adjacent")
    func gridNoDiagonal() {
        let layout = LayoutTemplate.grid(rows: 2, columns: 2)
        // Moving up from bottom-right must reach top-right (1), never top-left (0).
        let result = ZoneNavigator.adjacentZone(from: layout.zones[3], direction: .up, in: layout)
        #expect(result?.id == 1)
    }

    // MARK: - Non-uniform layouts (reachable via the freeform editor)

    @Test("Unequal-width columns navigate by adjacency, not size")
    func priorityGridHorizontal() {
        // 25% / 50% / 25% — zones differ in width.
        let layout = LayoutTemplate.priorityGrid()
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[0], direction: .right, in: layout)?.id == 1)
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[1], direction: .right, in: layout)?.id == 2)
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[1], direction: .left, in: layout)?.id == 0)
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[2], direction: .left, in: layout)?.id == 1)
        #expect(ZoneNavigator.adjacentZone(from: layout.zones[1], direction: .up, in: layout) == nil)
    }

    @Test("L-shaped layout: a full-height zone beside two stacked zones")
    func lShapedNavigation() {
        // id0: left half, full height. id1: top-right. id2: bottom-right.
        let left = Zone(id: 0, normalizedFrame: CGRect(x: 0, y: 0, width: 0.5, height: 1))
        let topRight = Zone(id: 1, normalizedFrame: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
        let bottomRight = Zone(id: 2, normalizedFrame: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
        let layout = ZoneLayout(name: "L", zones: [left, topRight, bottomRight])

        // Vertical moves on the right column stay in the column (no diagonal to left).
        #expect(ZoneNavigator.adjacentZone(from: topRight, direction: .down, in: layout)?.id == 2)
        #expect(ZoneNavigator.adjacentZone(from: bottomRight, direction: .up, in: layout)?.id == 1)
        // Left from either right-column zone lands on the single tall zone.
        #expect(ZoneNavigator.adjacentZone(from: topRight, direction: .left, in: layout)?.id == 0)
        #expect(ZoneNavigator.adjacentZone(from: bottomRight, direction: .left, in: layout)?.id == 0)
        // The tall zone has no vertical neighbour.
        #expect(ZoneNavigator.adjacentZone(from: left, direction: .up, in: layout) == nil)
        #expect(ZoneNavigator.adjacentZone(from: left, direction: .down, in: layout) == nil)
    }

    // MARK: - nearestZone fallback

    @Test("Nearest zone is chosen by centre distance")
    func nearestZone() {
        let layout = LayoutTemplate.columns(3)
        // Point far right, outside but closest to the right column's centre.
        let zone = ZoneNavigator.nearestZone(to: CGPoint(x: 1900, y: 540), layout: layout, displayBounds: display)
        #expect(zone?.id == 2)
    }
}
