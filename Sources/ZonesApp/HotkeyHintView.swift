import AppKit
import ZonesCore

/// The contents of the hotkey-hint HUD: a blurred rounded panel showing the held
/// modifier keys, a one-line title, the four directional arrows (as a cross), and
/// — for the region chord — the extra keys with captions.
///
/// Purely presentational and Auto-Layout driven, so the window controller can
/// size the window to `fittingSize`. Assigning ``content`` rebuilds the panel.
final class HotkeyHintView: NSView {

    private let panel = NSVisualEffectView()
    private let stack = NSStackView()

    var content: HotkeyHintContent? {
        didSet { rebuild() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        panel.material = .hudWindow
        panel.state = .active
        panel.blendingMode = .behindWindow
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 18
        panel.layer?.masksToBounds = true
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)

        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Building

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let content else { return }

        stack.addArrangedSubview(modifierRow(content.modifierGlyphs))
        stack.addArrangedSubview(titleLabel(content.title))
        stack.addArrangedSubview(arrowCross(content.arrows))
        if !content.extras.isEmpty {
            stack.addArrangedSubview(extrasGrid(content.extras))
        }
    }

    /// The held modifier keys, drawn as accent-tinted caps.
    private func modifierRow(_ glyphs: [String]) -> NSView {
        let row = NSStackView(views: glyphs.map { KeyCapView(glyph: $0, style: .modifier) })
        row.orientation = .horizontal
        row.spacing = 8
        return row
    }

    private func titleLabel(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        return label
    }

    /// The four arrows laid out as a directional cross. Captions (region chord)
    /// sit beneath each cap; the move chord has none and shows a tighter cross.
    private func arrowCross(_ arrows: [HintKey]) -> NSView {
        let byGlyph = Dictionary(arrows.map { ($0.glyph, $0) }, uniquingKeysWith: { first, _ in first })
        let grid = NSGridView(numberOfColumns: 3, rows: 3)
        grid.rowSpacing = 6
        grid.columnSpacing = 6
        for column in 0..<3 { grid.column(at: column).xPlacement = .center }

        place(byGlyph["↑"], in: grid, row: 0, column: 1)
        place(byGlyph["←"], in: grid, row: 1, column: 0)
        place(byGlyph["→"], in: grid, row: 1, column: 2)
        place(byGlyph["↓"], in: grid, row: 2, column: 1)
        return grid
    }

    private func place(_ key: HintKey?, in grid: NSGridView, row: Int, column: Int) {
        guard let key else { return }
        grid.cell(atColumnIndex: column, rowIndex: row).contentView = captionedCap(key, style: .standard)
    }

    /// The region-only extra keys (quarters, maximize, center), wrapped into rows
    /// of three captioned caps.
    private func extrasGrid(_ extras: [HintKey]) -> NSView {
        let rows = stride(from: 0, to: extras.count, by: 3).map { start -> NSView in
            let slice = extras[start..<min(start + 3, extras.count)]
            let row = NSStackView(views: slice.map { captionedCap($0, style: .standard) })
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 12
            return row
        }
        let column = NSStackView(views: rows)
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 12
        return column
    }

    /// A key cap with its caption (if any) stacked beneath, kept to a uniform
    /// width so captions don't shove neighbouring caps out of alignment.
    private func captionedCap(_ key: HintKey, style: KeyCapView.Style) -> NSView {
        let cap = KeyCapView(glyph: key.glyph, style: style)
        guard let caption = key.caption else { return cap }

        let label = NSTextField(labelWithString: caption)
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center

        let column = NSStackView(views: [cap, label])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 4
        return column
    }
}
