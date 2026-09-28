import SwiftData
import SwiftUI

struct CheckView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case meal = "Meal"
        case label = "Ingredient label"
        var id: String { rawValue }
    }

    @State private var mode: Mode = UserDefaults.standard.string(forKey: "checkMode") == "label" ? .label : .meal

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PageIntro(title: "Check your plate", subtitle: "A quick answer before you eat.")
                    .padding(.horizontal, 20)
                    .padding(.top, 13)
                    .padding(.bottom, 19)
                HStack(spacing: 4) {
                    modeButton(.meal, symbol: "fork.knife")
                    modeButton(.label, symbol: "text.viewfinder")
                }
                .padding(5)
                .padding(.horizontal, 20)
                .padding(.bottom, 15)
                switch mode {
                case .meal: MealCheckView()
                case .label: LabelScanView()
                }
            }
            .background(Color.pageBackground)
            .navigationTitle(" ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Food.self) { FoodDetailView(food: $0) }
        }
    }

    private func modeButton(_ value: Mode, symbol: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { mode = value } } label: {
            Label(value.rawValue, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(mode == value ? AppStyle.pine : AppStyle.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 39)
                .background(mode == value ? AppStyle.paper : .clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}

struct VerdictCard: View {
    let rating: Rating
    let title: String
    var subtitle: String?

    var body: some View {
        ZStack(alignment: .trailing) {
            PlateMark(symbol: rating.symbol, size: 125, tint: .white)
                .opacity(0.38)
                .offset(x: 32, y: 15)
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    Circle().fill(rating.color).frame(width: 8, height: 8)
                    Text("Your meal verdict")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppStyle.mist)
                }
                Text(title)
                    .font(AppStyle.display(26))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppStyle.mist)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 142)
        .background(AppStyle.pine, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .clipped()
        .animation(.spring, value: rating)
    }
}

struct MealCheckView: View {
    @Environment(FoodStore.self) private var store
    @Environment(MealBuilder.self) private var meal
    @Environment(\.modelContext) private var context
    @Query private var preferences: [FoodPreference]
    @Query private var challenges: [ChallengeRecord]

    @State private var showPicker = false
    @State private var logType = MealType.suggested()
    @State private var logged = false

    var body: some View {
        @Bindable var meal = meal
        let personal = PersonalData(preferences: preferences, challenges: challenges)
        let foods = meal.foodIDs.compactMap { store.food($0) }
        let analysis = MealAnalysis(foods: foods, reactions: personal.reactions, tolerance: personal.tolerance)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if foods.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        PlateMark(symbol: "fork.knife", size: 118, tint: AppStyle.pine)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                        Text("Every ingredient\ncounts.")
                            .font(AppStyle.display(29))
                            .tracking(-0.7)
                            .foregroundStyle(AppStyle.ink)
                        Text("Add the foods in your meal. We’ll check the whole plate, including how portions can add up.")
                            .font(.subheadline)
                            .foregroundStyle(AppStyle.muted)
                        Button {
                            showPicker = true
                        } label: {
                            Label("Add ingredients", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppStyle.pine)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 27))
                } else {
                    VerdictCard(rating: analysis.overall, title: analysis.headline,
                                subtitle: "\(foods.count) ingredient\(foods.count == 1 ? "" : "s") · \(analysis.problemItems.count) to watch")

                    if !analysis.stackedGroups.isEmpty {
                        stackingMeter(analysis)
                    }

                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(analysis.items) { item in
                                HStack(spacing: 12) {
                                    NavigationLink(value: item.food) {
                                        HStack(spacing: 12) {
                                            EmojiTile(emoji: item.food.emoji, rating: item.effective, size: 40)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.food.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                                Text(item.reason ?? (item.food.serving.map { "Safe serve: \($0)" } ?? item.effective.verdict))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                            Spacer()
                                            RatingPill(rating: item.effective, compact: true)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    Button {
                                        withAnimation { meal.remove(item.food.id) }
                                    } label: {
                                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove \(item.food.name)")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                if item.id != analysis.items.last?.id { Divider().padding(.leading, 66) }
                            }
                        }
                    }

                    if !analysis.advice.isEmpty {
                        Card {
                            Label("Tips", systemImage: "sparkles").font(.headline)
                            ForEach(analysis.advice, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(tip).fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            showPicker = true
                        } label: {
                            Label("Add", systemImage: "plus").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        Button(role: .destructive) {
                            withAnimation { meal.foodIDs = [] }
                        } label: {
                            Label("Clear", systemImage: "trash").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)

                    Card {
                        Text("Ate it?").font(.headline)
                        Picker("Meal", selection: $logType) {
                            ForEach(MealType.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        Button {
                            context.insert(MealLog(mealType: logType, foodIDs: meal.foodIDs))
                            logged.toggle()
                            withAnimation { meal.foodIDs = [] }
                        } label: {
                            Label("Log to diary", systemImage: "book.closed.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .sensoryFeedback(.success, trigger: logged)
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showPicker) {
            FoodPickerSheet(title: "Add ingredients", selection: $meal.foodIDs)
        }
    }

    private func stackingMeter(_ analysis: MealAnalysis) -> some View {
        Card {
            Label("FODMAP stacking", systemImage: "square.stack.3d.up.fill")
                .font(.headline)
                .foregroundStyle(Color.fodmapAmber)
            Text("Moderate foods from the same group add up. On their own each is fine; together they can tip the meal into high.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(analysis.stackedGroups) { g in
                let count = analysis.items.filter { $0.effective == .moderate && $0.food.triggerGroups.contains(g) }.count
                HStack {
                    Text("\(g.emoji) \(g.name)").font(.subheadline.weight(.medium))
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(0..<max(count, 3), id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i < count ? (i >= 1 ? Color.fodmapRed : Color.fodmapAmber) : Color.secondary.opacity(0.2))
                                .frame(width: 22, height: 10)
                        }
                    }
                }
            }
        }
    }
}
