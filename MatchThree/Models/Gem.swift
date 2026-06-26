import SwiftUI

enum GemType: Int, CaseIterable {
    case ruby, emerald, sapphire, topaz, amethyst, diamond

    var color: Color {
        switch self {
        case .ruby:     .red
        case .emerald:  .green
        case .sapphire: .blue
        case .topaz:    .orange
        case .amethyst: .purple
        case .diamond:  .white
        }
    }

    var symbol: String {
        switch self {
        case .ruby:     "ruby"
        case .emerald:  "emerald"
        case .sapphire: "sapphire"
        case .topaz:    "topaz"
        case .amethyst: "amethyst"
        case .diamond:  "diamond"
        }
    }
}

struct Gem: Identifiable, Equatable {
    let id = UUID()
    let type: GemType

    static func random() -> Gem {
        Gem(type: GemType.allCases.randomElement()!)
    }
}

struct Position: Equatable, Hashable {
    let row: Int
    let col: Int
}

struct Swap {
    let from: Position
    let to: Position
}

struct MatchGroup {
    let positions: Set<Position>
    let type: GemType
}
