import Foundation

/// A reintroduction challenge: one FODMAP group tested with one food at three increasing doses.
struct Challenge: Identifiable, Hashable {
    let id: String
    let group: FodmapGroup
    let title: String
    let food: String
    let emoji: String
    let doses: [String]
    let tip: String

    static let washoutDays = 3

    /// Suggested order: start with groups that have the clearest single-food tests.
    static let all: [Challenge] = [
        Challenge(id: "sorbitol", group: .sorbitol, title: "Sorbitol", food: "Avocado", emoji: "🥑",
                  doses: ["¼", "½", "1 whole"],
                  tip: "Or use 2 → 4 → 6 dried apricot halves."),
        Challenge(id: "lactose", group: .lactose, title: "Lactose", food: "Cow's milk", emoji: "🥛",
                  doses: ["½ cup (125 ml)", "¾ cup (190 ml)", "1 cup (250 ml)"],
                  tip: "Plain yoghurt works too: ½ → ¾ → 1 tub."),
        Challenge(id: "fructose", group: .fructose, title: "Fructose", food: "Honey", emoji: "🍯",
                  doses: ["1 tsp", "1½ tsp", "2 tsp"],
                  tip: "Or half → one → one-and-a-half mangoes."),
        Challenge(id: "mannitol", group: .mannitol, title: "Mannitol", food: "Button mushrooms", emoji: "🍄",
                  doses: ["½ cup", "1 cup", "1½ cups"],
                  tip: "Sweet potato (½ → 1 → 1½ cups) is an alternative."),
        Challenge(id: "fructans-wheat", group: .fructans, title: "Fructans · Wheat", food: "Wheat bread", emoji: "🍞",
                  doses: ["1 slice", "2 slices", "3 slices"],
                  tip: "Use plain white bread with no onion, garlic or honey."),
        Challenge(id: "fructans-garlic", group: .fructans, title: "Fructans · Garlic", food: "Garlic", emoji: "🧄",
                  doses: ["¼ clove", "½ clove", "1 clove"],
                  tip: "Cook it into an otherwise low-FODMAP meal."),
        Challenge(id: "fructans-onion", group: .fructans, title: "Fructans · Onion", food: "Onion", emoji: "🧅",
                  doses: ["1 tbsp", "¼ medium", "½ medium"],
                  tip: "Onion is often a stronger trigger than garlic — go slow."),
        Challenge(id: "gos", group: .gos, title: "GOS", food: "Canned chickpeas", emoji: "🫘",
                  doses: ["¼ cup", "½ cup", "1 cup"],
                  tip: "Canned lentils (½ → 1 → 1½ cups) also work."),
    ]

    static func find(_ id: String) -> Challenge? { all.first { $0.id == id } }
}

enum ReactionLevel: Int, CaseIterable, Identifiable {
    case none = 0, mild, moderate, severe

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: "No symptoms"
        case .mild: "Mild"
        case .moderate: "Moderate"
        case .severe: "Severe"
        }
    }

    var emoji: String {
        switch self {
        case .none: "😊"
        case .mild: "🙂"
        case .moderate: "😣"
        case .severe: "😖"
        }
    }
}
