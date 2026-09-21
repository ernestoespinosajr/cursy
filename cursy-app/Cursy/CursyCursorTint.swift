import SwiftUI

enum CursyCursorTint: String, CaseIterable, Identifiable {
    case mint, blue, coral, gold, violet
    var id: String { rawValue }
    static let preferenceKey = "cursyCursorTint"

    static func resolve(_ value: String) -> Self { Self(rawValue: value) ?? .mint }

    var color: Color {
        switch self {
        case .mint: return Color(red: 0.22, green: 0.84, blue: 0.63)
        case .blue: return Color(red: 0.22, green: 0.53, blue: 1)
        case .coral: return Color(red: 1, green: 0.30, blue: 0.34)
        case .gold: return Color(red: 1, green: 0.72, blue: 0.16)
        case .violet: return Color(red: 0.70, green: 0.44, blue: 1)
        }
    }

    func title(spanish: Bool) -> String {
        switch self {
        case .mint: return spanish ? "Menta" : "Mint"
        case .blue: return spanish ? "Azul" : "Blue"
        case .coral: return "Coral"
        case .gold: return spanish ? "Dorado" : "Gold"
        case .violet: return spanish ? "Violeta" : "Violet"
        }
    }
}
