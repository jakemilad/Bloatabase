import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(FoodStore.self) private var store
    @Query(sort: \MealLog.date) private var meals: [MealLog]
    @Query(sort: \SymptomLog.date) private var symptoms: [SymptomLog]

    var body: some View {
        let insights = TriggerInsights(meals: meals, symptoms: symptoms, store: store)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageIntro(title: "Your patterns", subtitle: "A clearer view of what agrees with you.")
                summary(insights)
                chart(insights)
                suspects(insights)
                if !insights.safeFoods.isEmpty { safeFoods(insights) }
                Text("Insights look at what you ate 30 minutes to 24 hours before each check-in. They show patterns, not proof — confirm suspicions with a reintroduction challenge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Color.pageBackground)
        .navigationTitle("Insights")
        .navigationDestination(for: Food.self) { FoodDetailView(food: $0) }
    }

    private func summary(_ i: TriggerInsights) -> some View {
        let lowMeals = meals.filter { m in m.foodIDs.allSatisfy { store.food($0)?.rating == .low } }.count
        return HStack(spacing: 10) {
            stat("\(meals.count)", "meals logged", .accentColor)
            stat(meals.isEmpty ? "–" : "\(Int(Double(lowMeals) / Double(meals.count) * 100))%", "fully low FODMAP", .fodmapGreen)
            stat(i.symptomLogCount == 0 ? "–" : String(format: "%.1f", i.averageSeverity), "avg symptoms", severityColor(i.averageSeverity))
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(AppStyle.display(28).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func chart(_ i: TriggerInsights) -> some View {
        Card {
            Text("Last 14 days").font(.headline)
            Text("Worst symptom score each day. Red markers show days with a high-FODMAP meal.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(i.days) { d in
                    if d.severity >= 0 {
                        BarMark(x: .value("Day", d.day, unit: .day), y: .value("Severity", d.severity))
                            .foregroundStyle(severityColor(d.severity).gradient)
                            .cornerRadius(4)
                    }
                    if d.highMeals > 0 {
                        PointMark(x: .value("Day", d.day, unit: .day), y: .value("High meal", 10.5))
                            .symbol(.circle)
                            .symbolSize(40)
                            .foregroundStyle(Color.fodmapRed)
                    }
                }
            }
            .chartYScale(domain: 0...11)
            .chartYAxis { AxisMarks(values: [0, 5, 10]) }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.narrow), centered: true)
                }
            }
            .frame(height: 180)
        }
    }

    private func suspects(_ i: TriggerInsights) -> some View {
        Card {
            Label("Possible triggers", systemImage: "exclamationmark.magnifyingglass").font(.headline)
            if i.symptomLogCount < 5 {
                Text("Log at least 5 symptom check-ins (and your meals) to start spotting patterns. You have \(i.symptomLogCount).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(min(i.symptomLogCount, 5)), total: 5)
            } else if i.suspects.isEmpty {
                Text("No food stands out yet — nice! Keep logging.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(i.suspects.prefix(8)) { s in
                    if let food = store.food(s.foodID) {
                        NavigationLink(value: food) {
                            HStack(spacing: 12) {
                                EmojiTile(emoji: food.emoji, rating: food.rating, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                    Text("Eaten before \(s.occurrences) check-ins · symptoms \(String(format: "%.1f", s.avgSeverityWith)) vs \(String(format: "%.1f", s.avgSeverityWithout)) otherwise")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if food.rating == .low {
                                        Text("Usually low FODMAP — may just be eaten alongside a trigger")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                Text("+\(String(format: "%.1f", s.lift))")
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Color.fodmapRed)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                let groups = FodmapGroup.allCases.filter { g in i.suspects.contains { store.food($0.foodID)?.triggerGroups.contains(g) == true } }
                if !groups.isEmpty {
                    Divider()
                    Text("Common thread: \(groups.map(\.name).joined(separator: ", ")). Consider challenging \(groups.count == 1 ? "this group" : "these groups") in the Reintroduce tab.")
                        .font(.subheadline)
                }
            }
        }
    }

    private func safeFoods(_ i: TriggerInsights) -> some View {
        Card {
            Label("Seem to agree with you", systemImage: "hand.thumbsup.fill").font(.headline)
            FlowLayout {
                ForEach(i.safeFoods.prefix(12)) { s in
                    if let food = store.food(s.foodID) {
                        Text("\(food.emoji) \(food.name)")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.fodmapGreen.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }
}
