import SwiftUI
import UIKit

enum AvatarPresets {
    static let fallbackKeys = (1...12).map { "avatar-\($0)" }

    private static let colors: [Color] = [
        .orange, .teal, .indigo, .pink, .green, .blue, .purple, .red, .mint, .brown, .cyan, .yellow,
    ]
    private static let symbols = ["bird.fill", "bird", "leaf.fill", "tree.fill"]

    static func isPreset(_ value: String) -> Bool {
        value.hasPrefix("avatar-")
    }

    /// Placeholder art until real images named `avatar-N` are added to the asset catalog.
    static func style(for key: String) -> (color: Color, symbol: String) {
        let index = max((Int(key.dropFirst("avatar-".count)) ?? 1) - 1, 0)
        return (colors[index % colors.count], symbols[(index / colors.count + index) % symbols.count])
    }
}

struct AvatarView: View {
    let profilePicture: String?
    var size: CGFloat = 80

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(.circle)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        let value = profilePicture?.trimmingCharacters(in: .whitespaces) ?? ""
        if value.isEmpty {
            DefaultAvatar(size: size)
        } else if AvatarPresets.isPreset(value) {
            PresetAvatar(key: value, size: size)
        } else {
            RemoteImage(path: value)
        }
    }
}

struct DefaultAvatar: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white, Color(.systemGray3))
            .frame(width: size, height: size)
    }
}

struct PresetAvatar: View {
    let key: String
    let size: CGFloat

    var body: some View {
        if UIImage(named: key) != nil {
            Image(key)
                .resizable()
                .scaledToFill()
        } else {
            let style = AvatarPresets.style(for: key)
            Circle()
                .fill(style.color.gradient)
                .overlay {
                    Image(systemName: style.symbol)
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(.white)
                }
        }
    }
}
