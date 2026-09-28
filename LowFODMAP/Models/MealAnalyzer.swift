import Foundation

/// Personal tolerance learned from reintroduction challenges, per FODMAP group.
struct ToleranceProfile {
    var byGroup: [FodmapGroup: ChallengeStatus] = [:]

    init(records: [ChallengeRecord] = []) {
        // Fructans have several sub-challenges; keep the least tolerated result.
        for record in records where record.finished || record.shouldStop {
            let status = record.status
            guard let newRating = status.rating else { continue }
            if let existing = byGroup[record.group]?.rating, existing >= newRating { continue }
            byGroup[record.group] = status
        }
    }

    var isEmpty: Bool { byGroup.isEmpty }

    func status(for group: FodmapGroup) -> ChallengeStatus? { byGroup[group] }

    /// Rating for a food adjusted by the user's tested tolerance, plus the reason.
    func personalRating(for food: Food) -> (rating: Rating, reason: String)? {
        let triggers = food.triggerGroups
        guard food.rating > .low, !triggers.isEmpty else { return nil }
        let statuses = triggers.map { byGroup[$0] }
        guard statuses.allSatisfy({ $0 != nil }) else { return nil }
        let worst = statuses.compactMap { $0?.rating }.max() ?? .low
        let names = triggers.map(\.name).joined(separator: " & ")
        switch worst {
        case .low:
            return (.low, "You tolerated \(names) in your reintroduction challenges.")
        case .moderate:
            return (.moderate, "You tolerated small amounts of \(names) — keep portions modest.")
        case .high:
            return (.high, "\(names) triggered symptoms in your challenge.")
        }
    }
}

struct MealAnalysis {
    struct Item: Identifiable {
        let food: Food
        let effective: Rating
        let reason: String?
        var id: String { food.id }
    }

    let items: [Item]
    let stackedGroups: [FodmapGroup]
    let overall: Rating

    var problemItems: [Item] { items.filter { $0.effective > .low } }

    var headline: String {
        if items.isEmpty { return "Add foods to check a meal" }
        switch overall {
        case .low: return "This meal looks low FODMAP"
        case .moderate: return "Mostly fine — mind your portions"
        case .high: return stackedGroups.isEmpty || items.contains(where: { $0.effective == .high })
            ? "This meal is likely high FODMAP" : "These foods may stack up"
        }
    }

    var advice: [String] {
        var out: [String] = []
        for item in items where item.effective == .high {
            out.append("Swap out \(item.food.name.lowercased()) — it's high in \(groupList(item.food)).")
        }
        for g in stackedGroups {
            let names = items.filter { ($0.food.groups[g.rawValue] ?? 0) > 0 && $0.effective == .moderate }.map { $0.food.name.lowercased() }
            out.append("\(names.joined(separator: " + ")) all contain \(g == .gos ? "GOS" : g.name.lowercased()). Together they can add up to a high serve — keep one or halve the portions.")
        }
        let untyped = items.filter { $0.effective == .moderate && $0.food.triggerGroups.isEmpty }
        if untyped.count >= 2 {
            out.append("Several moderate foods together can stack up. Stick to the safe serving size for each.")
        }
        for item in items where item.effective == .moderate {
            if let serving = item.food.serving {
                out.append("Keep \(item.food.name.lowercased()) to \(serving).")
            }
        }
        return out
    }

    private func groupList(_ food: Food) -> String {
        let g = food.triggerGroups.map { $0.name.lowercased() }
        return g.isEmpty ? "FODMAPs" : g.joined(separator: " and ")
    }

    init(foods: [Food], reactions: [String: PersonalReaction], tolerance: ToleranceProfile) {
        var items: [Item] = []
        for food in foods {
            if let r = reactions[food.id] {
                items.append(Item(food: food, effective: r.rating, reason: "You marked this as “\(r.label.lowercased())”."))
            } else if let personal = tolerance.personalRating(for: food) {
                items.append(Item(food: food, effective: personal.rating, reason: personal.reason))
            } else {
                items.append(Item(food: food, effective: food.rating, reason: nil))
            }
        }
        self.items = items

        // FODMAP stacking: two or more moderate foods sharing a group.
        var counts: [FodmapGroup: Int] = [:]
        for item in items where item.effective == .moderate {
            for g in item.food.triggerGroups { counts[g, default: 0] += 1 }
        }
        stackedGroups = FodmapGroup.allCases.filter { (counts[$0] ?? 0) >= 2 }

        let worst = items.map(\.effective).max() ?? .low
        if worst == .high || !stackedGroups.isEmpty {
            overall = .high
        } else {
            overall = worst
        }
    }
}
