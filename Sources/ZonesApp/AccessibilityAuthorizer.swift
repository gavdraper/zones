import ApplicationServices

/// Gatekeeper for the Accessibility (AX) permission that window manipulation
/// and the mouse event tap both require.
enum AccessibilityAuthorizer {

    /// Whether this process is currently trusted for Accessibility.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers the system prompt that deep-links the user to
    /// System Settings → Privacy & Security → Accessibility if not yet trusted.
    @discardableResult
    static func promptIfNeeded() -> Bool {
        // Literal value of `kAXTrustedCheckOptionPrompt`; referencing the imported
        // global is rejected under Swift 6 strict concurrency (mutable global).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
