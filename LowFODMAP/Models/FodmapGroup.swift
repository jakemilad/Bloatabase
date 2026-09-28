import Foundation

/// The six FODMAP subgroups tested in the reintroduction phase.
enum FodmapGroup: String, Codable, CaseIterable, Identifiable {
    case fructans, gos, lactose, fructose, sorbitol, mannitol

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fructans: "Fructans"
        case .gos: "GOS"
        case .lactose: "Lactose"
        case .fructose: "Fructose"
        case .sorbitol: "Sorbitol"
        case .mannitol: "Mannitol"
        }
    }

    var family: String {
        switch self {
        case .fructans, .gos: "Oligosaccharide"
        case .lactose: "Disaccharide"
        case .fructose: "Monosaccharide"
        case .sorbitol, .mannitol: "Polyol"
        }
    }

    var shortName: String {
        switch self {
        case .fructans: "Fruc"
        case .gos: "GOS"
        case .lactose: "Lact"
        case .fructose: "Frut"
        case .sorbitol: "Sorb"
        case .mannitol: "Mann"
        }
    }

    var emoji: String {
        switch self {
        case .fructans: "🧄"
        case .gos: "🫘"
        case .lactose: "🥛"
        case .fructose: "🍯"
        case .sorbitol: "🍑"
        case .mannitol: "🍄"
        }
    }

    var summary: String {
        switch self {
        case .fructans: "Chains of fructose found in wheat, rye, barley, garlic, onion and some fruit and veg. The most common trigger."
        case .gos: "Galacto-oligosaccharides, found mainly in legumes like beans, lentils and chickpeas, plus cashews and pistachios."
        case .lactose: "The sugar in milk. Only a trigger if you don't make enough lactase; hard cheeses are naturally low."
        case .fructose: "A problem when a food has more fructose than glucose — e.g. honey, mango, apples and agave."
        case .sorbitol: "A sugar alcohol in stone fruit, apples, pears, blackberries and 'sugar-free' gum and mints."
        case .mannitol: "A sugar alcohol in mushrooms, cauliflower, celery and sweet potato."
        }
    }

    var commonSources: [String] {
        switch self {
        case .fructans: ["Wheat bread & pasta", "Garlic", "Onion", "Rye", "Barley", "Inulin / chicory root"]
        case .gos: ["Kidney beans", "Chickpeas", "Lentils", "Baked beans", "Cashews", "Pistachios"]
        case .lactose: ["Cow's milk", "Soft cheese", "Yoghurt", "Ice cream", "Custard"]
        case .fructose: ["Honey", "Mango", "Agave", "Apples", "Pears", "High-fructose corn syrup"]
        case .sorbitol: ["Apricots", "Peaches", "Plums", "Blackberries", "Avocado", "Sugar-free gum"]
        case .mannitol: ["Mushrooms", "Cauliflower", "Celery", "Sweet potato", "Snow peas"]
        }
    }
}
