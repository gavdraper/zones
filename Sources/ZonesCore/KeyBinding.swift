/// The set of modifier keys held for a chord, independent of any particular
/// event framework. ``KeyboardMonitor`` translates `CGEventFlags` into this so
/// the binding table can live in pure, testable core code.
public struct Modifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = Modifiers(rawValue: 1 << 0)
    public static let option  = Modifiers(rawValue: 1 << 1)
    public static let command = Modifiers(rawValue: 1 << 2)
    public static let shift   = Modifiers(rawValue: 1 << 3)

    /// The held modifiers as display glyphs in canonical `⌃⌥⇧⌘` order, for
    /// rendering a chord in hints, help, and Settings.
    public var glyphs: [String] {
        var glyphs: [String] = []
        if contains(.control) { glyphs.append("⌃") }
        if contains(.option)  { glyphs.append("⌥") }
        if contains(.shift)   { glyphs.append("⇧") }
        if contains(.command) { glyphs.append("⌘") }
        return glyphs
    }
}

/// What a recognised key chord should do.
public enum KeyCommand: Equatable, Sendable {
    /// Step the focused window to the neighbouring zone.
    case move(ZoneNavigator.Direction)
    /// Snap the focused window to a built-in screen region.
    case region(WindowRegion)
}

/// The default keyboard bindings, resolved purely from a keycode and the held
/// modifiers.
///
/// Two chord families share the arrow keys but can never collide because the
/// modifier sets are matched *exactly* and are disjoint. Which modifiers arm
/// each family is chosen by the active ``HotkeyScheme``; the keycode→action
/// tables below never change:
/// - Zone moves: scheme move modifiers + arrows.
/// - Built-in regions: scheme region modifiers + arrows (halves) / U·I·J·K
///   (quarters) / Return (maximize) / C (center).
public enum KeyBinding {

    /// Modifiers that arm the zone-move family under the default scheme. Kept
    /// for callers and tests that don't thread a scheme through.
    public static var moveModifiers: Modifiers { HotkeyScheme.default.moveModifiers }

    /// Modifiers that arm the built-in-region family under the default scheme.
    public static var regionModifiers: Modifiers { HotkeyScheme.default.regionModifiers }

    /// Arrow keycodes (`kVK_*`) → navigation direction.
    private static let moves: [Int64: ZoneNavigator.Direction] = [
        123: .left,   // kVK_LeftArrow
        124: .right,  // kVK_RightArrow
        125: .down,   // kVK_DownArrow
        126: .up,     // kVK_UpArrow
    ]

    /// Keycodes (`kVK_*`) → built-in region. Arrow rows are ordered to match
    /// `moves` above so the two tables stay easy to cross-check.
    private static let regions: [Int64: WindowRegion] = [
        123: .leftHalf,            // ←
        124: .rightHalf,           // →
        125: .bottomHalf,          // ↓
        126: .topHalf,             // ↑
        32:  .topLeftQuarter,      // U
        34:  .topRightQuarter,     // I
        38:  .bottomLeftQuarter,   // J
        40:  .bottomRightQuarter,  // K
        36:  .maximize,            // Return
        8:   .center,              // C
    ]

    /// The command for `keyCode` under exactly `modifiers` for the given
    /// `scheme`, or `nil` if the chord isn't bound. Modifiers must match a
    /// family set exactly, so a stray extra modifier never resolves.
    public static func command(
        forKeyCode keyCode: Int64,
        modifiers: Modifiers,
        scheme: HotkeyScheme = .default
    ) -> KeyCommand? {
        if modifiers == scheme.moveModifiers {
            return moves[keyCode].map(KeyCommand.move)
        }
        if modifiers == scheme.regionModifiers {
            return regions[keyCode].map(KeyCommand.region)
        }
        return nil
    }
}
