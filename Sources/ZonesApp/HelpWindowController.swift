import AppKit
import ZonesCore

/// A single row of help: an SF Symbol, a short title, and an explanation. The
/// `shortcut`, when present, is rendered as a key-cap style chip.
private struct HelpTopic {
    let symbol: String
    let title: String
    let detail: String
    let shortcut: String?
}

/// Shows a read-only window explaining the snapping gestures and hotkeys.
/// Mirrors ``EditorWindowController``'s lifecycle: the app runs as a menu-bar
/// agent (`.accessory`), so this promotes it to `.regular` while open and
/// demotes it on close, and keeps `isReleasedWhenClosed = false` so ARC remains
/// the sole owner of the window.
@MainActor
final class HelpWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onClose: () -> Void

    /// The move and region chord rows reflect the active scheme, so Help never
    /// advertises modifiers that no longer work.
    private static func topics(for scheme: HotkeyScheme) -> [HelpTopic] {
        [
            HelpTopic(
                symbol: "rectangle.split.3x1",
                title: "Snap a window to a zone",
                detail: "Hold Shift while dragging a window. Release it over a highlighted zone to snap it into place.",
                shortcut: "⇧ + drag"
            ),
            HelpTopic(
                symbol: "arrow.left.arrow.right",
                title: "Move between zones",
                detail: "Send the focused window to the next zone in any direction without touching the mouse.",
                shortcut: "\(scheme.moveModifiers.glyphs.joined(separator: " ")) + arrows"
            ),
            HelpTopic(
                symbol: "rectangle.lefthalf.inset.filled",
                title: "Snap to halves & quarters",
                detail: "Place the focused window without a layout: arrows for halves, U/I/J/K for quarters, Return to maximize, C to center.",
                shortcut: "\(scheme.regionModifiers.glyphs.joined(separator: " ")) + key"
            ),
            HelpTopic(
                symbol: "square.grid.2x2",
                title: "Switch layouts",
                detail: "Pick a built-in or your own layout from the Zones menu-bar icon.",
                shortcut: nil
            ),
            HelpTopic(
                symbol: "plus.rectangle",
                title: "Create a layout",
                detail: "Choose “New Layout…” to split a grid into the zones you want, then save it.",
                shortcut: nil
            ),
            HelpTopic(
                symbol: "slider.horizontal.3",
                title: "Gaps & hotkeys",
                detail: "Open “Settings…” to inset snapped windows with a gap, choose which modifier keys arm the hotkeys, and toggle the on-screen hints.",
                shortcut: nil
            )
        ]
    }

    private let topics: [HelpTopic]

    /// - Parameters:
    ///   - hotkeyScheme: the active modifier preset, so the hotkey rows show the
    ///     chords that actually fire.
    ///   - onClose: called when the window closes, so the owner can release this
    ///     controller.
    init(hotkeyScheme: HotkeyScheme, onClose: @escaping () -> Void) {
        self.topics = Self.topics(for: hotkeyScheme)
        self.onClose = onClose
        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 460, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.isReleasedWhenClosed = false
        window.title = "Zones Help"
        window.delegate = self

        // Size the window to its content's fitting height. The width is fixed at
        // 460 first so the wrapping detail labels compute their wrapped height
        // against the final layout width before we read `fittingSize`.
        let content = buildContentView()
        window.contentView = content
        window.layoutIfNeeded()
        window.setContentSize(NSSize(width: 460, height: content.fittingSize.height))
        window.center()
    }

    /// Brings the help window to the front, promoting the agent so it can take
    /// focus and order in front of other apps.
    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        Log.help.info("help window opened")
    }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let header = headerLabel()
        let rows = topics.map(topicRow)
        let stack = NSStackView(views: [header] + rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func headerLabel() -> NSView {
        let label = NSTextField(labelWithString: "Keyboard shortcuts & gestures")
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }

    private func topicRow(_ topic: HelpTopic) -> NSView {
        let icon = iconView(topic.symbol)
        let text = NSStackView(views: [titleLabel(topic), detailLabel(topic.detail)])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3

        let row = NSStackView(views: [icon, text])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        return row
    }

    private func iconView(_ symbol: String) -> NSView {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        let view = NSImageView(image: image ?? NSImage())
        view.contentTintColor = .controlAccentColor
        view.symbolConfiguration = .init(pointSize: 16, weight: .regular)
        view.setContentHuggingPriority(.required, for: .horizontal)
        // Pin a fixed width so the text columns of every row align.
        view.widthAnchor.constraint(equalToConstant: 22).isActive = true
        return view
    }

    private func titleLabel(_ topic: HelpTopic) -> NSView {
        let title = NSTextField(labelWithString: topic.title)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        guard let shortcut = topic.shortcut else { return title }

        let chip = shortcutChip(shortcut)
        let row = NSStackView(views: [title, chip])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func detailLabel(_ detail: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: detail)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 360
        return label
    }

    /// A rounded key-cap chip used to render a shortcut like "⌃ ⌥ + arrows".
    private func shortcutChip(_ shortcut: String) -> NSView {
        let label = NSTextField(labelWithString: shortcut)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center

        let chip = NSView()
        chip.wantsLayer = true
        chip.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        chip.layer?.cornerRadius = 5
        chip.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: chip.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -7)
        ])
        chip.setContentHuggingPriority(.required, for: .horizontal)
        return chip
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Demotion back to a menu-bar agent is owned by AppDelegate via onClose,
        // so closing this window doesn't hide another (Settings/Editor) still open.
        Log.help.info("help window closed")
        // Defer so the in-flight `close()` stack unwinds before `onClose`
        // releases the owner's last reference to this controller.
        DispatchQueue.main.async { [onClose] in onClose() }
    }
}
