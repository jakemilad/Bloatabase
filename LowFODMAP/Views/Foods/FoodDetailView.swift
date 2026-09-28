import SwiftData
import SwiftUI

struct FoodDetailView: View {
    @Environment(FoodStore.self) private var store
    @Environment(MealBuilder.self) private var meal
    @Environment(\.modelContext) private var context
    @Query private var preferences: [FoodPreference]
    @Query private var challenges: [ChallengeRecord]
    @Query private var shopping: [ShoppingItem]

    let food: Food

    @State private var toast: String?
    @State private var noteDraft = ""
    @State private var showGroupInfo: FodmapGroup?

    private var preference: FoodPreference? { preferences.first { $0.foodID == food.id } }
    private var tolerance: ToleranceProfile { ToleranceProfile(records: challenges) }
    private var category: FoodCategory? { store.category(food.category) }
    private var isOnList: Bool { shopping.contains { $0.foodID == food.id && !$0.isChecked } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                hero
                personalCallout
                actions
                breakdown
                if !food.notes.isEmpty { notes }
                swaps
                reactionPicker
                sources
            }
            .padding(20)
        }
        .background(Color.pageBackground)
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: preference?.isFavorite == true ? "heart.fill" : "heart")
                        .foregroundStyle(preference?.isFavorite == true ? Color.fodmapRed : Color.accentColor)
                }
                .sensoryFeedback(.impact, trigger: preference?.isFavorite)
                .accessibilityLabel(preference?.isFavorite == true ? "Remove from favourites" : "Add to favourites")
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $showGroupInfo) { g in
            GroupInfoSheet(group: g).presentationDetents([.medium])
        }
        .onAppear {
            store.markViewed(food)
            noteDraft = preference?.note ?? ""
        }
    }

    // MARK: - Sections

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppStyle.pine)
            PlateMark(symbol: food.rating.symbol, size: 210, tint: .white)
                .opacity(0.34)
                .offset(x: 185, y: -22)
            VStack(alignment: .leading, spacing: 0) {
                if let category {
                    Text(category.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.mist)
                }
                Spacer(minLength: 20)
                Text(food.name)
                    .font(AppStyle.display(food.name.count > 26 ? 29 : 36))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 19)
                HStack(spacing: 9) {
                    Image(systemName: food.rating.symbol).font(.subheadline.weight(.bold))
                    Text("\(food.rating.label) FODMAP")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(food.rating.color, in: Capsule())
                .padding(.bottom, 9)
                Text(servingLine)
                    .font(.subheadline)
                    .foregroundStyle(AppStyle.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var servingLine: String {
        switch food.rating {
        case .low:
            return food.serving.map { "Low FODMAP up to \($0)" } ?? "Low FODMAP in normal servings"
        case .moderate:
            return food.serving.map { "OK in small amounts — keep to \($0)" } ?? "Small amounts may be tolerated"
        case .high:
            return food.serving.map { "High FODMAP — only tolerated around \($0)" } ?? "High FODMAP in typical servings"
        }
    }

    @ViewBuilder
    private var personalCallout: some View {
        if let reaction = preference?.reaction {
            callout(emoji: reaction.emoji, title: "Your experience: \(reaction.label)",
                    message: reaction.rating == food.rating ? "Matches the general rating." : "You've marked this differently from the general rating.",
                    color: reaction.rating.color)
        } else if let personal = tolerance.personalRating(for: food) {
            callout(emoji: "🧪", title: "Personalised: \(personal.rating.label)", message: personal.reason, color: personal.rating.color)
        }
    }

    private func callout(emoji: String, title: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                meal.add(food)
                flash("Added to your meal check")
            } label: {
                Label(meal.contains(food) ? "Added to meal" : "Add to meal check", systemImage: meal.contains(food) ? "checkmark" : "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(AppStyle.pine, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                actionButton(title: "Log food", symbol: "plus.circle") { logNow() }
                actionButton(title: isOnList ? "On list" : "Shopping list", symbol: isOnList ? "checkmark.circle" : "basket") { addToList() }
            }
        }
    }

    private func actionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.subheadline)
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppStyle.pine)
    }

    private var breakdown: some View {
        Card {
            HStack {
                Text("FODMAP breakdown").font(.headline)
                Spacer()
                if food.groups.isEmpty && food.rating != .low {
                    Text("Not tested per group").font(.caption).foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(FodmapGroup.allCases) { g in
                    Button { showGroupInfo = g } label: { groupCell(g) }
                        .buttonStyle(.plain)
                }
            }
            Text("Tap a group to learn more. Tested tolerance from your reintroduction shows as a badge.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func groupCell(_ g: FodmapGroup) -> some View {
        let level = food.level(for: g)
        let rating = level.map { Rating(level: $0) }
        let color = rating?.color ?? .secondary
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(rating == nil ? AnyShapeStyle(Color.secondary.opacity(0.2)) : AnyShapeStyle(color.gradient))
                    .frame(width: 30, height: 30)
                    .overlay {
                        if rating == nil { Text("?").font(.caption.weight(.bold)).foregroundStyle(.secondary) }
                    }
                if let status = tolerance.status(for: g), let r = status.rating {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(r.color)
                        .background(Circle().fill(Color.cardBackground))
                        .offset(x: 6, y: -4)
                }
            }
            Text(g.name).font(.caption.weight(.semibold))
            Text(rating?.label ?? "Unknown").font(.caption2).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var notes: some View {
        Card {
            Label("Good to know", systemImage: "lightbulb.fill").font(.headline)
            ForEach(food.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(note)
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var swaps: some View {
        let options = store.swaps(for: food)
        if !options.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Low FODMAP swaps").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(options) { swap in
                            NavigationLink(value: swap) { FoodCard(food: swap) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
    }

    private var reactionPicker: some View {
        Card {
            Text("How does it treat you?").font(.headline)
            Text("Your own experience overrides the general rating in searches and meal checks.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(PersonalReaction.allCases) { r in
                    let selected = preference?.reaction == r
                    Button {
                        setReaction(selected ? nil : r)
                    } label: {
                        VStack(spacing: 4) {
                            Text(r.emoji).font(.title2)
                            Text(r.label).font(.caption.weight(.medium)).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? r.rating.color.opacity(0.2) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(selected ? r.rating.color : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField("Personal note (e.g. “fine with 5 almonds”)", text: $noteDraft, axis: .vertical)
                .font(.subheadline)
                .padding(10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .onSubmit(saveNote)
                .onChange(of: noteDraft) { _, _ in saveNote() }
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: food.sourcesDisagree ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .foregroundStyle(food.sourcesDisagree ? Color.fodmapAmber : Color.fodmapGreen)
                Text(food.sourcesDisagree
                     ? "Sources disagree on this food — rated conservatively."
                     : "Rated by \(food.sourceCount) of 3 source lists.")
            }
            .font(.caption.weight(.medium))
            Text("Everyone's tolerance is different. Check with your dietitian if unsure.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func preferenceOrCreate() -> FoodPreference {
        if let preference { return preference }
        let p = FoodPreference(foodID: food.id)
        context.insert(p)
        return p
    }

    private func toggleFavorite() {
        let p = preferenceOrCreate()
        p.isFavorite.toggle()
        p.updatedAt = .now
        flash(p.isFavorite ? "Added to favourites" : "Removed from favourites")
    }

    private func setReaction(_ r: PersonalReaction?) {
        preferenceOrCreate().reaction = r
    }

    private func saveNote() {
        guard noteDraft != (preference?.note ?? "") else { return }
        preferenceOrCreate().note = noteDraft
    }

    private func addToList() {
        guard !isOnList else { return flash("Already on your shopping list") }
        context.insert(ShoppingItem(name: food.name, foodID: food.id))
        flash("Added to shopping list")
    }

    private func logNow() {
        let type = MealType.suggested()
        context.insert(MealLog(mealType: type, foodIDs: [food.id]))
        flash("Logged to \(type.label.lowercased())")
    }

    private func flash(_ message: String) {
        withAnimation(.spring) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation { if toast == message { toast = nil } }
        }
    }
}

struct GroupInfoSheet: View {
    let group: FodmapGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(group.emoji).font(.system(size: 44))
                VStack(alignment: .leading) {
                    Text(group.name).font(.title2.weight(.bold))
                    Text(group.family).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text(group.summary)
            VStack(alignment: .leading, spacing: 8) {
                Text("Common sources").font(.headline)
                FlowLayout {
                    ForEach(group.commonSources, id: \.self) { s in
                        Text(s)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.fodmapRed.opacity(0.1), in: Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }
}
