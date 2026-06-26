import SwiftUI

struct GemView: View {
    let gem: Gem
    let size: CGFloat
    let isSelected: Bool
    let isMatched: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(gem.type.color.gradient)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.15)
                        .stroke(isSelected ? Color.yellow : Color.white.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
                .scaleEffect(isMatched ? 0.01 : 1.0)
                .opacity(isMatched ? 0 : 1)
                .animation(.easeIn(duration: 0.3), value: isMatched)

            Image(systemName: iconName)
                .font(.system(size: size * 0.4))
                .foregroundColor(.white)
                .shadow(radius: 2)
        }
    }

    private var iconName: String {
        switch gem.type {
        case .ruby:     "heart.fill"
        case .emerald:  "leaf.fill"
        case .sapphire: "drop.fill"
        case .topaz:    "flame.fill"
        case .amethyst: "star.fill"
        case .diamond:  "sparkles"
        }
    }
}
