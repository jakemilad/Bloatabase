import SwiftData
import SwiftUI

/// Launch arguments for previewing screens in the simulator, e.g.
/// `-startTab diary -seedDemo YES -openFood garlic -mealDemo YES`. No-ops in release builds.
enum DebugLaunch {
    static var initialTab: AppTab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "check": .check
        case "diary", "insights": .diary
        case "reintro": .reintro
        case "more": .more
        default: .foods
        }
        #else
        .foods
        #endif
    }

    #if DEBUG
    static func apply(context: ModelContext, store: FoodStore, meal: MealBuilder) {
        let d = UserDefaults.standard
        if d.bool(forKey: "mealDemo") {
            meal.foodIDs = ["almonds", "pea-protein", "rice", "chicken", "garlic"].filter { store.food($0) != nil }
        }
        if d.bool(forKey: "seedDemo"), ((try? context.fetchCount(FetchDescriptor<MealLog>())) ?? 0) == 0 {
            seed(context: context, store: store)
        }
    }

    private static func seed(context: ModelContext, store: FoodStore) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let breakfasts = [["oats", "strawberry", "lactose-free-milk"], ["eggs", "spinach", "potato"]]
        let lunches = [["rice", "chicken", "carrots", "zucchini-courgette"], ["quinoa", "tofu-drained-or-firm", "bok-choy"]]
        let safeDinner = ["rice", "chicken", "green-beans"]
        let triggerDinners = [["regular-breads", "garlic", "cheddar-cheese"], ["pasta", "onions", "garlic", "tomatoes"]]
        for dayOffset in 0..<12 {
            let day = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            let hadTrigger = dayOffset % 2 == 1 || dayOffset == 4
            let dinner = hadTrigger ? triggerDinners[dayOffset % 2] : safeDinner
            let meals: [(Int, MealType, [String])] = [
                (8, .breakfast, breakfasts[dayOffset % 2]),
                (13, .lunch, lunches[dayOffset % 2]),
                (19, .dinner, dinner),
            ]
            for (hour, type, ids) in meals {
                context.insert(MealLog(date: cal.date(byAdding: .hour, value: hour, to: day)!, mealType: type, foodIDs: ids.filter { store.food($0) != nil }))
            }
            // Symptoms are logged the next morning, so they follow the previous dinner.
            let checkIn = cal.date(byAdding: .hour, value: 31, to: day)!
            guard checkIn < .now else { continue }
            let sev = hadTrigger ? Int.random(in: 6...8) : Int.random(in: 0...2)
            context.insert(SymptomLog(date: checkIn, bloating: sev, pain: max(0, sev - 2), gas: sev, nausea: 0, stress: Int.random(in: 1...4), stoolType: hadTrigger ? 6 : 4))
        }
        let lactose = ChallengeRecord(challengeID: "lactose", group: .lactose, startDate: cal.date(byAdding: .day, value: -9, to: today)!)
        lactose.reactions = [0, 0, 1]
        lactose.finished = true
        lactose.finishedAt = cal.date(byAdding: .day, value: -7, to: today)
        context.insert(lactose)
        let sorbitol = ChallengeRecord(challengeID: "sorbitol", group: .sorbitol, startDate: cal.date(byAdding: .day, value: -1, to: today)!)
        sorbitol.reactions = [0, -1, -1]
        context.insert(sorbitol)
        context.insert(FoodPreference(foodID: "garlic", isFavorite: false, reaction: .avoid, note: "Even a little sets me off"))
        context.insert(FoodPreference(foodID: "avocado", isFavorite: true))
        context.insert(FoodPreference(foodID: "strawberry", isFavorite: true))
        context.insert(ShoppingItem(name: "Garlic infused oil", foodID: "garlic-infused-oil"))
        context.insert(ShoppingItem(name: "Honey", foodID: "honey"))
        context.insert(ShoppingItem(name: "Lactose free milk", foodID: "lactose-free-milk"))
    }
    #endif
}
