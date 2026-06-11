import Testing
@testable import ZonesCore

@Suite("Hotkey schemes")
struct HotkeySchemeTests {

    // Keycodes used by the bindings.
    private let left: Int64 = 123, c: Int64 = 8

    @Test("Every scheme keeps its move and region modifiers distinct")
    func familiesNeverCollide() {
        for scheme in HotkeyScheme.allCases {
            #expect(scheme.moveModifiers != scheme.regionModifiers)
        }
    }

    @Test("The default scheme reproduces the original Control+Option bindings")
    func defaultMatchesOriginal() {
        #expect(HotkeyScheme.default == .controlOption)
        #expect(HotkeyScheme.default.moveModifiers == [.control, .option])
        #expect(HotkeyScheme.default.regionModifiers == [.control, .option, .command])
    }

    @Test("command(forKeyCode:) resolves under the chosen scheme's modifiers")
    func commandHonoursScheme() {
        let scheme = HotkeyScheme.optionCommand
        #expect(KeyBinding.command(forKeyCode: left, modifiers: [.option, .command], scheme: scheme) == .move(.left))
        #expect(KeyBinding.command(forKeyCode: c, modifiers: [.option, .command, .shift], scheme: scheme) == .region(.center))
        // The default scheme's modifiers no longer resolve under a different scheme.
        #expect(KeyBinding.command(forKeyCode: left, modifiers: [.control, .option], scheme: scheme) == nil)
    }

    @Test("Hint content reflects the chosen scheme's modifier glyphs")
    func hintGlyphsFollowScheme() throws {
        let scheme = HotkeyScheme.optionCommand
        let move = try #require(HotkeyHint.content(for: scheme.moveModifiers, scheme: scheme))
        #expect(move.modifierGlyphs == ["⌥", "⌘"])

        let region = try #require(HotkeyHint.content(for: scheme.regionModifiers, scheme: scheme))
        #expect(region.modifierGlyphs == ["⌥", "⇧", "⌘"])
    }

    @Test("Modifier glyphs render in canonical ⌃⌥⇧⌘ order")
    func glyphOrder() {
        let all: Modifiers = [.command, .shift, .option, .control]
        #expect(all.glyphs == ["⌃", "⌥", "⇧", "⌘"])
        #expect(Modifiers().glyphs.isEmpty)
    }
}
