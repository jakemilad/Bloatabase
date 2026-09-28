import Foundation

/// Reads a packaged-food ingredient list and flags ingredients that are high in FODMAPs.
struct IngredientAnalyzer {
    struct Rule {
        let pattern: String
        let rating: Rating
        let groups: [FodmapGroup]
        let reason: String
        let regex: NSRegularExpression

        init(_ pattern: String, _ rating: Rating, _ groups: [FodmapGroup], _ reason: String) {
            self.pattern = pattern
            self.rating = rating
            self.groups = groups
            self.reason = reason
            self.regex = try! NSRegularExpression(pattern: "\\b(?:" + pattern + ")\\b", options: [.caseInsensitive])
        }

        func matches(_ s: String) -> Bool {
            regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }
    }

    struct Finding: Identifiable, Hashable {
        let id = UUID()
        let ingredient: String
        let rating: Rating?
        let groups: [FodmapGroup]
        let reason: String
        let matchedFoodID: String?

        static func == (a: Finding, b: Finding) -> Bool { a.id == b.id }
        func hash(into h: inout Hasher) { h.combine(id) }
    }

    struct Report {
        let findings: [Finding]

        var flagged: [Finding] { findings.filter { ($0.rating ?? .low) > .low } }
        var high: [Finding] { findings.filter { $0.rating == .high } }
        var moderate: [Finding] { findings.filter { $0.rating == .moderate } }

        var overall: Rating {
            if !high.isEmpty { return .high }
            if !moderate.isEmpty { return .moderate }
            return .low
        }

        var groups: [FodmapGroup] {
            FodmapGroup.allCases.filter { g in flagged.contains { $0.groups.contains(g) } }
        }

        var headline: String {
            switch overall {
            case .high: "Contains high-FODMAP ingredients"
            case .moderate: "Check portion size or hidden ingredients"
            case .low: findings.isEmpty ? "No ingredients found" : "No high-FODMAP ingredients spotted"
            }
        }
    }

    /// Checked first: things that look like triggers but are fine.
    static let safeRules: [Rule] = [
        Rule("garlic[- ]infused (?:olive )?oil|garlic oil|onion[- ]infused oil", .low, [], "Infused oils are low FODMAP — fructans don't dissolve into oil."),
        Rule("lactose[- ]free\\s?\\w*|lactose free", .low, [], "Lactose-free dairy is low FODMAP."),
        Rule("(?:coconut|almond|rice|macadamia) milk", .low, [], "Low FODMAP plant milk."),
        Rule("cocoa butter|butter ?fat|milk ?fat|anhydrous milk fat|ghee|butter", .low, [], "Fats contain almost no lactose."),
        Rule("green beans?|vanilla beans?|coffee beans?|cocoa beans?|jelly beans?", .low, [], "Not a legume source of GOS."),
        Rule("soy(?:a|bean)? (?:lecithin|oil)|soybean oil|lecithin|soy protein isolate|soy sauce|tamari|tofu|pea protein(?: isolate)?", .low, [], "Low FODMAP soy or pea derivative."),
        Rule("wheat starch|wheat glucose syrup|glucose syrup|glucose|dextrose|maltodextrin|wheat maltodextrin|modified (?:wheat |maize |corn |tapioca )?starch", .low, [], "Highly refined — FODMAPs are removed in processing."),
        Rule("erythritol|e968|stevia|steviol glycosides?|sucralose|aspartame|acesulfame(?: k)?|saccharin|monk fruit", .low, [], "Low FODMAP sweetener."),
        Rule("whey protein isolate", .low, [], "Isolate has most lactose removed."),
        Rule("chives|spring onion greens?|green part of (?:spring onion|leek)|scallion greens?|asafoetida|hing", .low, [], "Low FODMAP way to get onion flavour."),
        Rule("cream of tartar|coconut cream|(?:apple )?cider vinegar|white vinegar|rice vinegar|wine vinegar|spirit vinegar", .low, [], "Low FODMAP in normal amounts."),
        Rule("sugar|sucrose|cane sugar|brown sugar|rice malt syrup|maple syrup|golden syrup", .low, [], "Table sugar is low FODMAP in normal amounts."),
    ]

