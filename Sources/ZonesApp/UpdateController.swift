import AppKit
import Sparkle

/// Owns the Sparkle updater and vends the "Check for Updates…" menu item.
/// All Sparkle knowledge lives here so the rest of the app stays
/// framework-agnostic — `MenuBarController` only asks for a menu item.
///
/// Update behaviour (feed URL, public signing key, automatic-check policy) is
/// configured via the `SU*` keys in the bundle's Info.plist; see Scripts/bundle.sh.
@MainActor
final class UpdateController {
    private let controller: SPUStandardUpdaterController

    init() {
        // `startingUpdater: true` boots the scheduled background check straight
        // away, honouring SUEnableAutomaticChecks / SUScheduledCheckInterval.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// A fresh item on every call: the menu is rebuilt on each `refresh()`, and
    /// an `NSMenuItem` can only belong to one menu at a time. Targeting the
    /// standard controller also gives us automatic validation (the item disables
    /// itself while a check is already in flight).
    func makeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        item.target = controller
        return item
    }
}
