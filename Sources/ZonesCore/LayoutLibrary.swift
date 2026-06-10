import Foundation

/// The app's in-memory layout model: built-in templates plus the user's custom
/// layouts, with one of them marked active. It loads from and persists to a
/// `LayoutStore`, and notifies observers (the menu bar, the snap controller) via
/// `onChange` so they can refresh without depending on AppKit here.
///
/// `@MainActor` because it backs main-thread UI; the built-ins are injected so
/// the type stays free of `LayoutTemplate` wiring and trivially testable.
@MainActor
public final class LayoutLibrary {
    public private(set) var builtins: [ZoneLayout]
    public private(set) var userLayouts: [UserLayout]
    public private(set) var selection: LayoutSelection

    /// Called after any change to the layouts or the active selection.
    public var onChange: (() -> Void)?

    private let store: LayoutStore

    public init(store: LayoutStore, builtins: [ZoneLayout]) throws {
        precondition(!builtins.isEmpty, "LayoutLibrary requires at least one built-in layout")
        self.store = store
        self.builtins = builtins

        let persisted = try store.load()
        self.userLayouts = persisted.userLayouts
        self.selection = Self.resolve(persisted.active, builtins: builtins, userLayouts: persisted.userLayouts)

        // A dangling persisted selection (deleted user layout, renamed built-in)
        // gets corrected and re-saved so the file reflects reality.
        if persisted.active != selection {
            try? persist()
        }
    }

    /// The active layout resolved to a concrete, snappable `ZoneLayout`.
    public var active: ZoneLayout {
        switch selection {
        case let .builtin(name):
            return builtins.first { $0.name == name } ?? builtins[0]
        case let .user(id):
            return userLayouts.first { $0.id == id }?.asZoneLayout() ?? builtins[0]
        }
    }

    // MARK: - Selection

    public func selectBuiltin(named name: String) {
        guard builtins.contains(where: { $0.name == name }) else { return }
        selection = .builtin(name: name)
        saveAndNotify()
    }

    public func selectUser(id: UUID) {
        guard userLayouts.contains(where: { $0.id == id }) else { return }
        selection = .user(id: id)
        saveAndNotify()
    }

    // MARK: - Mutation

    /// Adds a new user layout (or replaces one with the same id) and makes it
    /// active — newly saved layouts become the current one.
    public func add(_ layout: UserLayout) {
        upsert(layout)
        selection = .user(id: layout.id)
        saveAndNotify()
    }

    /// Replaces an existing user layout in place, leaving the active selection
    /// as-is. No-op if the id isn't known.
    public func update(_ layout: UserLayout) {
        guard userLayouts.contains(where: { $0.id == layout.id }) else { return }
        upsert(layout)
        saveAndNotify()
    }

    /// Removes a user layout, falling back to the first built-in if it was active.
    public func remove(id: UUID) {
        userLayouts.removeAll { $0.id == id }
        if selection == .user(id: id) {
            selection = .builtin(name: builtins[0].name)
        }
        saveAndNotify()
    }

    public func userLayout(id: UUID) -> UserLayout? {
        userLayouts.first { $0.id == id }
    }

    // MARK: - Private

    private func upsert(_ layout: UserLayout) {
        if let index = userLayouts.firstIndex(where: { $0.id == layout.id }) {
            userLayouts[index] = layout
        } else {
            userLayouts.append(layout)
        }
    }

    private func saveAndNotify() {
        try? persist()
        onChange?()
    }

    private func persist() throws {
        try store.save(PersistedLibrary(userLayouts: userLayouts, active: selection))
    }

    private static func resolve(
        _ selection: LayoutSelection?, builtins: [ZoneLayout], userLayouts: [UserLayout]
    ) -> LayoutSelection {
        let fallback = LayoutSelection.builtin(name: builtins[0].name)
        guard let selection else { return fallback }
        switch selection {
        case let .builtin(name):
            return builtins.contains { $0.name == name } ? selection : fallback
        case let .user(id):
            return userLayouts.contains { $0.id == id } ? selection : fallback
        }
    }
}
