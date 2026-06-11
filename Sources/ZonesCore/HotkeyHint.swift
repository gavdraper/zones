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

    /// The hint for exactly these held modifiers under `scheme`, or `nil` when
    /// they don't arm a chord family. Matching is exact, so a stray extra
    /// modifier shows nothing — the same rule the bindings resolve under. The
    /// modifier glyphs are taken from the scheme, so the hint tracks whichever
    /// chord the user has chosen.
    public static func content(
        for modifiers: Modifiers,
        scheme: HotkeyScheme = .default
    ) -> HotkeyHintContent? {
        if modifiers == scheme.moveModifiers { return move(scheme) }
        if modifiers == scheme.regionModifiers { return region(scheme) }
        return nil
    }

    /// Step the focused window between zones in any of four directions.
    private static func move(_ scheme: HotkeyScheme) -> HotkeyHintContent {
        HotkeyHintContent(
            modifierGlyphs: scheme.moveModifiers.glyphs,
            title: "Move between zones",
            arrows: [
                HintKey(glyph: "↑"),
                HintKey(glyph: "↓"),
                HintKey(glyph: "←"),
                HintKey(glyph: "→"),
            ],
            extras: []
        )
    }

    /// Snap the focused window to a built-in screen region.
    private static func region(_ scheme: HotkeyScheme) -> HotkeyHintContent {
        HotkeyHintContent(
            modifierGlyphs: scheme.regionModifiers.glyphs,
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
}
