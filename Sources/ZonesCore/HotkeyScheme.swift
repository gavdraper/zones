/// A selectable preset that decides which modifier keys arm the two keyboard
/// chord families. The user picks one of these in Settings; the keycode→action
/// tables in ``KeyBinding`` are unchanged — only the modifiers that gate them
/// move. Each scheme keeps its move and region modifiers distinct so the two
/// families can never collide under the exact match the bindings perform.
///
/// Persisted by raw value, so the case names are a stable on-disk contract.
public enum HotkeyScheme: String, CaseIterable, Codable, Sendable {
    /// `⌃⌥` to move, `⌃⌥⌘` for regions — the original, pre-settings bindings.
    case controlOption
    /// `⌥⌘` to move, `⌥⌘⇧` for regions.
    case optionCommand
    /// `⌃⇧` to move, `⌃⌥⇧` for regions.
    case controlShift

    /// The scheme used when nothing has been chosen, matching the bindings that
    /// shipped before schemes were configurable.
    public static let `default`: HotkeyScheme = .controlOption

    /// Modifiers that arm the zone-move family (held with the arrow keys).
    public var moveModifiers: Modifiers {
        switch self {
        case .controlOption: return [.control, .option]
        case .optionCommand: return [.option, .command]
        case .controlShift:  return [.control, .shift]
        }
    }

    /// Modifiers that arm the built-in-region family. Always a different set
    /// from ``moveModifiers`` so a single keycode never resolves to both.
    public var regionModifiers: Modifiers {
        switch self {
        case .controlOption: return [.control, .option, .command]
        case .optionCommand: return [.option, .command, .shift]
        case .controlShift:  return [.control, .option, .shift]
        }
    }

    /// Human-readable name for the move chord, shown in the Settings picker.
    public var displayName: String {
        switch self {
        case .controlOption: return "Control + Option"
        case .optionCommand: return "Option + Command"
        case .controlShift:  return "Control + Shift"
        }
    }
}
