import AppKit
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    func applyToApp() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum Theme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }

    static let canvas = adaptive(0xF6F6FA, 0x17191F)
    static let surface = adaptive(0xFFFFFF, 0x22252D)
    static let preview = adaptive(0xF0F0F0, 0x121419)
    static let border = adaptive(0xE2E3E8, 0x3A3F4B)
    static let mutedFill = adaptive(0xF2F3F5, 0x2D313B)
    static let privacy = adaptive(0xF2F7F5, 0x20332D)
    static let selection = adaptive(0xFFF0E8, 0x432C28)
    static let accent = adaptive(0xCC4A33, 0xFF9A80)
    static let heroFill = adaptive(0xFDEBE0, 0x432C28)
    static let heroInk = adaptive(0xE65E40, 0xFF9A80)
    static let green = adaptive(0x3D8C6E, 0x7CCDA8)
}
