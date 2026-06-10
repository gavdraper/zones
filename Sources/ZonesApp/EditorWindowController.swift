import AppKit
import ZonesCore

/// Hosts the grid editor in a real window. Because the app runs as a menu-bar
/// agent (`.accessory`, no Dock icon and can't take key focus), this controller
/// temporarily promotes the app to `.regular` while the window is open and
/// demotes it again on close — otherwise the editor couldn't receive keyboard
/// input or come to the front.
@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let viewModel: GridEditorViewModel
    private let editorView: GridEditorView
    private let nameField = NSTextField()

    /// A dedicated undo manager for grid edits, kept separate from the name
    /// field's text editing so the two don't interleave.
    private let gridUndoManager = UndoManager()

    private let onClose: () -> Void

    /// - Parameters:
    ///   - layout: an existing layout to edit, or `nil` for a new one.
    ///   - onSave: receives the committed layout.
    ///   - onClose: called when the window closes, so the owner can release this.
    init(
        editing layout: UserLayout? = nil,
        onSave: @escaping (UserLayout) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        let undoManager = gridUndoManager
        self.viewModel = GridEditorViewModel(layout: layout, undoManager: undoManager, onCommit: onSave)
        self.editorView = GridEditorView(viewModel: viewModel)

        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init()

        // This controller owns the window via a strong reference, so ARC must be
        // its sole owner. Left at the default `true`, `close()` would release the
        // window in addition to ARC, over-releasing it into a crash.
        window.isReleasedWhenClosed = false
        window.title = layout.map { "Edit “\($0.name)”" } ?? "New Zone Layout"
        window.delegate = self
        window.center()
        nameField.stringValue = viewModel.name
        window.contentView = buildContentView()
    }

    /// Brings the editor to the front, promoting the agent so it can take focus.
    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        Log.editor.info("editor window opened")
    }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let toolbar = buildToolbar()
        let container = NSView()
        container.addSubview(toolbar)
        container.addSubview(editorView)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        editorView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            editorView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            editorView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            editorView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func buildToolbar() -> NSView {
        let edits = NSStackView(views: [
            button(symbol: "rectangle.split.2x1", tooltip: "Split into left / right", action: #selector(splitVertical)),
            button(symbol: "rectangle.split.1x2", tooltip: "Split into top / bottom", action: #selector(splitHorizontal)),
            button(symbol: "arrow.triangle.merge", tooltip: "Merge selected zone", action: #selector(merge)),
            button(symbol: "arrow.uturn.backward", tooltip: "Undo", action: #selector(undo)),
            button(symbol: "arrow.uturn.forward", tooltip: "Redo", action: #selector(redo))
        ])
        edits.orientation = .horizontal
        edits.spacing = 6

        nameField.placeholderString = "Layout name"
        nameField.controlSize = .large
        nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"

        let bar = NSStackView(views: [edits, nameField, cancel, save])
        bar.orientation = .horizontal
        bar.spacing = 10
        bar.alignment = .centerY
        return bar
    }

    private func button(symbol: String, tooltip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        let button = NSButton(image: image ?? NSImage(), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.toolTip = tooltip
        return button
    }

    // MARK: - Actions

    @objc private func splitVertical() { editorView.splitSelection(axis: .vertical) }
    @objc private func splitHorizontal() { editorView.splitSelection(axis: .horizontal) }
    @objc private func merge() { editorView.mergeSelection() }

    @objc private func undo() {
        gridUndoManager.undo()
        editorView.needsDisplay = true
    }

    @objc private func redo() {
        gridUndoManager.redo()
        editorView.needsDisplay = true
    }

    @objc private func save() {
        let trimmed = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.name = trimmed.isEmpty ? "Custom Layout" : trimmed
        viewModel.commit()
        window.close()
    }

    @objc private func cancel() {
        window.close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Log.editor.info("editor window closed")
        // `onClose` releases the owner's last strong reference to this controller.
        // Deferring it lets the in-flight `close()` call stack unwind first, so the
        // controller (and its window) aren't deallocated out from under AppKit.
        DispatchQueue.main.async { [onClose] in onClose() }
    }
}
