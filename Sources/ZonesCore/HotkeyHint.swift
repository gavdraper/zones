/// A single labelled key shown in the on-screen hotkey hint: the glyph drawn on
/// the key cap, and an optional caption beneath it describing what the key does.
public struct HintKey: Equatable, Sendable {
    public let glyph: String
    public let caption: String?

    public init(glyph: String, caption: String? = nil) {
        self.glyph = glyph
        self.caption = caption
    }
}

/// What the transient on-screen hint should display while a chord's modifiers are
/// held: the modifiers that are down, a one-line title, the four directional
/// arrows, and any region-only extra keys.
public struct HotkeyHintContent: Equatable, Sendable {
    /// Modifier glyphs in canonical `⌃⌥⌘` order.
    public let modifierGlyphs: [String]
    public let title: String
    /// The directional keys, always ordered up, down, left, right.
    public let arrows: [HintKey]
    /// Extra keys shown only for the region family (quarters, maximize, center).
    public let extras: [HintKey]

    public init(modifierGlyphs: [String], title: String, arrows: [HintKey], extras: [HintKey]) {
        self.modifierGlyphs = modifierGlyphs
        self.title = title
        self.arrows = arrows
        self.extras = extras
    }
}

/// Resolves the held modifiers to the hint that should be shown, mirroring the
/// two chord families in ``KeyBinding``. This is the presentation counterpart of
/// `KeyBinding.command(forKeyCode:modifiers:)`: same exact, disjoint modifier
/// matching, but it yields displayable glyphs and captions rather than commands.
public enum HotkeyHint {

    /// The hint for exactly these held modifiers, or `nil` when they don't arm a
    /// chord family. Matching is exact, so a stray extra modifier (e.g. Shift)
    /// shows nothing — the same rule the bindings resolve under.
    public static func content(for modifiers: Modifiers) -> HotkeyHintContent? {
        if modifiers == KeyBinding.moveModifiers { return move }
        if modifiers == KeyBinding.regionModifiers { return region }
        return nil
    }

    /// `⌃⌥` — step the focused window between zones in any of four directions.
    private static let move = HotkeyHintContent(
        modifierGlyphs: ["⌃", "⌥"],
        title: "Move between zones",
        arrows: [
            HintKey(glyph: "↑"),
            HintKey(glyph: "↓"),
            HintKey(glyph: "←"),
            HintKey(glyph: "→"),
        ],
        extras: []
    )

    /// `⌃⌥⌘` — snap the focused window to a built-in screen region.
    private static let region = HotkeyHintContent(
        modifierGlyphs: ["⌃", "⌥", "⌘"],
        title: "Snap to region",
        arrows: [
            HintKey(glyph: "↑", caption: "Top half"),
            HintKey(glyph: "↓", caption: "Bottom half"),
            HintKey(glyph: "←", caption: "Left half"),
            HintKey(glyph: "→", caption: "Right half"),
        ],
        extras: [
            HintKey(glyph: "U", caption: "Top left"),
            HintKey(glyph: "I", caption: "Top right"),
            HintKey(glyph: "J", caption: "Bottom left"),
            HintKey(glyph: "K", caption: "Bottom right"),
            HintKey(glyph: "↩", caption: "Maximize"),
            HintKey(glyph: "C", caption: "Center"),
        ]
    )
}
