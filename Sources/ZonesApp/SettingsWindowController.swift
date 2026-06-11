import AppKit
import ZonesCore

/// The app's Settings window: window gaps, the keyboard hotkey preset, and the
/// hint toggle, all editing ``LayoutLibrary`` directly so changes persist and
/// notify the rest of the app at once.
///
/// Mirrors ``HelpWindowController``'s lifecycle: the app runs as a menu-bar
/// agent (`.accessory`), so this promotes it to `.regular` while open and
/// demotes it on close, and keeps `isReleasedWhenClosed = false` so ARC remains
/// the sole owner of the window.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let library: LayoutLibrary
    private let onClose: () -> Void

    /// Gap sizes (points) offered in the segmented control.
    private static let gapPresets: [Double] = [0, 4, 8, 12, 16]

    private let gapControl = NSSegmentedControl()
    private let schemePopUp = NSPopUpButton()
    private let schemePreview = NSTextField(labelWithString: "")
    private let hintsCheckbox = NSButton()

    /// - Parameter onClose: called when the window closes, so the owner can
    ///   release this controller.
    init(library: LayoutLibrary, onClose: @escaping () -> Void) {
        self.library = library
        self.onClose = onClose
        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 460, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.isReleasedWhenClosed = false
        window.title = "Zones Settings"
        window.delegate = self
        let content = buildContentView()
        window.contentView = content
        // Size the window to the content's natural height so the sections keep
        // their fixed spacing instead of the stack stretching to fill a taller
        // window and leaving a dead gap between sections.
        window.setContentSize(NSSize(width: 460, height: content.fittingSize.height))
        window.center()
        syncFromLibrary()
    }

    /// Brings the settings window to the front, promoting the agent so it can
    /// take focus and order in front of other apps.
    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        Log.app.info("settings window opened")
    }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let stack = NSStackView(views: [
            section(title: "Gaps", control: gapsControl(), help: "Spacing inset around every snapped window."),
            section(title: "Hotkeys", control: hotkeysControl(), help: "Modifier keys held to move between zones and snap to regions."),
            hintsControl()
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
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

    /// A titled section: a bold heading, the control, and a secondary caption.
    private func section(title: String, control: NSView, help: String) -> NSView {
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 13, weight: .semibold)

        let caption = NSTextField(wrappingLabelWithString: help)
        caption.font = .systemFont(ofSize: 11)
        caption.textColor = .secondaryLabelColor
        caption.preferredMaxLayoutWidth = 400

        let stack = NSStackView(views: [heading, control, caption])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func gapsControl() -> NSView {
        gapControl.segmentCount = Self.gapPresets.count
        gapControl.segmentStyle = .texturedRounded
        gapControl.trackingMode = .selectOne
        for (index, preset) in Self.gapPresets.enumerated() {
            gapControl.setLabel(preset == 0 ? "None" : "\(Int(preset)) pt", forSegment: index)
        }
        gapControl.target = self
        gapControl.action = #selector(gapChanged)
        return gapControl
    }

    private func hotkeysControl() -> NSView {
        schemePopUp.addItems(withTitles: HotkeyScheme.allCases.map(\.displayName))
        schemePopUp.target = self
        schemePopUp.action = #selector(schemeChanged)
        schemePopUp.setContentHuggingPriority(.required, for: .horizontal)

        schemePreview.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        schemePreview.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [schemePopUp, schemePreview])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func hintsControl() -> NSView {
        hintsCheckbox.setButtonType(.switch)
        hintsCheckbox.title = "Show hotkey hints while modifiers are held"
        hintsCheckbox.target = self
        hintsCheckbox.action = #selector(hintsChanged)
        return hintsCheckbox
    }

    // MARK: - State

    /// Pulls the persisted values into the controls so the window opens showing
    /// the current settings.
    private func syncFromLibrary() {
        if let index = Self.gapPresets.firstIndex(of: Double(library.gap)) {
            gapControl.selectedSegment = index
        }
        if let index = HotkeyScheme.allCases.firstIndex(of: library.hotkeyScheme) {
            schemePopUp.selectItem(at: index)
        }
        hintsCheckbox.state = library.hintsEnabled ? .on : .off
        updateSchemePreview()
    }

    /// Renders the chords the selected scheme produces, e.g. "Move ⌃⌥   ·   Snap ⌃⌥⌘".
    private func updateSchemePreview() {
        let scheme = selectedScheme
        let move = scheme.moveModifiers.glyphs.joined()
        let region = scheme.regionModifiers.glyphs.joined()
        schemePreview.stringValue = "Move \(move)   ·   Snap to region \(region)"
    }

    private var selectedScheme: HotkeyScheme {
        let index = schemePopUp.indexOfSelectedItem
        let all = HotkeyScheme.allCases
        return all.indices.contains(index) ? all[index] : .default
    }

    // MARK: - Actions

    @objc private func gapChanged() {
        let index = gapControl.selectedSegment
        guard Self.gapPresets.indices.contains(index) else { return }
        library.setGap(CGFloat(Self.gapPresets[index]))
    }

    @objc private func schemeChanged() {
        library.setHotkeyScheme(selectedScheme)
        updateSchemePreview()
    }

    @objc private func hintsChanged() {
        library.setHintsEnabled(hintsCheckbox.state == .on)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Demotion back to a menu-bar agent is owned by AppDelegate via onClose,
        // so closing this window doesn't hide another (Editor/Help) still open.
        Log.app.info("settings window closed")
        // Defer so the in-flight `close()` stack unwinds before `onClose`
        // releases the owner's last reference to this controller.
        DispatchQueue.main.async { [onClose] in onClose() }
    }
}
