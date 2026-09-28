import SwiftUI

/// A quiet editorial canvas with one strong, plate-shaped focal point.
enum AppStyle {
    static let ink = Color(red: 0.07, green: 0.18, blue: 0.17)
    static let pine = Color(red: 0.06, green: 0.29, blue: 0.27)
    static let jade = Color(red: 0.17, green: 0.52, blue: 0.43)
    static let mist = Color(red: 0.86, green: 0.94, blue: 0.91)
    static let canvas = Color(red: 0.96, green: 0.98, blue: 0.97)
    static let paper = Color.white
    static let muted = Color(red: 0.42, green: 0.51, blue: 0.48)

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
}

struct PlateMark: View {
    var symbol: String = "leaf.fill"
    var size: CGFloat = 180
    var tint: Color = AppStyle.mist

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.17), lineWidth: 1)
                .padding(1)
            Circle()
                .stroke(tint.opacity(0.42), lineWidth: 1.5)
                .padding(size * 0.10)
            Circle()
                .fill(tint.opacity(0.10))
                .padding(size * 0.20)
            Image(systemName: symbol)
                .font(.system(size: size * 0.29, weight: .ultraLight))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct PageIntro: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppStyle.display(34))
                .tracking(-1.3)
                .foregroundStyle(AppStyle.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct ActionTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    var tint: Color = AppStyle.pine
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppStyle.ink)
                    Text(subtitle).font(.caption).foregroundStyle(AppStyle.muted)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .padding(16)
            .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
