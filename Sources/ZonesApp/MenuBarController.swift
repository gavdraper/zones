import AppKit
import ZonesCore

/// The status-bar item: an on/off toggle for snapping, a picker for the active
/// layout, and quit. Behaviour is delegated to the drag monitor and snap
/// controller it is given.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let dragMonitor: DragMonitor
    private let snapController: SnapController

    /// The selectable built-in layouts, in menu order.
    private let layouts: [ZoneLayout] = [
        LayoutTemplate.columns(2),
        LayoutTemplate.columns(3),
        LayoutTemplate.grid(rows: 2, columns: 2),
        LayoutTemplate.priorityGrid()
    ]

    init(dragMonitor: DragMonitor, snapController: SnapController) {
        self.dragMonitor = dragMonitor
        self.snapController = snapController
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

    /// Rebuilds the menu to reflect current state (e.g. after snapping becomes
    /// available once Accessibility is granted).
    func refresh() {
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: "Snapping Enabled", action: #selector(toggleSnapping), keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = dragMonitor.isRunning ? .on : .off
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Layout", action: nil, keyEquivalent: ""))
        for layout in layouts {
            let item = NSMenuItem(
                title: layout.name, action: #selector(selectLayout(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = layout.name
            item.state = (layout.name == snapController.layout.name) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Zones", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleSnapping(_ sender: NSMenuItem) {
        if dragMonitor.isRunning {
            dragMonitor.stop()
            sender.state = .off
        } else {
            // start() fails if Accessibility permission was revoked; don't claim
            // "enabled" when the tap never installed.
            sender.state = dragMonitor.start() ? .on : .off
        }
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let layout = layouts.first(where: { $0.name == name }) else { return }
        snapController.layout = layout
        buildMenu()   // refresh checkmarks
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
