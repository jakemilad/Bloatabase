import Foundation
import SwiftData

/// How the user personally reacts to a food, overriding the generic rating.
enum PersonalReaction: Int, Codable, CaseIterable, Identifiable {
    case fine = 0, someSymptoms = 1, avoid = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .fine: "Works for me"
        case .someSymptoms: "Some symptoms"
        case .avoid: "Avoid"
        }
    }

    var emoji: String {
        switch self {
        case .fine: "😊"
        case .someSymptoms: "😐"
        case .avoid: "😣"
        }
    }

    var rating: Rating { Rating(level: rawValue) }
}

@Model
final class FoodPreference {
    @Attribute(.unique) var foodID: String
    var isFavorite: Bool
    var reactionRaw: Int?
    var note: String
    var updatedAt: Date

    init(foodID: String, isFavorite: Bool = false, reaction: PersonalReaction? = nil, note: String = "") {
        self.foodID = foodID
        self.isFavorite = isFavorite
        self.reactionRaw = reaction?.rawValue
        self.note = note
        self.updatedAt = .now
    }

    var reaction: PersonalReaction? {
        get { reactionRaw.flatMap(PersonalReaction.init(rawValue:)) }
        set { reactionRaw = newValue?.rawValue; updatedAt = .now }
    }
}

@Model
final class ShoppingItem {
    var name: String
    var foodID: String?
    var isChecked: Bool
    var createdAt: Date

    init(name: String, foodID: String? = nil) {
        self.name = name
        self.foodID = foodID
        self.isChecked = false
        self.createdAt = .now
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack, drink

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        case .drink: "cup.and.saucer.fill"
        }
    }

    static func suggested(for date: Date = .now) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<11: .breakfast
        case 11..<15: .lunch
        case 17..<22: .dinner
        default: .snack
        }
    }
}

@Model
final class MealLog {
    var date: Date
    var mealTypeRaw: String
    var foodIDs: [String]
    var extraFoods: [String]
    var note: String

    init(date: Date = .now, mealType: MealType, foodIDs: [String], extraFoods: [String] = [], note: String = "") {
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.foodIDs = foodIDs
        self.extraFoods = extraFoods
        self.note = note
    }

    var mealType: MealType { MealType(rawValue: mealTypeRaw) ?? .snack }
}

@Model
final class SymptomLog {
    var date: Date
    var bloating: Int
    var pain: Int
    var gas: Int
    var nausea: Int
    var stress: Int
    /// Bristol stool scale 1–7, nil if not recorded.
    var stoolType: Int?
    var note: String

    init(date: Date = .now, bloating: Int = 0, pain: Int = 0, gas: Int = 0, nausea: Int = 0, stress: Int = 0, stoolType: Int? = nil, note: String = "") {
        self.date = date
        self.bloating = bloating
        self.pain = pain
        self.gas = gas
        self.nausea = nausea
        self.stress = stress
        self.stoolType = stoolType
        self.note = note
    }

    /// 0–10 overall gut symptom score (stress is tracked but not counted as a symptom).
    var severity: Double {
        let worst = Double(max(bloating, pain, gas, nausea))
        let avg = Double(bloating + pain + gas + nausea) / 4
        return (worst * 0.6 + avg * 0.4)
    }
}

enum ChallengeStatus: String, Codable {
    case notStarted, inProgress, washout, tolerated, partlyTolerated, notTolerated

    var label: String {
        switch self {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .washout: "Washout"
        case .tolerated: "Tolerated"
        case .partlyTolerated: "Small amounts OK"
        case .notTolerated: "Trigger"
        }
    }

    var rating: Rating? {
        switch self {
        case .tolerated: .low
        case .partlyTolerated: .moderate
        case .notTolerated: .high
        default: nil
        }
    }
}

@Model
final class ChallengeRecord {
    var challengeID: String
    var groupRaw: String
    var startDate: Date
    /// Symptom reaction per dose day: 0 none, 1 mild, 2 moderate, 3 severe. -1 = not logged.
    var reactions: [Int]
    var finished: Bool
    var finishedAt: Date?
    var note: String

    init(challengeID: String, group: FodmapGroup, startDate: Date = .now) {
        self.challengeID = challengeID
        self.groupRaw = group.rawValue
        self.startDate = startDate
        self.reactions = [-1, -1, -1]
        self.finished = false
        self.note = ""
    }

    var group: FodmapGroup { FodmapGroup(rawValue: groupRaw) ?? .fructans }

    /// Outcome following the Monash approach: stop at the first dose that causes
    /// clear symptoms; tolerance is the largest dose eaten comfortably.
    var status: ChallengeStatus {
        if let firstBad = reactions.firstIndex(where: { $0 >= 2 }) {
            return firstBad == 0 ? .notTolerated : .partlyTolerated
        }
        if finished {
            return reactions.contains(1) ? .partlyTolerated : .tolerated
        }
        return .inProgress
    }

    var loggedDays: Int { reactions.filter { $0 >= 0 }.count }

    var currentDayIndex: Int? {
        reactions.firstIndex(where: { $0 < 0 })
    }

    var shouldStop: Bool { reactions.contains { $0 >= 2 } }
}
