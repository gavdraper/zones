import Testing
@testable import ZonesCore

@Suite("Key bindings")
struct KeyBindingTests {

    // Keycodes used by the default bindings.
    private let left: Int64 = 123, right: Int64 = 124, down: Int64 = 125, up: Int64 = 126
    private let u: Int64 = 32, i: Int64 = 34, j: Int64 = 38, k: Int64 = 40
    private let returnKey: Int64 = 36, c: Int64 = 8

    @Test("Control+Option+arrows are zone-move commands")
    func zoneMoves() {
        let mods: Modifiers = [.control, .option]
        #expect(KeyBinding.command(forKeyCode: left, modifiers: mods) == .move(.left))
        #expect(KeyBinding.command(forKeyCode: right, modifiers: mods) == .move(.right))
        #expect(KeyBinding.command(forKeyCode: up, modifiers: mods) == .move(.up))
        #expect(KeyBinding.command(forKeyCode: down, modifiers: mods) == .move(.down))
    }

    @Test("Control+Option+Command+arrows are half regions")
    func halfRegions() {
        let mods: Modifiers = [.control, .option, .command]
        #expect(KeyBinding.command(forKeyCode: left, modifiers: mods) == .region(.leftHalf))
        #expect(KeyBinding.command(forKeyCode: right, modifiers: mods) == .region(.rightHalf))
        #expect(KeyBinding.command(forKeyCode: up, modifiers: mods) == .region(.topHalf))
        #expect(KeyBinding.command(forKeyCode: down, modifiers: mods) == .region(.bottomHalf))
    }

    @Test("Control+Option+Command+U/I/J/K are quarter regions")
    func quarterRegions() {
        let mods: Modifiers = [.control, .option, .command]
        #expect(KeyBinding.command(forKeyCode: u, modifiers: mods) == .region(.topLeftQuarter))
        #expect(KeyBinding.command(forKeyCode: i, modifiers: mods) == .region(.topRightQuarter))
        #expect(KeyBinding.command(forKeyCode: j, modifiers: mods) == .region(.bottomLeftQuarter))
        #expect(KeyBinding.command(forKeyCode: k, modifiers: mods) == .region(.bottomRightQuarter))
    }

    @Test("Control+Option+Command+Return maximizes, +C centers")
    func maximizeAndCenter() {
        let mods: Modifiers = [.control, .option, .command]
        #expect(KeyBinding.command(forKeyCode: returnKey, modifiers: mods) == .region(.maximize))
        #expect(KeyBinding.command(forKeyCode: c, modifiers: mods) == .region(.center))
    }

    @Test("No keycode resolves to both a move and a region — the two families never collide")
    func noCollision() {
        let moveMods: Modifiers = [.control, .option]
        let regionMods: Modifiers = [.control, .option, .command]
        for keyCode in Int64(0)...127 {
            let move = KeyBinding.command(forKeyCode: keyCode, modifiers: moveMods)
            let region = KeyBinding.command(forKeyCode: keyCode, modifiers: regionMods)
            let bothFire = move != nil && region != nil
            #expect(!bothFire || move != region)
            // A move chord must never yield a region, and vice versa.
            if case .region = move { Issue.record("move chord produced a region for \(keyCode)") }
            if case .move = region { Issue.record("region chord produced a move for \(keyCode)") }
        }
    }

    @Test("Unknown chords resolve to nil")
    func unknownChords() {
        #expect(KeyBinding.command(forKeyCode: left, modifiers: [.control]) == nil)
        #expect(KeyBinding.command(forKeyCode: c, modifiers: [.control, .option]) == nil)
        #expect(KeyBinding.command(forKeyCode: 99, modifiers: [.control, .option, .command]) == nil)
    }

    @Test("Exact modifier match — extra modifiers don't resolve")
    func exactModifierMatch() {
        // Adding Shift to a zone-move chord must not still resolve as a move.
        #expect(KeyBinding.command(forKeyCode: left, modifiers: [.control, .option, .shift]) == nil)
    }
}
