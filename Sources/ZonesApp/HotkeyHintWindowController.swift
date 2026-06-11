import AppKit
import ZonesCore

/// Owns the transparent, click-through HUD that shows the available hotkeys while
/// the chord modifiers are held. Sizes itself to its content and centres on the
/// supplied screen, fading in and out (unless the user has asked for reduced
/// motion). The caller decides *when* to show and hide; this only renders.
@MainActor
final class HotkeyHintWindowController {
    private let window: NSWindow
    private let hintView = HotkeyHintView()
    private var isShown = false
    private var orderOutTimer: Timer?

    private static let fadeInDuration: TimeInterval = 0.12
    private static let fadeOutDuration: TimeInterval = 0.10

    init() {
        window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = true                  // a passive hint, never interactive
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = true
        window.alphaValue = 0
        window.contentView = hintView
    }

    /// Shows `content` centred on `screen`. Safe to call again while visible to
    /// swap content (e.g. when `⌘` is added to escalate the move hint to regions);
    /// the window resizes and re-centres in place.
    func show(_ content: HotkeyHintContent, on screen: NSScreen) {
        orderOutTimer?.invalidate()
        orderOutTimer = nil
        hintView.content = content
        hintView.layoutSubtreeIfNeeded()
        window.setFrame(centeredFrame(of: hintView.fittingSize, on: screen), display: true)
        window.orderFrontRegardless()
        isShown = true
        fade(to: 1, over: Self.fadeInDuration)
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        fade(to: 0, over: Self.fadeOutDuration)

        // With reduced motion the fade is instantaneous, so order out at once.
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.orderOut(nil)
            return
        }

        // Otherwise order the window out once the fade has finished. A re-show
        // invalidates this timer, so a hide racing with a re-show never tears
        // down a live hint.
        orderOutTimer = Timer.scheduledTimer(withTimeInterval: Self.fadeOutDuration, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isShown else { return }
                self.window.orderOut(nil)
            }
        }
    }

    // MARK: - Geometry

    private func centeredFrame(of size: NSSize, on screen: NSScreen) -> NSRect {
        let area = screen.visibleFrame
        let origin = NSPoint(
            x: (area.midX - size.width / 2).rounded(),
            y: (area.midY - size.height / 2).rounded()
        )
        return NSRect(origin: origin, size: size)
    }

    // MARK: - Fade

    private func fade(to alpha: CGFloat, over duration: TimeInterval) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.alphaValue = alpha
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            window.animator().alphaValue = alpha
        }
    }
}
