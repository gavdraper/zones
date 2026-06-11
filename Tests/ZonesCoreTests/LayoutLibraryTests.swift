import Testing
import Foundation
@testable import ZonesCore

@MainActor
@Suite("Layout library")
struct LayoutLibraryTests {

    private let builtins = LayoutTemplate.builtins()

    private func makeLayout(name: String = "Custom") -> UserLayout {
        UserLayout(name: name, grid: EditableGrid.single.splitting(.root, axis: .vertical, at: 0.5))
    }

    @Test("Defaults to the first built-in when nothing is persisted")
    func defaultsToFirstBuiltin() throws {
        let library = try LayoutLibrary(store: InMemoryLayoutStore(), builtins: builtins)
        #expect(library.active == builtins[0])
    }

    @Test("Resolves a persisted built-in selection")
    func resolvesBuiltinSelection() throws {
        let store = InMemoryLayoutStore(PersistedLibrary(active: .builtin(name: builtins[1].name)))
        let library = try LayoutLibrary(store: store, builtins: builtins)
        #expect(library.active == builtins[1])
    }

    @Test("Resolves a persisted user selection")
    func resolvesUserSelection() throws {
        let layout = makeLayout()
        let store = InMemoryLayoutStore(PersistedLibrary(userLayouts: [layout], active: .user(id: layout.id)))
        let library = try LayoutLibrary(store: store, builtins: builtins)
        #expect(library.active == layout.asZoneLayout())
    }

    @Test("A dangling user selection falls back to the first built-in and re-persists")
    func danglingSelectionFallsBack() throws {
        let store = InMemoryLayoutStore(PersistedLibrary(active: .user(id: UUID())))
        let library = try LayoutLibrary(store: store, builtins: builtins)

        #expect(library.active == builtins[0])
        // The corrected selection was written back.
        #expect(store.saved.active == .builtin(name: builtins[0].name))
    }

    @Test("Adding a layout persists it and makes it active")
    func addPersistsAndActivates() throws {
        let store = InMemoryLayoutStore()
        let library = try LayoutLibrary(store: store, builtins: builtins)
        let layout = makeLayout()

        var notified = false
        library.onChange = { notified = true }
        library.add(layout)

        #expect(notified)
        #expect(library.active == layout.asZoneLayout())
        #expect(store.saved.userLayouts == [layout])
        #expect(store.saved.active == .user(id: layout.id))
    }

    @Test("Loads the persisted gap")
    func loadsPersistedGap() throws {
        let store = InMemoryLayoutStore(PersistedLibrary(gap: 8))
        let library = try LayoutLibrary(store: store, builtins: builtins)
        #expect(library.gap == 8)
    }

    @Test("Setting the gap clamps, persists, and notifies")
    func setGapPersistsAndNotifies() throws {
        let store = InMemoryLayoutStore()
        let library = try LayoutLibrary(store: store, builtins: builtins)

        var notified = false
        library.onChange = { notified = true }
        library.setGap(-5)   // clamps to 0; equals current value, so no-op
        #expect(library.gap == 0)
        #expect(!notified)

        library.setGap(16)
        #expect(notified)
        #expect(library.gap == 16)
        #expect(store.saved.gap == 16)
    }

    @Test("Loads the persisted hotkey scheme")
    func loadsPersistedScheme() throws {
        let store = InMemoryLayoutStore(PersistedLibrary(hotkeyScheme: .optionCommand))
        let library = try LayoutLibrary(store: store, builtins: builtins)
        #expect(library.hotkeyScheme == .optionCommand)
    }

    @Test("Defaults to the default scheme when nothing is persisted")
    func defaultsToDefaultScheme() throws {
        let library = try LayoutLibrary(store: InMemoryLayoutStore(), builtins: builtins)
        #expect(library.hotkeyScheme == .default)
    }

    @Test("Setting the hotkey scheme persists, notifies, and is a no-op when unchanged")
    func setSchemePersistsAndNotifies() throws {
        let store = InMemoryLayoutStore()
        let library = try LayoutLibrary(store: store, builtins: builtins)

        var notified = false
        library.onChange = { notified = true }
        library.setHotkeyScheme(.default)   // equals current value, so no-op
        #expect(!notified)

        library.setHotkeyScheme(.controlShift)
        #expect(notified)
        #expect(library.hotkeyScheme == .controlShift)
        #expect(store.saved.hotkeyScheme == .controlShift)
    }

    @Test("Removing the active layout falls back to the first built-in")
    func removeActiveFallsBack() throws {
        let layout = makeLayout()
        let store = InMemoryLayoutStore(PersistedLibrary(userLayouts: [layout], active: .user(id: layout.id)))
        let library = try LayoutLibrary(store: store, builtins: builtins)

        library.remove(id: layout.id)

        #expect(library.userLayouts.isEmpty)
        #expect(library.active == builtins[0])
        #expect(store.saved.active == .builtin(name: builtins[0].name))
    }

    @Test("Updating a layout keeps the active selection and persists the change")
    func updateKeepsSelection() throws {
        var layout = makeLayout(name: "Before")
        let store = InMemoryLayoutStore(PersistedLibrary(userLayouts: [layout], active: .user(id: layout.id)))
        let library = try LayoutLibrary(store: store, builtins: builtins)

        layout.name = "After"
        library.update(layout)

        #expect(library.userLayout(id: layout.id)?.name == "After")
        #expect(library.active.name == "After")
        #expect(store.saved.userLayouts.first?.name == "After")
    }
}
