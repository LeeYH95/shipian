import AppKit
import SwiftUI
import NotesCore

extension Color {
    init(notesHex: UInt32) {
        self.init(.sRGB, red: Double((notesHex >> 16) & 255) / 255, green: Double((notesHex >> 8) & 255) / 255, blue: Double(notesHex & 255) / 255, opacity: 1)
    }
}

enum NotesTheme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    static let shell = adaptive(0xFCFDFF, 0x343A45)
    static let surface = adaptive(0xFAFBFD, 0x2D323C)
    static let text = adaptive(0x24262B, 0xF0F2F7)
    static let muted = adaptive(0x626B78, 0xB5BFCE)
    static let accent = adaptive(0x4E68B1, 0xA9BDF5)
    static let onAccent = adaptive(0xFFFFFF, 0x1B294E)
    static let border = adaptive(0xDFE3E9, 0x4A5463)
    static let danger = adaptive(0xA74747, 0xEDAAA5)
    static func paper(_ paper: NotePaper) -> Color {
        switch paper {
        case .plain: return surface
        case .blue: return adaptive(0xEEF2FA, 0x303B52)
        case .lavender: return adaptive(0xF0EDF6, 0x3F394E)
        case .rose: return adaptive(0xF4E8EC, 0x543D4C)
        case .warm: return adaptive(0xF6F0E5, 0x494136)
        case .gray: return adaptive(0xECEEF0, 0x383E47)
        }
    }
    static func editorSwatch(_ paper: NotePaper) -> Color {
        switch paper {
        case .plain: return adaptive(0xFAFCFE, 0x647085)
        case .blue: return adaptive(0xE5EDFA, 0x526B91)
        case .lavender: return adaptive(0xEDE8F5, 0x6B628C)
        case .rose: return adaptive(0xF4E8EC, 0x88687A)
        case .warm: return adaptive(0xF5EFDF, 0x8B8064)
        case .gray: return adaptive(0xE6ECEF, 0x647B88)
        }
    }
    static func appearance() -> NSAppearance? {
        switch UserDefaults.standard.string(forKey: "notesTheme") ?? "system" {
        case "light": return NSAppearance(named: .aqua)
        case "dark": return NSAppearance(named: .darkAqua)
        default: return nil
        }
    }
    static var fontSize: Double { let n = UserDefaults.standard.double(forKey: "notesFontSize"); return n >= 14 ? n : 23 }
    static var defaultPaper: NotePaper { NotePaper(rawValue: UserDefaults.standard.string(forKey: "notesPaper") ?? "blue") ?? .blue }
}

extension NotePaper {
    var chineseName: String {
        switch self { case .plain: return "云白"; case .blue: return "雾蓝"; case .lavender: return "浅藤"; case .rose: return "烟粉"; case .warm: return "麦芽"; case .gray: return "浅石" }
    }
}

struct NotesIconButton: View {
    let symbol: String
    let label: String
    var selected = false
    var size: CGFloat = 34
    var action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 16, weight: .regular)).frame(width: size, height: size).contentShape(Rectangle()) }
            .buttonStyle(NotesPressStyle()).foregroundStyle(selected ? NotesTheme.accent : NotesTheme.muted)
            .background(selected ? NotesTheme.accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .animation(NotesMotion.quick, value: selected)
            .notesTooltip(label).accessibilityLabel(label).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
