import Foundation
import Observation

@Observable
final class FoodStore {
    let foods: [Food]
    let categories: [FoodCategory]
    private let byID: [String: Food]
    private let index: [(food: Food, name: String, words: [String], aliases: [String])]

    private(set) var recentIDs: [String] = []
    private let recentsKey = "recentFoodIDs"

    init() {
        let db: FoodDatabase
        if let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(FoodDatabase.self, from: data) {
            db = decoded
        } else {
            db = FoodDatabase(categories: [], foods: [])
        }
        foods = db.foods
        categories = db.categories
        byID = Dictionary(db.foods.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        index = db.foods.map { food in
            let name = Self.normalize(food.name)
            return (food, name, name.split(separator: " ").map(String.init), food.aliases.map(Self.normalize))
        }
        recentIDs = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
    }

    func food(_ id: String) -> Food? { byID[id] }

    func category(_ id: String) -> FoodCategory? { categories.first { $0.id == id } }

    func foods(in categoryID: String) -> [Food] { foods.filter { $0.category == categoryID } }

    var recents: [Food] { recentIDs.compactMap { byID[$0] } }

    func markViewed(_ food: Food) {
        recentIDs.removeAll { $0 == food.id }
        recentIDs.insert(food.id, at: 0)
        recentIDs = Array(recentIDs.prefix(12))
        UserDefaults.standard.set(recentIDs, forKey: recentsKey)
    }

    func clearRecents() {
        recentIDs = []
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }

    // MARK: - Search

    static func normalize(_ s: String) -> String {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let cleaned = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    /// Ranked search over names and aliases with light typo tolerance.
    func search(_ query: String, ratings: Set<Rating> = [], category: String? = nil) -> [Food] {
        let q = Self.normalize(query)
        guard !q.isEmpty else {
            return foods.filter { (ratings.isEmpty || ratings.contains($0.rating)) && (category == nil || $0.category == category) }
        }
        let qWords = q.split(separator: " ").map(String.init)
        var scored: [(Food, Int)] = []
        for entry in index {
            if !ratings.isEmpty && !ratings.contains(entry.food.rating) { continue }
            if let category, entry.food.category != category { continue }
            let s = score(q: q, qWords: qWords, entry: entry)
            if s > 0 { scored.append((entry.food, s)) }
        }
        return scored.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name.count < $1.0.name.count }.map(\.0)
    }

    private func score(q: String, qWords: [String], entry: (food: Food, name: String, words: [String], aliases: [String])) -> Int {
        if entry.name == q { return 1000 }
        if entry.aliases.contains(q) { return 900 }
        if entry.name.hasPrefix(q) { return 800 }
        // every query word must prefix-match some word in the name
        let allWordsMatch = qWords.allSatisfy { qw in entry.words.contains { $0.hasPrefix(qw) } }
        if allWordsMatch { return 600 + (entry.words.first?.hasPrefix(qWords[0]) == true ? 50 : 0) }
        if entry.aliases.contains(where: { $0.hasPrefix(q) }) { return 550 }
        // mid-word matches are noisy for short queries ("avo" → "savoy")
        if q.count >= 4 {
            if entry.name.contains(q) { return 400 }
            if entry.aliases.contains(where: { $0.contains(q) }) { return 350 }
        }
        // typo tolerance on single words of 4+ chars
        if q.count >= 4 {
            let maxDist = q.count >= 7 ? 2 : 1
            let singular = Self.singular(q)
            for word in entry.words + entry.aliases where abs(word.count - q.count) <= maxDist + 2 {
                if Self.levenshtein(word, q) <= maxDist || Self.levenshtein(Self.singular(word), singular) <= maxDist { return 200 }
            }
            // "strawberies" vs "strawberry" style prefix typos
            for word in entry.words where word.count >= q.count - 1 {
                if Self.levenshtein(String(word.prefix(q.count)), q) <= 1 { return 150 }
            }
        }
        return 0
    }

    /// Crude singular form so "strawberies" still finds "strawberry".
    static func singular(_ w: String) -> String {
        if w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if w.hasSuffix("es") && w.count > 4 { return String(w.dropLast(2)) }
        if w.hasSuffix("s") && w.count > 3 { return String(w.dropLast()) }
        return w
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    /// Best single match for a free-text ingredient, used by the label scanner and meal builder.
    func bestMatch(for text: String) -> Food? {
        let q = Self.normalize(text)
        guard q.count >= 3 else { return nil }
        let results = search(q)
        guard let top = results.first else { return nil }
        let topName = Self.normalize(top.name)
        // only accept confident matches: exact, alias, or name-prefix
        if topName == q || top.aliases.map(Self.normalize).contains(q) || topName.hasPrefix(q) || q.hasPrefix(topName) {
            return top
        }
        let qWords = Set(q.split(separator: " "))
        let nameWords = Set(topName.split(separator: " "))
        return qWords.isSubset(of: nameWords) || nameWords.isSubset(of: qWords) ? top : nil
    }

    // MARK: - Swaps

    /// Hand-picked swaps for the most common high-FODMAP foods, keyed by a word in the food name.
    private static let swapHints: [(keyword: String, swaps: [String])] = [
        ("garlic", ["Garlic infused oil", "Chives", "Spring onion", "Ginger"]),
        ("onion", ["Spring onion", "Chives", "Garlic infused oil", "Leek"]),
        ("shallot", ["Spring onion", "Chives", "Garlic infused oil"]),
        ("honey", ["Maple syrup", "Rice malt syrup", "Golden syrup", "White sugar"]),
        ("agave", ["Maple syrup", "Rice malt syrup", "White sugar"]),
        ("bread", ["Spelt bread sourdough", "Gluten free breads", "Rice bread", "Oat bread", "Rice cakes"]),
        ("pasta", ["Gluten free pasta", "Rice noodles", "Quinoa", "Rice"]),
        ("couscous", ["Quinoa", "Rice", "Polenta", "Millet"]),
        ("milk", ["Lactose free milk", "Almond milk", "Rice milk", "Soy milk made with soy protein"]),
        ("yoghurt", ["Lactose free yoghurt", "Coconut yoghurt", "Greek yoghurt"]),
        ("yogurt", ["Lactose free yogurt", "Greek yogurt"]),
        ("ice cream", ["Lactose free cow's milk ice cream", "Sorbet", "Dark chocolate"]),
        ("cheese", ["Cheddar", "Parmesan", "Brie", "Feta", "Mozzarella"]),
        ("apple", ["Orange", "Kiwifruit", "Strawberry", "Pineapple", "Grapes"]),
        ("pear", ["Orange", "Kiwifruit", "Strawberry", "Grapes"]),
        ("mango", ["Pineapple", "Papaya", "Kiwifruit", "Orange"]),
        ("watermelon", ["Cantaloupe", "Honeydew", "Pineapple"]),
        ("cashew", ["Peanuts", "Macadamia", "Walnuts", "Pecans"]),
        ("pistachio", ["Peanuts", "Macadamia", "Walnuts", "Pumpkin seeds"]),
        ("mushroom", ["Oyster mushrooms", "Canned mushrooms", "Zucchini", "Eggplant"]),
        ("cauliflower", ["Broccoli", "Zucchini", "Carrot", "Green beans"]),
        ("bean", ["Tofu", "Canned lentils", "Chickpeas canned", "Green beans"]),
        ("lentil", ["Canned lentils", "Tofu", "Quinoa"]),
        ("hummus", ["Peanut butter", "Baba ganoush", "Tahini"]),
        ("avocado", ["Cucumber", "Olives", "Tomato"]),
        ("asparagus", ["Green beans", "Zucchini", "Broccoli"]),
    ]

    /// Low-FODMAP alternatives: curated suggestions first, then same-category foods sharing words.
    func swaps(for food: Food, limit: Int = 8) -> [Food] {
        guard food.rating != .low else { return [] }
        let lowered = food.name.lowercased()
        var curated: [Food] = []
        for hint in Self.swapHints where lowered.contains(hint.keyword) {
            for q in hint.swaps {
                if let match = search(q).first(where: { $0.rating == .low && $0.id != food.id }), !curated.contains(match) {
                    curated.append(match)
                }
            }
            break
        }
        if curated.count >= 3 { return Array(curated.prefix(limit)) }
        let words: Set<String> = Set(Self.normalize(food.name).split(separator: " ").map(String.init).filter { $0.count > 3 })
        let candidates = foods.filter { $0.category == food.category && $0.rating == .low && $0.id != food.id }
        let ranked: [(food: Food, score: Int)] = candidates.map { c in
            let cw: Set<String> = Set(Self.normalize(c.name).split(separator: " ").map(String.init))
            return (c, words.intersection(cw).count * 10 + c.sourceCount)
        }
        let sorted = ranked.sorted { a, b in
            a.score != b.score ? a.score > b.score : a.food.name < b.food.name
        }
        let rest = sorted.map(\.food).filter { !curated.contains($0) }
        return Array((curated + rest).prefix(limit))
    }
}
