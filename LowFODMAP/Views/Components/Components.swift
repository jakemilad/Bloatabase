import SwiftData
import SwiftUI

struct RatingDot: View {
    let rating: Rating
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(rating.color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white.opacity(0.75), lineWidth: 1))
            .accessibilityLabel("\(rating.label) FODMAP")
    }
}

struct RatingPill: View {
    let rating: Rating
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: rating.symbol)
            Text(compact ? rating.label : "\(rating.label) FODMAP")
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(rating.color)
        .background(rating.color.opacity(0.10), in: Capsule())
    }
}

struct EmojiTile: View {
    let emoji: String
    var rating: Rating?
    var size: CGFloat = 44

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background((rating?.color ?? AppStyle.jade).opacity(0.10), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

/// Six tiny traffic lights, one per FODMAP group.
struct GroupLights: View {
    let food: Food

    var body: some View {
        HStack(spacing: 3) {
            ForEach(FodmapGroup.allCases) { g in
                let level = food.level(for: g)
                Circle()
                    .fill(level.map { Rating(level: $0).color } ?? Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

struct FoodRow: View {
    let food: Food
    var personal: Rating?

    var body: some View {
        HStack(spacing: 13) {
            EmojiTile(emoji: food.emoji, rating: personal ?? food.rating, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppStyle.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let serving = food.serving, food.rating != .high {
                        Label(serving, systemImage: "scalemass")
                            .labelStyle(.titleAndIcon)
                    } else if !food.triggerGroups.isEmpty {
                        Text(food.triggerGroups.map(\.name).joined(separator: " · "))
                    } else {
                        Text(food.rating.verdict)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppStyle.muted)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            RatingPill(rating: personal ?? food.rating, compact: true)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(AppStyle.ink.opacity(0.045)))
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title).font(AppStyle.display(24)).tracking(-0.5).foregroundStyle(AppStyle.ink)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action).font(.subheadline.weight(.semibold)).foregroundStyle(AppStyle.jade)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    var color: Color = .accentColor
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .foregroundStyle(isOn ? .white : .primary)
                .background(isOn ? AnyShapeStyle(color) : AnyShapeStyle(Color.cardBackground), in: Capsule())
                .overlay(Capsule().strokeBorder(AppStyle.ink.opacity(isOn ? 0 : 0.07)))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// Simple wrapping layout for chips and tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 {
                x = 0; y += rowH + spacing; rowH = 0
            }
            x += s.width + spacing
            maxX = max(maxX, x - spacing)
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxX, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

struct EmptyStateView: View {
    let emoji: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: emptySymbol)
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(AppStyle.pine)
                .frame(width: 94, height: 94)
                .background(AppStyle.mist, in: Circle())
            Text(title).font(AppStyle.display(24)).foregroundStyle(AppStyle.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppStyle.muted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private var emptySymbol: String {
        switch emoji {
        case "🔎": "magnifyingglass"
        case "📓": "book.closed"
        case "🛒": "basket"
        case "💚": "heart"
        case "🍽️": "fork.knife"
        default: "leaf"
        }
    }
}

/// Shared lookups for per-food personal preferences.
struct PersonalData {
    let preferences: [FoodPreference]
    let challenges: [ChallengeRecord]

    var reactions: [String: PersonalReaction] {
        Dictionary(preferences.compactMap { p in p.reaction.map { (p.foodID, $0) } }, uniquingKeysWith: { a, _ in a })
    }

    var tolerance: ToleranceProfile { ToleranceProfile(records: challenges) }

    func personalRating(for food: Food) -> Rating? {
        if let r = reactions[food.id] { return r.rating }
        return tolerance.personalRating(for: food)?.rating
    }
}

extension View {
    func pageBackground() -> some View {
        self.scrollContentBackground(.hidden).background(Color.pageBackground)
    }
}
