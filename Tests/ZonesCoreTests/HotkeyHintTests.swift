import Testing
@testable import ZonesCore

@Suite("Hotkey hint content")
struct HotkeyHintTests {

    @Test("Move modifiers (⌃⌥) yield the four directional arrows, no captions, no extras")
    func moveTier() throws {
        let content = try #require(HotkeyHint.content(for: KeyBinding.moveModifiers))
        #expect(content.modifierGlyphs == ["⌃", "⌥"])
        #expect(content.arrows.map(\.glyph) == ["↑", "↓", "←", "→"])
        #expect(content.arrows.allSatisfy { $0.caption == nil })
        #expect(content.extras.isEmpty)
    }

    @Test("Region modifiers (⌃⌥⌘) caption the arrows and add the extra region keys")
    func regionTier() throws {
        let content = try #require(HotkeyHint.content(for: KeyBinding.regionModifiers))
        #expect(content.modifierGlyphs == ["⌃", "⌥", "⌘"])
        #expect(content.arrows.map(\.glyph) == ["↑", "↓", "←", "→"])
        #expect(content.arrows.allSatisfy { $0.caption != nil })
        #expect(content.extras.map(\.glyph) == ["U", "I", "J", "K", "↩", "C"])
    }

    @Test("A partial or unbound modifier set yields no hint")
    func noHint() {
        #expect(HotkeyHint.content(for: []) == nil)
        #expect(HotkeyHint.content(for: [.control]) == nil)
        #expect(HotkeyHint.content(for: [.command]) == nil)
        #expect(HotkeyHint.content(for: [.control, .command]) == nil)
    }

    @Test("Stray extra modifiers never resolve — the match is exact")
    func exactMatch() {
        #expect(HotkeyHint.content(for: [.control, .option, .shift]) == nil)
        #expect(HotkeyHint.content(for: [.control, .option, .command, .shift]) == nil)
    }
}
