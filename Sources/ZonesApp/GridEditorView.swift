import AppKit
import ZonesCore

/// Interactive canvas for editing a grid layout. It renders the view-model's
/// cells and dividers, and translates mouse gestures into view-model calls:
/// click selects a cell, dragging a divider resizes it. It owns no layout
/// logic — every mutation goes through `GridEditorViewModel`, which works in the
/// unit square this view maps to and from.
///
/// The view is **flipped** (top-left origin), matching the grid's coordinate
/// space, so mapping is a pure scale by `bounds` with no Quartz/AppKit flip.
final class GridEditorView: NSView {
    private let viewModel: GridEditorViewModel

    /// The unit-square point of the currently selected cell's centre, if any.
    private(set) var selection: CGPoint?

    /// Pixel tolerance for grabbing a divider.
    private let dividerGrabRadius: CGFloat = 6

    private var activeDivider: GridDivider?

    init(viewModel: GridEditorViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        viewModel.onChange = { [weak self] in self?.needsDisplay = true }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Public edit hooks (driven by the window's toolbar)

    func splitSelection(axis: GridAxis) {
        guard let selection else { return }
        viewModel.splitCell(at: selection, axis: axis)
    }

    func mergeSelection() {
        guard let selection else { return }
        viewModel.mergeCell(at: selection)
        // The merged cell may no longer exist; recentre selection on what's there.
        self.selection = viewModel.grid.rect(at: viewModel.grid.leafPath(at: selection) ?? .root)?.center
        needsDisplay = true
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let divider = divider(near: point) {
            activeDivider = divider
            viewModel.beginResize()
            return
        }

        // Otherwise select the cell under the cursor.
        let unit = unitPoint(point)
        if let path = viewModel.grid.leafPath(at: unit) {
            selection = viewModel.grid.rect(at: path)?.center
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let divider = activeDivider else { return }
        let unit = unitPoint(convert(event.locationInWindow, from: nil))
        guard let region = viewModel.grid.rect(at: divider.id) else { return }

        let ratio: Double
        switch divider.axis {
        case .vertical:
            ratio = region.width > 0 ? Double((unit.x - region.minX) / region.width) : 0.5
        case .horizontal:
            ratio = region.height > 0 ? Double((unit.y - region.minY) / region.height) : 0.5
        }
        viewModel.updateResize(divider.id, to: ratio)
    }

    override func mouseUp(with event: NSEvent) {
        guard activeDivider != nil else { return }
        activeDivider = nil
        viewModel.endResize()
    }

    override func resetCursorRects() {
        for divider in viewModel.grid.dividers() {
            let band = grabBand(for: divider)
            let cursor: NSCursor = divider.axis == .vertical ? .resizeLeftRight : .resizeUpDown
            addCursorRect(band, cursor: cursor)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: CGRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        for zone in viewModel.grid.zones() {
            drawCell(zone)
        }
        for divider in viewModel.grid.dividers() {
            drawDivider(divider)
        }
    }

    private func drawCell(_ zone: Zone) {
        let rect = viewRect(zone.normalizedFrame).insetBy(dx: 4, dy: 4)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)

        let isSelected = selection.map { zone.normalizedFrame.contains($0) } ?? false
        if isSelected {
            NSColor.controlAccentColor.withAlphaComponent(0.30).setFill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 3
        } else {
            NSColor.controlAccentColor.withAlphaComponent(0.10).setFill()
            NSColor.tertiaryLabelColor.setStroke()
            path.lineWidth = 1.5
        }
        path.fill()
        path.stroke()

        drawLabel("\(zone.id + 1)", in: rect)
    }

    private func drawLabel(_ text: String, in rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        let origin = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        text.draw(at: origin, withAttributes: attributes)
    }

    private func drawDivider(_ divider: GridDivider) {
        let band = viewRect(divider.bounds)
        let line = NSBezierPath()
        if divider.axis == .vertical {
            line.move(to: CGPoint(x: band.midX, y: band.minY + 4))
            line.line(to: CGPoint(x: band.midX, y: band.maxY - 4))
        } else {
            line.move(to: CGPoint(x: band.minX + 4, y: band.midY))
            line.line(to: CGPoint(x: band.maxX - 4, y: band.midY))
        }
        NSColor.separatorColor.setStroke()
        line.lineWidth = 2
        line.stroke()
    }

    // MARK: - Coordinate mapping (unit square ↔ flipped view)

    private func viewRect(_ unit: CGRect) -> CGRect {
        CGRect(
            x: unit.minX * bounds.width,
            y: unit.minY * bounds.height,
            width: unit.width * bounds.width,
            height: unit.height * bounds.height
        )
    }

    private func unitPoint(_ point: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        return CGPoint(x: point.x / bounds.width, y: point.y / bounds.height)
    }

    /// The pixel band around a divider that accepts a grab/drag.
    private func grabBand(for divider: GridDivider) -> CGRect {
        viewRect(divider.bounds).insetBy(dx: -dividerGrabRadius, dy: -dividerGrabRadius)
    }

    private func divider(near point: CGPoint) -> GridDivider? {
        viewModel.grid.dividers().first { grabBand(for: $0).contains(point) }
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
