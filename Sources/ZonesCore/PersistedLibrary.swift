/// The on-disk document: the user's custom layouts plus which layout is active.
/// Built-in templates are defined in code and are not persisted.
public struct PersistedLibrary: Equatable, Codable, Sendable {
    public var userLayouts: [UserLayout]
    public var active: LayoutSelection?

    /// Spacing in points applied around every snapped window. Files written
    /// before gaps existed have no such key and decode to `0`.
    public var gap: Double

    /// Whether the on-screen hotkey hint is shown while the chord modifiers are
    /// held. Files written before hints existed have no such key and decode to
    /// `true`, so the feature is on by default.
    public var hintsEnabled: Bool

    /// Which modifier preset arms the keyboard chords. Files written before
    /// schemes were configurable have no such key and decode to the default.
    public var hotkeyScheme: HotkeyScheme

    public init(
        userLayouts: [UserLayout] = [],
        active: LayoutSelection? = nil,
        gap: Double = 0,
        hintsEnabled: Bool = true,
        hotkeyScheme: HotkeyScheme = .default
    ) {
        self.userLayouts = userLayouts
        self.active = active
        self.gap = gap
        self.hintsEnabled = hintsEnabled
        self.hotkeyScheme = hotkeyScheme
    }

    public static var empty: PersistedLibrary { PersistedLibrary() }

    private enum CodingKeys: String, CodingKey {
        case userLayouts, active, gap, hintsEnabled, hotkeyScheme
    }

    // Custom decoding keeps older library.json files (no `gap`/`hintsEnabled`/
    // `hotkeyScheme`, and historically an absent `userLayouts`/`active`)
    // loadable instead of failing the whole read. Encoding stays synthesized.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userLayouts = try container.decodeIfPresent([UserLayout].self, forKey: .userLayouts) ?? []
        active = try container.decodeIfPresent(LayoutSelection.self, forKey: .active)
        gap = try container.decodeIfPresent(Double.self, forKey: .gap) ?? 0
        hintsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hintsEnabled) ?? true
        hotkeyScheme = try container.decodeIfPresent(HotkeyScheme.self, forKey: .hotkeyScheme) ?? .default
    }
}
