import AppKit
import ZonesCore

/// The status-bar item: an on/off toggle for snapping, a picker for the active
/// layout (built-ins and the user's own), entry points to the editor, and quit.
/// Layout state lives in `LayoutLibrary`; this controller only renders it and
/// forwards intent.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let monitors: [InputMonitor]
    private let library: LayoutLibrary
    private let onNewLayout: () -> Void
    private let onEditLayout: (UserLayout) -> Void
    private let onShowHelp: () -> Void
    private let makeUpdateMenuItem: () -> NSMenuItem?

    init(
        monitors: [InputMonitor],
        library: LayoutLibrary,
        onNewLayout: @escaping () -> Void,
        onEditLayout: @escaping (UserLayout) -> Void,
        onShowHelp: @escaping () -> Void,
        makeUpdateMenuItem: @escaping () -> NSMenuItem? = { nil }
    ) {
        self.monitors = monitors
        self.library = library
        self.onNewLayout = onNewLayout
        self.onEditLayout = onEditLayout
        self.onShowHelp = onShowHelp
        self.makeUpdateMenuItem = makeUpdateMenuItem
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        buildMenu()
    }

    private func configureButton() {
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "Zones"
        )
    }

    /// Rebuilds the menu to reflect current state (snapping availability, the
    /// active layout, and the set of user layouts).
    func refresh() {
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        addSnappingToggle(to: menu)
        addHintsToggle(to: menu)
        menu.addItem(.separator())
        addBuiltinLayouts(to: menu)
        addUserLayouts(to: menu)
        menu.addItem(.separator())
        addEditorEntries(to: menu)
        menu.addItem(.separator())
        addGapMenu(to: menu)
        menu.addItem(.separator())
        addHelp(to: menu)
        addUpdates(to: menu)
        addQuit(to: menu)
        statusItem.menu = menu
    }

    // MARK: - Menu sections

    private func addSnappingToggle(to menu: NSMenu) {
        let toggle = NSMenuItem(title: "Snapping Enabled", action: #selector(toggleSnapping), keyEquivalent: "")
        toggle.target = self
        toggle.state = snappingEnabled ? .on : .off
        menu.addItem(toggle)
    }

    private func addHintsToggle(to menu: NSMenu) {
        let toggle = NSMenuItem(title: "Show Hotkey Hints", action: #selector(toggleHints), keyEquivalent: "")
        toggle.target = self
        toggle.state = library.hintsEnabled ? .on : .off
        menu.addItem(toggle)
    }

    private func addBuiltinLayouts(to menu: NSMenu) {
        menu.addItem(sectionHeader("Layout"))
        for layout in library.builtins {
            let item = NSMenuItem(title: layout.name, action: #selector(selectBuiltin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = layout.name
            item.state = isActiveBuiltin(layout.name) ? .on : .off
            menu.addItem(item)
        }
    }

    private func addUserLayouts(to menu: NSMenu) {
        guard !library.userLayouts.isEmpty else { return }
        menu.addItem(sectionHeader("My Layouts"))
        for layout in library.userLayouts {
            let item = NSMenuItem(title: layout.name, action: nil, keyEquivalent: "")
            item.state = isActiveUser(layout.id) ? .on : .off
            item.submenu = userLayoutSubmenu(for: layout)
            menu.addItem(item)
        }
    }

    private func userLayoutSubmenu(for layout: UserLayout) -> NSMenu {
        let submenu = NSMenu()
        submenu.addItem(menuItem("Use This Layout", #selector(selectUser(_:)), id: layout.id))
        submenu.addItem(menuItem("Edit…", #selector(editUser(_:)), id: layout.id))
        submenu.addItem(.separator())
        submenu.addItem(menuItem("Delete", #selector(deleteUser(_:)), id: layout.id))
        return submenu
    }

    private func addEditorEntries(to menu: NSMenu) {
        let new = NSMenuItem(title: "New Layout…", action: #selector(newLayout), keyEquivalent: "n")
        new.target = self
        menu.addItem(new)
    }

    /// Preset gap sizes (points) offered in the menu.
    private static let gapPresets: [Double] = [0, 4, 8, 12, 16]

    private func addGapMenu(to menu: NSMenu) {
        let item = NSMenuItem(title: "Gaps", action: nil, keyEquivalent: "")
        item.submenu = gapSubmenu()
        menu.addItem(item)
    }

    private func gapSubmenu() -> NSMenu {
        let submenu = NSMenu()
        for preset in Self.gapPresets {
            let title = preset == 0 ? "None" : "\(Int(preset)) pt"
            let entry = NSMenuItem(title: title, action: #selector(setGap(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = preset
            entry.state = library.gap == CGFloat(preset) ? .on : .off
            submenu.addItem(entry)
        }
        return submenu
    }

    private func addHelp(to menu: NSMenu) {
        let help = NSMenuItem(title: "Zones Help", action: #selector(showHelp), keyEquivalent: "?")
        help.target = self
        menu.addItem(help)
    }

    /// Adds "Check for Updates…" when an updater is wired in. Absent in dev
    /// builds that don't supply one, so the menu silently omits it.
    private func addUpdates(to menu: NSMenu) {
        guard let item = makeUpdateMenuItem() else { return }
        menu.addItem(item)
    }

    private func addQuit(to menu: NSMenu) {
        let quit = NSMenuItem(title: "Quit Zones", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> NSMenuItem {
        NSMenuItem(title: title, action: nil, keyEquivalent: "")
    }

    private func menuItem(_ title: String, _ action: Selector, id: UUID) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = id
        return item
    }

    private func isActiveBuiltin(_ name: String) -> Bool {
        library.selection == .builtin(name: name)
    }

    private func isActiveUser(_ id: UUID) -> Bool {
        library.selection == .user(id: id)
    }

    // MARK: - Actions

    /// Snapping is on when every input monitor is installed; they start and stop
    /// as a group.
    private var snappingEnabled: Bool {
        !monitors.isEmpty && monitors.allSatisfy(\.isRunning)
    }

    @objc private func toggleSnapping(_ sender: NSMenuItem) {
        if snappingEnabled {
            monitors.forEach { $0.stop() }
            sender.state = .off
        } else {
            let started = monitors.map { $0.start() }
            sender.state = started.allSatisfy { $0 } ? .on : .off
        }
    }

    @objc private func toggleHints() {
        library.setHintsEnabled(!library.hintsEnabled)
    }

    @objc private func selectBuiltin(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        library.selectBuiltin(named: name)
    }

    @objc private func selectUser(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        library.selectUser(id: id)
    }

    @objc private func editUser(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID, let layout = library.userLayout(id: id) else { return }
        onEditLayout(layout)
    }

    @objc private func deleteUser(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID, let layout = library.userLayout(id: id) else { return }
        guard confirmDeletion(of: layout.name) else { return }
        library.remove(id: id)
    }

    @objc private func setGap(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        library.setGap(CGFloat(value))
    }

    @objc private func newLayout() {
        onNewLayout()
    }

    @objc private func showHelp() {
        onShowHelp()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func confirmDeletion(of name: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Delete “\(name)”?"
        alert.informativeText = "This layout will be removed permanently."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
