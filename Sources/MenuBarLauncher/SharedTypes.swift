import Foundation
import AppKit

// Shared Shortcut struct for keyboard shortcut handling
struct Shortcut: Equatable {
    var keyCode: UInt16
    var modifiersRawValue: UInt

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiers.rawValue
    }

    // Custom Codable implementation to avoid synthesized init conflicts
    enum CodingKeys: String, CodingKey {
        case keyCode, modifiersRawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        modifiersRawValue = try container.decode(UInt.self, forKey: .modifiersRawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiersRawValue, forKey: .modifiersRawValue)
    }

    static var defaultShortcut: Shortcut {
        Shortcut(keyCode: 49, modifiers: [.command, .shift]) // Space + ⌘⇧
    }

    var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        let keyName = keyCodeToString(keyCode)
        parts.append(keyName)

        return parts.joined(separator: " ")
    }

    func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            49: "Space", 36: "Return", 53: "Esc", 51: "Delete",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K",
            41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
            65: ".", 67: "*", 69: "+", 71: "Clear", 75: "/", 76: "Enter", 78: "-",
            81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6",
            89: "7", 91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F14", 107: "F10",
            109: "F12", 111: "F15", 113: "F4", 114: "F2", 115: "F10", 116: "F1",
            117: "F1", 118: "F2", 119: "F3", 120: "F4", 121: "F5", 122: "F6"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }
}

enum DisplayMode: String, CaseIterable, Codable, Identifiable {
    case popover = "popover"
    case floatingWindow = "floatingWindow"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .popover: return "Popover (menu bar)"
        case .floatingWindow: return "Fenêtre flottante"
        }
    }
}

extension Notification.Name {
    static let shortcutChanged = Notification.Name("shortcutChanged")
    static let webViewHeightChanged = Notification.Name("webViewHeightChanged")
    static let webViewWidthChanged = Notification.Name("webViewWidthChanged")
    static let displayModeChanged = Notification.Name("displayModeChanged")
}