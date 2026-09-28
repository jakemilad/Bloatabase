import Foundation

/// Looks for foods that tend to appear before bad symptom days.
struct TriggerInsights {
    struct Suspect: Identifiable {
        let foodID: String
        let name: String
        let occurrences: Int
        let avgSeverityWith: Double
        let avgSeverityWithout: Double
        var id: String { foodID }
        var lift: Double { avgSeverityWith - avgSeverityWithout }
    }

    struct DayPoint: Identifiable {
        let day: Date
        let severity: Double
        let highMeals: Int
        var id: Date { day }
    }

    let suspects: [Suspect]
    let safeFoods: [Suspect]
    let days: [DayPoint]
    let averageSeverity: Double
    let symptomLogCount: Int

    /// Window before a symptom log in which meals are considered.
    static let lookback: TimeInterval = 24 * 3600
    static let minimumGap: TimeInterval = 30 * 60

    init(meals: [MealLog], symptoms: [SymptomLog], store: FoodStore) {
        symptomLogCount = symptoms.count
        averageSeverity = symptoms.isEmpty ? 0 : symptoms.map(\.severity).reduce(0, +) / Double(symptoms.count)

        // For each symptom log, which foods were eaten in the preceding window?
        var exposures: [(foods: Set<String>, severity: Double)] = []
        for s in symptoms {
            let window = meals.filter {
                let dt = s.date.timeIntervalSince($0.date)
                return dt >= Self.minimumGap && dt <= Self.lookback
            }
            exposures.append((Set(window.flatMap(\.foodIDs)), s.severity))
        }

        var results: [Suspect] = []
        let allFoods = Set(exposures.flatMap(\.foods))
        for id in allFoods {
            let with = exposures.filter { $0.foods.contains(id) }.map(\.severity)
            let without = exposures.filter { !$0.foods.contains(id) }.map(\.severity)
            guard with.count >= 2, let food = store.food(id) else { continue }
            let avgWith = with.reduce(0, +) / Double(with.count)
            let avgWithout = without.isEmpty ? averageSeverity : without.reduce(0, +) / Double(without.count)
            results.append(Suspect(foodID: id, name: food.name, occurrences: with.count, avgSeverityWith: avgWith, avgSeverityWithout: avgWithout))
        }
        // Rank known FODMAP sources above low-FODMAP foods that merely co-occur with them.
        let prior: (Suspect) -> Double = { Double(store.food($0.foodID)?.rating.level ?? 0) * 1.5 }
        suspects = results.filter { $0.lift >= 1 && $0.avgSeverityWith >= 3 }
            .sorted { $0.lift + prior($0) > $1.lift + prior($1) }
        safeFoods = results.filter { $0.avgSeverityWith <= 2 && $0.occurrences >= 3 }.sorted { $0.occurrences > $1.occurrences }

        // Daily worst severity for the chart, last 14 days.
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: .now))!
        var points: [DayPoint] = []
        for offset in 0..<14 {
            let day = cal.date(byAdding: .day, value: offset, to: start)!
            let daySymptoms = symptoms.filter { cal.isDate($0.date, inSameDayAs: day) }
            let dayMeals = meals.filter { cal.isDate($0.date, inSameDayAs: day) }
            let highMeals = dayMeals.filter { meal in meal.foodIDs.contains { store.food($0)?.rating == .high } }.count
            let sev = daySymptoms.map(\.severity).max() ?? -1
            points.append(DayPoint(day: day, severity: sev, highMeals: highMeals))
        }
        days = points
    }
}