    static let triggerRules: [Rule] = [
        // Fructans
        Rule("onions?(?: powder| salt| extract| flakes| juice)?|dehydrated onion|shallots?|leeks?|spring onion(?: bulb)?s?", .high, [.fructans], "Onion family — one of the most common fructan triggers."),
        Rule("garlic(?: powder| salt| extract| paste| puree| flakes)?|dehydrated garlic", .high, [.fructans], "Garlic is very high in fructans, even in small amounts."),
        Rule("inulin|chicory(?: root)?(?: fibre| fiber| extract)?|oligofructose|fructo-?oligosaccharides?|fos|agave inulin|yacon", .high, [.fructans], "Added prebiotic fibre — high in fructans."),
        Rule("wheat(?: flour| bran| germ| protein)?|whole ?wheat|wholemeal|atta|durum|semolina|couscous|bulgur|freekeh|farro|kamut|einkorn|rye(?: flour)?|barley(?: flour)?", .high, [.fructans], "Wheat, rye and barley are high in fructans in normal serves."),
        Rule("spelt(?: flour)?", .moderate, [.fructans], "Spelt is lower than wheat, but still a source of fructans."),
        Rule("(?:barley )?malt(?: extract| flour| vinegar)?|malted barley", .moderate, [.fructans], "Usually used in small amounts — generally OK, but watch large serves."),
        Rule("artichoke|asparagus|beetroot|dandelion|pistachios?|cashews?", .high, [.fructans, .gos], "High in fructans or GOS."),
        // GOS
        Rule("chick ?peas?|garbanzo|besan|gram flour|lentils?|kidney beans?|black beans?|baked beans|haricot|borlotti|cannellini|navy beans?|pinto beans?|broad beans?|fava|lupin(?: flour)?|soy(?:a|bean)? flour|split peas?|beans?|legumes?|pulses?", .high, [.gos], "Legumes are high in GOS."),
        // Lactose
        Rule("milk(?: powder| solids)?|whole milk|skim(?:med)? milk(?: powder)?|milk solids|non-?fat milk|dairy solids|lactose|condensed milk|evaporated milk|buttermilk|cream cheese|ricotta|cottage cheese|mascarpone|quark|custard|ice cream|yogh?urt|kefir", .high, [.lactose], "Contains lactose."),
        Rule("whey(?: powder| protein concentrate| protein)?|cream|sour cream|milk chocolate|milk protein concentrate", .moderate, [.lactose], "Contains some lactose — small amounts may be OK."),
        // Fructose
        Rule("honey|agave(?: syrup| nectar)?|high[- ]fructose corn syrup|hfcs|glucose-fructose syrup|fructose-glucose syrup|fructose(?: syrup)?|crystalline fructose|isoglucose", .high, [.fructose], "Excess fructose."),
        Rule("(?:apple|pear|mango|grape) juice(?: concentrate)?|fruit juice concentrate|concentrated (?:apple|pear|fruit) juice|apples?|pears?|mangoe?s?|dried fruit|raisins?|sultanas?|dates?|figs?|prunes?", .high, [.fructose, .sorbitol], "High-fructose or polyol fruit."),
        // Polyols
        Rule("sorbitol|e420|xylitol|e967|maltitol(?: syrup)?|e965|isomalt|e953|lactitol|e966|polyols?|sugar alcohols?|hydrogenated starch hydrolysates?", .high, [.sorbitol], "Polyol sweetener — often found in 'sugar-free' products."),
        Rule("mannitol|e421|mushrooms?|cauliflower", .high, [.mannitol], "High in mannitol."),
        Rule("apricots?|peach(?:es)?|plums?|nectarines?|cherr(?:y|ies)|blackberr(?:y|ies)|watermelon", .high, [.sorbitol, .fructose], "Stone fruit and berries high in polyols."),
        // Hidden-ingredient warnings
        Rule("natural flavou?rs?|flavou?rings?|spices?|seasoning|herbs? and spices|vegetable (?:powder|extract|stock|bouillon)|stock powder|yeast extract|hydrolysed vegetable protein", .moderate, [.fructans], "May hide onion or garlic — check with the manufacturer."),
        Rule("isomalto-?oligosaccharides?|imo|polydextrose|fibre|fiber", .moderate, [], "Added fibre — some types can cause symptoms in larger amounts."),
    ]

