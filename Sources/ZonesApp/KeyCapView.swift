import AppKit

/// A single rounded "key cap" showing one glyph, used to render the hotkey hint.
/// Sizes itself to a fixed square via Auto-Layout so caps line up in rows and
/// grids regardless of glyph width.
final class KeyCapView: NSView {

    /// Visual weight of a cap. Modifier caps are accent-tinted to stand apart
    /// from the action keys they combine with.
    enum Style {
        case standard
        case modifier

        var fill: NSColor {
            switch self {
            case .standard: return NSColor.white.withAlphaComponent(0.14)
            case .modifier: return NSColor.controlAccentColor.withAlphaComponent(0.30)
            }
        }

        var border: NSColor {
            switch self {
            case .standard: return NSColor.white.withAlphaComponent(0.30)
            case .modifier: return NSColor.controlAccentColor.withAlphaComponent(0.55)
            }
        }
    }

    private static let side: CGFloat = 38

    init(glyph: String, style: Style) {
        super.init(frame: .zero)
        configure(glyph: glyph, style: style)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure(glyph: String, style: Style) {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = style.fill.cgColor
        layer?.borderColor = style.border.cgColor
        layer?.borderWidth = 1

        let label = NSTextField(labelWithString: glyph)
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.side),
            heightAnchor.constraint(equalToConstant: Self.side),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
