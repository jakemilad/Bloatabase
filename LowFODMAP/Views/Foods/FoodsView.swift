import SwiftData
import SwiftUI

struct FoodsView: View {
    @Environment(FoodStore.self) private var store
    @Query private var preferences: [FoodPreference]
    @Query private var challenges: [ChallengeRecord]
    @AppStorage("dietPhase") private var phaseRaw = DietPhase.elimination.rawValue

    @State private var query = ""
    @State private var ratingFilter: Set<Rating> = []
    @State private var path = NavigationPath()
    @FocusState private var searchFocused: Bool

    private var personal: PersonalData { PersonalData(preferences: preferences, challenges: challenges) }
    private var phase: DietPhase { DietPhase(rawValue: phaseRaw) ?? .elimination }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty || !ratingFilter.isEmpty }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if !isSearching { homeHero }
                    searchBar
                        .padding(.horizontal, isSearching ? 0 : 15)
                        .offset(y: isSearching ? 0 : -54)
                        .padding(.bottom, isSearching ? 0 : -54)
                    if isSearching {
                        results
                    } else {
                        home
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color.pageBackground)
            .navigationTitle(" ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("fodmap.")
                        .font(AppStyle.display(25))
                        .tracking(-1.3)
                        .foregroundStyle(AppStyle.pine)
                }
            }
            .navigationDestination(for: Food.self) { FoodDetailView(food: $0) }
            .navigationDestination(for: FoodCategory.self) { CategoryView(category: $0) }
        }
        #if DEBUG
        .task {
            if let id = UserDefaults.standard.string(forKey: "openFood"), let food = store.food(id), path.isEmpty {
                path.append(food)
            }
            if let q = UserDefaults.standard.string(forKey: "searchQuery") { query = q }
        }
        #endif
    }

    // MARK: - Results

    private var results: some View {
        let found = store.search(query, ratings: ratingFilter)
        return LazyVStack(alignment: .leading, spacing: 17) {
            ratingChips
            if found.isEmpty {
                EmptyStateView(
                    emoji: "🔎",
                    title: "No match for “\(query)”",
                    message: "Try a simpler name, or check an ingredient label in the Check tab."
                )
            } else {
                Text("\(found.count) result\(found.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppStyle.muted)
                ForEach(found) { food in
                    NavigationLink(value: food) {
                        FoodRow(food: food, personal: personal.personalRating(for: food))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ratingChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Rating.allCases) { r in
                    FilterChip(title: r.label, color: r.color, isOn: ratingFilter.contains(r)) {
                        if ratingFilter.contains(r) { ratingFilter.remove(r) } else { ratingFilter.insert(r) }
                    }
                }
                if !ratingFilter.isEmpty {
                    Button("Clear") { ratingFilter = [] }
                        .font(.subheadline)
                        .padding(.leading, 4)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppStyle.jade)
            TextField("Search a food or ingredient", text: $query)
                .font(.subheadline)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel("Search foods")
            if !query.isEmpty {
                Button { query = ""; searchFocused = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppStyle.muted)
                }
                .accessibilityLabel("Clear search")
            } else {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.muted)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(AppStyle.ink.opacity(0.06)))
        .shadow(color: AppStyle.ink.opacity(0.06), radius: 16, y: 7)
    }

    // MARK: - Home

    private var favorites: [Food] {
        preferences.filter(\.isFavorite).sorted { $0.updatedAt > $1.updatedAt }.compactMap { store.food($0.foodID) }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Find by rating")
                    ratingChips
                }
                if !favorites.isEmpty {
                    foodStrip(title: "Favourites", foods: favorites)
                }
                if !store.recents.isEmpty {
                    foodStrip(title: "Recently viewed", foods: store.recents, clear: store.clearRecents)
                }
                commonTraps
                categoryGrid
                phaseNote
                Text("Ratings merged from three open-source FODMAP lists. They aren't a substitute for advice from a dietitian, and serving sizes matter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
        }
    }

    private var homeHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppStyle.pine)
            PlateMark(symbol: "leaf", size: 220, tint: AppStyle.mist)
                .opacity(0.8)
                .offset(x: 185, y: 40)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Circle().fill(AppStyle.mist).frame(width: 7, height: 7)
                    Text("Your food guide")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppStyle.mist)
                .padding(.bottom, 20)
                Text("Eat with\nconfidence.")
                    .font(AppStyle.display(36))
                    .tracking(-1.2)
                    .lineSpacing(-1)
                    .foregroundStyle(.white)
                Spacer(minLength: 10)
                Text("\(store.foods.count) foods to explore")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppStyle.mist)
                    .padding(.bottom, 24)
            }
            .padding(26)
        }
        .frame(height: 245)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var phaseNote: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "circle.dotted.circle")
                .font(.title2)
                .foregroundStyle(AppStyle.jade)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your journey · \(phase.shortTitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppStyle.ink)
                Text(phase.guidance)
                    .font(.caption)
                    .foregroundStyle(AppStyle.muted)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.mist.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
    }

    private func foodStrip(title: String, foods: [Food], clear: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, trailing: clear == nil ? nil : "Clear", action: clear)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(foods) { food in
                        NavigationLink(value: food) {
                            FoodCard(food: food, personal: personal.personalRating(for: food))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    private static let trapIDs = ["garlic", "onions", "honey", "apples", "regular-breads", "cow-milk", "cashews", "mushrooms", "avocado", "cauliflower", "mango", "baked-beans"]

    private var commonTraps: some View {
        let traps = Self.trapIDs.compactMap { store.food($0) }
        return Group {
            if !traps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Common traps")
                    Text("Everyday foods that are surprisingly high in FODMAPs.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(traps) { food in
                                NavigationLink(value: food) {
                                    FoodCard(food: food, personal: personal.personalRating(for: food))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, -20)
                }
            }
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Browse")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(store.categories) { cat in
                    NavigationLink(value: cat) {
                        CategoryTile(category: cat, foods: store.foods(in: cat.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct FoodCard: View {
    let food: Food
    var personal: Rating?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                EmojiTile(emoji: food.emoji, rating: personal ?? food.rating, size: 52)
                Spacer()
                RatingDot(rating: personal ?? food.rating, size: 13)
            }
            Text(food.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            RatingPill(rating: personal ?? food.rating, compact: true)
        }
        .padding(15)
        .frame(width: 158, height: 166, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AppStyle.ink.opacity(0.05)))
    }
}

struct CategoryTile: View {
    let category: FoodCategory
    let foods: [Food]

    var body: some View {
        let low = foods.filter { $0.rating == .low }.count
        let mod = foods.filter { $0.rating == .moderate }.count
        let high = foods.filter { $0.rating == .high }.count
        let total = max(foods.count, 1)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.emoji)
                    .font(.system(size: 25))
                    .frame(width: 45, height: 45)
                    .background(AppStyle.mist.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                Text("\(foods.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppStyle.muted)
            }
            Text(category.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppStyle.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule().fill(Color.fodmapGreen).frame(width: max(0, geo.size.width * CGFloat(low) / CGFloat(total) - 2))
                    if mod > 0 { Capsule().fill(Color.fodmapAmber).frame(width: max(2, geo.size.width * CGFloat(mod) / CGFloat(total) - 2)) }
                    if high > 0 { Capsule().fill(Color.fodmapRed).frame(width: max(2, geo.size.width * CGFloat(high) / CGFloat(total) - 2)) }
                }
            }
            .frame(height: 5)
        }
        .padding(15)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AppStyle.ink.opacity(0.05)))
    }
}

struct CategoryView: View {
    @Environment(FoodStore.self) private var store
    @Query private var preferences: [FoodPreference]
    @Query private var challenges: [ChallengeRecord]
    let category: FoodCategory

    @State private var filter: Rating?
    @State private var query = ""

    var body: some View {
        let personal = PersonalData(preferences: preferences, challenges: challenges)
        let foods = store.search(query, ratings: filter.map { [$0] } ?? [], category: category.id)
            .sorted { query.isEmpty ? ($0.rating != $1.rating ? $0.rating < $1.rating : $0.name < $1.name) : false }
        List {
            Section {
                Picker("Rating", selection: $filter) {
                    Text("All").tag(Rating?.none)
                    ForEach(Rating.allCases) { Text($0.label).tag(Rating?.some($0)) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ForEach(Rating.allCases) { rating in
                let section = foods.filter { $0.rating == rating }
                if !section.isEmpty {
                    Section {
                        ForEach(section) { food in
                            NavigationLink(value: food) {
                                FoodRow(food: food, personal: personal.personalRating(for: food))
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            RatingDot(rating: rating, size: 8)
                            Text("\(rating.label) · \(section.count)")
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search \(category.name.lowercased())")
        .navigationTitle("\(category.emoji) \(category.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