    let store: FoodStore?

    init(store: FoodStore? = nil) {
        self.store = store
    }

    /// Splits a label into individual ingredients, including sub-ingredients in brackets.
    static func split(_ text: String) -> [String] {
        var t = text.replacingOccurrences(of: "\n", with: " ")
        if let r = t.range(of: "ingredients?\\s*:", options: [.regularExpression, .caseInsensitive]) {
            t = String(t[r.upperBound...])
        }
        // drop allergen statements that repeat ingredient names
        if let r = t.range(of: "\\b(?:contains|may contain|allergens?|made on|manufactured|produced in|nutrition)\\b", options: [.regularExpression, .caseInsensitive]) {
            t = String(t[..<r.lowerBound])
        }
        let separators = CharacterSet(charactersIn: ",;()[]{}•·|")
        return t.components(separatedBy: separators)
            .flatMap { $0.components(separatedBy: " and ") }
            .map { part in
                part.replacingOccurrences(of: "\\d+(?:[.,]\\d+)?\\s*%", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^[\\s.:*-]+|[\\s.:*-]+$", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            }
            .filter { $0.count >= 2 && $0.rangeOfCharacter(from: .letters) != nil }
    }

    func analyze(_ text: String) -> Report {
        var seen = Set<String>()
        var findings: [Finding] = []
        for ingredient in Self.split(text) {
            let key = ingredient.lowercased()
            guard seen.insert(key).inserted else { continue }
            findings.append(classify(ingredient))
        }
        // flagged first, then by original order
        let order: (Finding) -> Int = { -(($0.rating?.level ?? -1)) }
        return Report(findings: findings.enumerated().sorted {
            order($0.element) != order($1.element) ? order($0.element) < order($1.element) : $0.offset < $1.offset
        }.map(\.element))
    }

    func classify(_ ingredient: String) -> Finding {
        if let rule = Self.safeRules.first(where: { $0.matches(ingredient) }) {
            // a safe phrase wins unless a separate trigger also appears, e.g. "sugar, onion powder"
            let otherTrigger = Self.triggerRules.first { trigger in
                trigger.matches(ingredient.replacingOccurrences(of: rule.pattern, with: "", options: [.regularExpression, .caseInsensitive]))
            }
            if let otherTrigger {
                return Finding(ingredient: ingredient, rating: otherTrigger.rating, groups: otherTrigger.groups, reason: otherTrigger.reason, matchedFoodID: nil)
            }
            return Finding(ingredient: ingredient, rating: .low, groups: [], reason: rule.reason, matchedFoodID: nil)
        }
        if let rule = Self.triggerRules.first(where: { $0.matches(ingredient) }) {
            return Finding(ingredient: ingredient, rating: rule.rating, groups: rule.groups, reason: rule.reason, matchedFoodID: nil)
        }
        if let food = store?.bestMatch(for: ingredient) {
            let reason = food.rating == .low ? "Matches “\(food.name)” in the food guide." : "“\(food.name)” is rated \(food.rating.label.lowercased()) FODMAP."
            return Finding(ingredient: ingredient, rating: food.rating, groups: food.triggerGroups, reason: reason, matchedFoodID: food.id)
        }
        return Finding(ingredient: ingredient, rating: nil, groups: [], reason: "Not a known FODMAP source.", matchedFoodID: nil)
    }
}
