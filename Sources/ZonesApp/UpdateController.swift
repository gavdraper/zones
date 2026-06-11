import AppKit
import Sparkle

/// Owns the Sparkle updater and vends the "Check for Updates…" menu item.
/// All Sparkle knowledge lives here so the rest of the app stays
/// framework-agnostic — `MenuBarController` only asks for a menu item.
///
/// Update behaviour (feed URL, public signing key, automatic-check policy) is
/// configured via the `SU*` keys in the bundle's Info.plist; see Scripts/bundle.sh.
///
/// Because the app runs as an `.accessory` agent (`LSUIElement`, no Dock icon
/// and not frontmost), Sparkle's windows would otherwise open *behind* whatever
/// app is currently active. We bring the app forward both when the check is
/// triggered and — via `SPUStandardUserDriverDelegate` — right before Sparkle
/// shows the update dialog, which arrives asynchronously after the appcast fetch.
@MainActor
final class UpdateController: NSObject {
    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        // `startingUpdater: true` boots the scheduled background check straight
        // away, honouring SUEnableAutomaticChecks / SUScheduledCheckInterval.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }

    /// A fresh item on every call: the menu is rebuilt on each `refresh()`, and
    /// an `NSMenuItem` can only belong to one menu at a time.
    func makeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        item.target = self
        return item
    }

    /// Activate first so the immediate "you're up to date" / error alerts land
    /// in front, then hand off to Sparkle's standard check.
    @objc private func checkForUpdates() {
        bringToFront()
        controller.checkForUpdates(nil)
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - SPUStandardUserDriverDelegate

extension UpdateController: SPUStandardUserDriverDelegate {
    /// Fired just before Sparkle presents an available-update dialog. By this
    /// point the async appcast fetch has completed and focus may have drifted
    /// back to another app, so re-activate to keep the window in front.
    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        MainActor.assumeIsolated {
            bringToFront()
        }
    }
}
