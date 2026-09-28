import SwiftData
import SwiftUI
import UserNotifications

struct MoreView: View {
    @Environment(\.modelContext) private var context
    @Query private var shopping: [ShoppingItem]
    @Query private var preferences: [FoodPreference]
    @AppStorage("dietPhase") private var phaseRaw = DietPhase.elimination.rawValue
    @AppStorage("hasOnboarded") private var hasOnboarded = true

    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    PageIntro(title: "Your corner", subtitle: "Everything for the journey ahead.")
                    HStack(spacing: 15) {
                        Image(systemName: "leaf.circle")
                            .font(.system(size: 38, weight: .ultraLight))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Make this yours")
                                .font(AppStyle.display(23))
                            Text("Your lists, saved foods and step settings live here.")
                                .font(.caption)
                                .foregroundStyle(AppStyle.mist)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(19)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppStyle.pine, in: RoundedRectangle(cornerRadius: 23))
                    Card {
                    Text("Current step")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.muted)
                    Picker(selection: $phaseRaw) {
                        ForEach(DietPhase.allCases) { p in
                            Text("\(p.emoji) \(p.shortTitle)").tag(p.rawValue)
                        }
                    } label: {
                        Label("Current step", systemImage: "figure.walk")
                    }
                    Text((DietPhase(rawValue: phaseRaw) ?? .elimination).guidance)
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                }
                    VStack(alignment: .leading, spacing: 11) {
                        SectionHeader(title: "Your things")
                    NavigationLink {
                        ShoppingListView()
                    } label: {
                        row("Shopping list", symbol: "cart.fill", color: .blue, badge: shopping.filter { !$0.isChecked }.count)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        MyFoodsView()
                    } label: {
                        row("My foods", symbol: "heart.fill", color: .fodmapRed, badge: preferences.filter { $0.isFavorite || $0.reaction != nil }.count)
                    }
                    .buttonStyle(.plain)
                }
                    VStack(alignment: .leading, spacing: 11) {
                    SectionHeader(title: "The field guide")
                    ForEach(Guide.all) { guide in
                        NavigationLink {
                            GuideView(guide: guide)
                        } label: {
                            HStack(spacing: 12) {
                                Text(guide.emoji).font(.title3).frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(guide.title).font(.subheadline.weight(.semibold)).foregroundStyle(AppStyle.ink)
                                    Text(guide.subtitle).font(.caption).foregroundStyle(AppStyle.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(AppStyle.muted)
                            }
                            .padding(16)
                            .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 19))
                        }
                        .buttonStyle(.plain)
                    }
                }
                    VStack(alignment: .leading, spacing: 12) {
                    Button("Show welcome again") { hasOnboarded = false }
                    Button("Erase all my data", role: .destructive) { confirmReset = true }
                    Text("Food data merged from the open-source fodmap-diet/basket, fodmap_list and foodmap projects. This app is not affiliated with Monash University. It isn't medical advice — work with a registered dietitian where you can.")
                        .font(.caption)
                        .foregroundStyle(AppStyle.muted)
                }
                }
                .padding(.horizontal, 20)
                .padding(.top, 13)
                .padding(.bottom, 30)
            }
            .background(AppStyle.canvas)
            .navigationTitle(" ")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Erase your diary, challenges, shopping list and personal ratings?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive, action: eraseAll)
            }
        }
    }

    private func row(_ title: String, symbol: String, color: Color, badge: Int) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppStyle.ink)
            Spacer()
            if badge > 0 {
                Text("\(badge)").foregroundStyle(AppStyle.muted).monospacedDigit()
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(AppStyle.muted)
        }
        .padding(14)
        .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 19))
    }

    private func eraseAll() {
        try? context.delete(model: MealLog.self)
        try? context.delete(model: SymptomLog.self)
        try? context.delete(model: ChallengeRecord.self)
        try? context.delete(model: ShoppingItem.self)
        try? context.delete(model: FoodPreference.self)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

struct ShoppingListView: View {
    @Environment(FoodStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
                    TextField("Add item", text: $draft)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                }
                if let match = draftMatch {
                    HStack(spacing: 8) {
                        RatingDot(rating: match.rating, size: 10)
                        Text("\(match.name) is \(match.rating.label.lowercased()) FODMAP")
                            .font(.caption)
                            .foregroundStyle(match.rating.color)
                    }
                }
            }
            let byCategory = Dictionary(grouping: items.filter { !$0.isChecked }) { item in
                item.foodID.flatMap { store.food($0)?.category } ?? "other"
            }
            ForEach(byCategory.keys.sorted { (store.category($0)?.name ?? "zz") < (store.category($1)?.name ?? "zz") }, id: \.self) { cat in
                Section(store.category(cat).map { "\($0.emoji) \($0.name)" } ?? "Other") {
                    ForEach(byCategory[cat] ?? []) { itemRow($0) }
                        .onDelete { idx in idx.forEach { context.delete((byCategory[cat] ?? [])[$0]) } }
                }
            }
            let done = items.filter(\.isChecked)
            if !done.isEmpty {
                Section {
                    ForEach(done) { itemRow($0) }
                } header: {
                    HStack {
                        Text("In the basket")
                        Spacer()
                        Button("Clear") { done.forEach { context.delete($0) } }.font(.caption)
                    }
                }
            }
            if items.isEmpty {
                EmptyStateView(emoji: "🛒", title: "Your list is empty",
                               message: "Add foods from any food page, or type them above — we'll flag anything that's high FODMAP.")
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Shopping list")
    }

    private var draftMatch: Food? {
        draft.count >= 3 ? store.bestMatch(for: draft) : nil
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        let food = item.foodID.flatMap { store.food($0) }
        return Button {
            withAnimation { item.isChecked.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Color.accentColor : .secondary)
                if let food { Text(food.emoji) }
                Text(item.name)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                Spacer()
                if let food, food.rating != .low {
                    RatingPill(rating: food.rating, compact: true)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.isChecked)
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let match = store.bestMatch(for: t)
        context.insert(ShoppingItem(name: match?.name ?? t.capitalizedFirst, foodID: match?.id))
        draft = ""
        focused = true
    }
}

struct MyFoodsView: View {
    @Environment(FoodStore.self) private var store
    @Query(sort: \FoodPreference.updatedAt, order: .reverse) private var preferences: [FoodPreference]

    var body: some View {
        List {
            let favs = preferences.filter(\.isFavorite).compactMap { p in store.food(p.foodID).map { (p, $0) } }
            let rated = preferences.filter { $0.reaction != nil }.compactMap { p in store.food(p.foodID).map { (p, $0) } }
            if favs.isEmpty && rated.isEmpty {
                EmptyStateView(emoji: "💚", title: "No saved foods yet",
                               message: "Tap the heart on a food, or tell us how it treats you, and it'll show up here.")
                    .listRowBackground(Color.clear)
            }
            if !favs.isEmpty {
                Section("Favourites") {
                    ForEach(favs, id: \.1.id) { p, food in
                        NavigationLink(value: food) { FoodRow(food: food, personal: p.reaction?.rating) }
                    }
                }
            }
            ForEach(PersonalReaction.allCases) { r in
                let list = rated.filter { $0.0.reaction == r }
                if !list.isEmpty {
                    Section("\(r.emoji) \(r.label)") {
                        ForEach(list, id: \.1.id) { p, food in
                            NavigationLink(value: food) {
                                VStack(alignment: .leading, spacing: 2) {
                                    FoodRow(food: food, personal: r.rating)
                                    if !p.note.isEmpty {
                                        Text(p.note).font(.caption).foregroundStyle(.secondary).padding(.leading, 56)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My foods")
        .navigationDestination(for: Food.self) { FoodDetailView(food: $0) }
    }
}
