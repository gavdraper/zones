import AppKit
import ZonesCore

/// The status-bar item: an entry to Settings, a picker for the active layout
/// (built-ins and the user's own), entry points to the editor, and quit. Layout
/// state lives in `LayoutLibrary`; this controller only renders it and forwards
/// intent.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let library: LayoutLibrary
    private let onNewLayout: () -> Void
    private let onEditLayout: (UserLayout) -> Void
    private let onShowSettings: () -> Void
    private let onShowHelp: () -> Void
    private let makeUpdateMenuItem: () -> NSMenuItem?

    init(
        library: LayoutLibrary,
        onNewLayout: @escaping () -> Void,
        onEditLayout: @escaping (UserLayout) -> Void,
        onShowSettings: @escaping () -> Void,
        onShowHelp: @escaping () -> Void,
        makeUpdateMenuItem: @escaping () -> NSMenuItem? = { nil }
    ) {
        self.library = library
        self.onNewLayout = onNewLayout
        self.onEditLayout = onEditLayout
        self.onShowSettings = onShowSettings
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

    /// Rebuilds the menu to reflect current state (the active layout and the set
    /// of user layouts).
    func refresh() {
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        addSettings(to: menu)
        menu.addItem(.separator())
        addBuiltinLayouts(to: menu)
        addUserLayouts(to: menu)
        menu.addItem(.separator())
        addEditorEntries(to: menu)
        menu.addItem(.separator())
        addHelp(to: menu)
        addUpdates(to: menu)
        addQuit(to: menu)
        statusItem.menu = menu
    }

    // MARK: - Menu sections

    private func addSettings(to menu: NSMenu) {
        let item = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        item.target = self
        menu.addItem(item)
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

    @objc private func showSettings() {
        onShowSettings()
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
