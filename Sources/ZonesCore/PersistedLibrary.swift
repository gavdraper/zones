/// The on-disk document: the user's custom layouts plus which layout is active.
/// Built-in templates are defined in code and are not persisted.
public struct PersistedLibrary: Equatable, Codable, Sendable {
    public var userLayouts: [UserLayout]
    public var active: LayoutSelection?

    public init(userLayouts: [UserLayout] = [], active: LayoutSelection? = nil) {
        self.userLayouts = userLayouts
        self.active = active
    }

    public static var empty: PersistedLibrary { PersistedLibrary() }
}
