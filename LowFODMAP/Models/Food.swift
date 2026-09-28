import SwiftUI

enum Rating: String, Codable, CaseIterable, Identifiable, Comparable {
    case low, moderate, high

    var id: String { rawValue }

    var level: Int {
        switch self {
        case .low: 0
        case .moderate: 1
        case .high: 2
        }
    }

    init(level: Int) {
        self = level <= 0 ? .low : (level == 1 ? .moderate : .high)
    }

    static func < (lhs: Rating, rhs: Rating) -> Bool { lhs.level < rhs.level }

    var label: String {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        }
    }

    var verdict: String {
        switch self {
        case .low: "Good to go"
        case .moderate: "Watch your portion"
        case .high: "Best avoided"
        }
    }

    var symbol: String {
        switch self {
        case .low: "checkmark.circle.fill"
        case .moderate: "exclamationmark.circle.fill"
        case .high: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .low: .fodmapGreen
        case .moderate: .fodmapAmber
        case .high: .fodmapRed
        }
    }
}

struct FoodCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
}

struct Food: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let emoji: String
    let rating: Rating
    let serving: String?
    let groups: [String: Int]
    let notes: [String]
    let aliases: [String]
    let sources: [String]
    let sourcesDisagree: Bool

    /// Per-group level. Foods rated low are low in every group; for others,
    /// missing groups are unknown (nil) rather than assumed low.
    func level(for group: FodmapGroup) -> Int? {
        if let v = groups[group.rawValue] { return v }
        return rating == .low ? 0 : (groups.isEmpty ? nil : 0)
    }

    var triggerGroups: [FodmapGroup] {
        FodmapGroup.allCases.filter { (groups[$0.rawValue] ?? 0) > 0 }
    }

    var sourceCount: Int { sources.count }
}

struct FoodDatabase: Codable {
    let categories: [FoodCategory]
    let foods: [Food]
}

extension Color {
    static let fodmapGreen = Color(red: 0.16, green: 0.50, blue: 0.41)
    static let fodmapAmber = Color(red: 0.68, green: 0.40, blue: 0.09)
    static let fodmapRed = Color(red: 0.77, green: 0.30, blue: 0.28)
    static let cardBackground = AppStyle.paper
    static let pageBackground = AppStyle.canvas
}
