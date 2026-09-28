import SwiftData
import SwiftUI

struct DiaryView: View {
    @Environment(FoodStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(sort: \MealLog.date, order: .reverse) private var meals: [MealLog]
    @Query(sort: \SymptomLog.date, order: .reverse) private var symptoms: [SymptomLog]

    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var showMealSheet = false
    @State private var showSymptomSheet = false
    @State private var editingMeal: MealLog?
    @State private var editingSymptom: SymptomLog?
    @State private var showInsights = UserDefaults.standard.string(forKey: "startTab") == "insights"

    private enum Entry: Identifiable {
        case meal(MealLog), symptom(SymptomLog)
        var id: PersistentIdentifier {
            switch self {
            case .meal(let m): m.persistentModelID
            case .symptom(let s): s.persistentModelID
            }
        }
        var date: Date {
            switch self {
            case .meal(let m): m.date
            case .symptom(let s): s.date
            }
        }
    }

    private var entries: [Entry] {
        let cal = Calendar.current
        let m = meals.filter { cal.isDate($0.date, inSameDayAs: day) }.map(Entry.meal)
        let s = symptoms.filter { cal.isDate($0.date, inSameDayAs: day) }.map(Entry.symptom)
        return (m + s).sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PageIntro(title: "Your food diary", subtitle: "The little details reveal the bigger picture.")
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                WeekStrip(selected: $day, meals: meals, symptoms: symptoms)
                    .padding(.bottom, 16)
                HStack(spacing: 10) {
                    quickButton("Log food", symbol: "fork.knife", filled: true) { showMealSheet = true }
                    quickButton("How I feel", symbol: "heart.text.square", filled: false) { showSymptomSheet = true }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                List {
                    Section {
                    if entries.isEmpty {
                        EmptyStateView(emoji: "📓", title: "Nothing logged",
                                       message: "Log meals and symptoms to spot your triggers. Aim for a quick check-in after each meal.")
                    }
                    ForEach(entries) { entry in
                        switch entry {
                        case .meal(let m):
                            Button { editingMeal = m } label: { MealEntryRow(meal: m) }
                                .buttonStyle(.plain)
                                .swipeActions { Button("Delete", role: .destructive) { context.delete(m) } }
                        case .symptom(let s):
                            Button { editingSymptom = s } label: { SymptomEntryRow(log: s) }
                                .buttonStyle(.plain)
                                .swipeActions { Button("Delete", role: .destructive) { context.delete(s) } }
                        }
                    }
                    .listRowBackground(AppStyle.paper)
                    .listRowSeparator(.hidden)
                    } header: {
                        Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppStyle.muted)
                            .textCase(nil)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(AppStyle.canvas)
            .navigationTitle(" ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: DiaryExport(meals: meals, symptoms: symptoms, store: store),
                              preview: SharePreview("FODMAP diary", image: Image(systemName: "tablecells"))) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(meals.isEmpty && symptoms.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInsights = true
                    } label: {
                        Label("Insights", systemImage: "chart.xyaxis.line")
                    }
                }
            }
            .navigationDestination(isPresented: $showInsights) { InsightsView() }
            .sheet(isPresented: $showMealSheet) { LogMealSheet(date: defaultTime) }
            .sheet(isPresented: $showSymptomSheet) { LogSymptomsSheet(date: defaultTime) }
            .sheet(item: $editingMeal) { LogMealSheet(existing: $0) }
            .sheet(item: $editingSymptom) { LogSymptomsSheet(existing: $0) }
        }
    }

    /// Now if viewing today, otherwise midday on the chosen day.
    private var defaultTime: Date {
        Calendar.current.isDateInToday(day) ? .now : Calendar.current.date(byAdding: .hour, value: 12, to: day)!
    }

    private func quickButton(_ title: String, symbol: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 15) {
                Image(systemName: symbol).font(.title3.weight(.medium))
                Text(title).font(.subheadline.weight(.semibold))
            }
                .frame(maxWidth: .infinity)
                .frame(height: 94, alignment: .leading)
                .padding(.horizontal, 18)
                .foregroundStyle(filled ? Color.white : AppStyle.pine)
                .background(filled ? AppStyle.pine : AppStyle.mist, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WeekStrip: View {
    @Binding var selected: Date
    let meals: [MealLog]
    let symptoms: [SymptomLog]

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days = (0..<14).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { d in
                        let isSel = cal.isDate(d, inSameDayAs: selected)
                        let hasMeals = meals.contains { cal.isDate($0.date, inSameDayAs: d) }
                        let worst = symptoms.filter { cal.isDate($0.date, inSameDayAs: d) }.map(\.severity).max()
                        Button { selected = d } label: {
                            VStack(spacing: 4) {
                                Text(d.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(isSel ? .white.opacity(0.8) : .secondary)
                                Text(d.formatted(.dateTime.day())).font(.headline.monospacedDigit())
                                HStack(spacing: 2) {
                                    Circle().fill(hasMeals ? Color.accentColor : .clear).frame(width: 5, height: 5)
                                    Circle().fill(worst.map { severityColor($0) } ?? .clear).frame(width: 5, height: 5)
                                }
                            }
                            .frame(width: 44, height: 64)
                            .foregroundStyle(isSel ? .white : .primary)
                            .background(isSel ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.cardBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(d)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear { proxy.scrollTo(today, anchor: .trailing) }
        }
    }
}

func severityColor(_ s: Double) -> Color {
    s < 3 ? .fodmapGreen : (s < 6 ? .fodmapAmber : .fodmapRed)
}

struct MealEntryRow: View {
    @Environment(FoodStore.self) private var store
    let meal: MealLog

    var body: some View {
        let foods = meal.foodIDs.compactMap { store.food($0) }
        let worst = foods.map(\.rating).max()
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: meal.mealType.symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(meal.mealType.label).font(.subheadline.weight(.semibold))
                    Text(meal.date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if let worst { RatingPill(rating: worst, compact: true) }
                }
                FlowLayout(spacing: 6) {
                    ForEach(foods) { f in
                        HStack(spacing: 4) {
                            Text(f.emoji)
                            Text(f.name).lineLimit(1)
                            RatingDot(rating: f.rating, size: 6)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                    ForEach(meal.extraFoods, id: \.self) { name in
                        Text(name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                }
                if !meal.note.isEmpty {
                    Text(meal.note).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct SymptomEntryRow: View {
    let log: SymptomLog

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.title3)
                .foregroundStyle(severityColor(log.severity))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Check-in").font(.subheadline.weight(.semibold))
                    Text(log.date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f / 10", log.severity))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(severityColor(log.severity))
                }
                HStack(spacing: 10) {
                    metric("Bloat", log.bloating)
                    metric("Pain", log.pain)
                    metric("Gas", log.gas)
                    metric("Nausea", log.nausea)
                    metric("Stress", log.stress)
                }
                if let stool = log.stoolType {
                    Text("Stool: type \(stool) · \(BristolScale.describe(stool))").font(.caption).foregroundStyle(.secondary)
                }
                if !log.note.isEmpty {
                    Text(log.note).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func metric(_ label: String, _ v: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(v)").font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(severityColor(Double(v)))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

enum BristolScale {
    static let descriptions = [
        1: "Separate hard lumps",
        2: "Lumpy and sausage-like",
        3: "Sausage with cracks",
        4: "Smooth and soft",
        5: "Soft blobs",
        6: "Mushy, ragged edges",
        7: "Entirely liquid",
    ]

    static func describe(_ t: Int) -> String { descriptions[t] ?? "" }

    static func color(_ t: Int) -> Color {
        switch t {
        case 3, 4: .fodmapGreen
        case 2, 5: .fodmapAmber
        default: .fodmapRed
        }
    }
}

/// CSV export to share with a dietitian.
struct DiaryExport: Transferable {
    /// Built eagerly on the main actor so no SwiftData models cross threads during export.
    let csv: String

    init(meals: [MealLog], symptoms: [SymptomLog], store: FoodStore) {
        csv = Self.makeCSV(meals: meals, symptoms: symptoms, store: store)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("fodmap-diary.csv")
            try export.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }

    private static func makeCSV(meals: [MealLog], symptoms: [SymptomLog], store: FoodStore) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        func esc(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var rows = ["date,type,meal,foods,fodmap,bloating,pain,gas,nausea,stress,stool,note"]
        for m in meals {
            let foods = m.foodIDs.compactMap { store.food($0) }
            let names = (foods.map(\.name) + m.extraFoods).joined(separator: "; ")
            let ratings = foods.map { "\($0.name): \($0.rating.label)" }.joined(separator: "; ")
            rows.append([fmt.string(from: m.date), "meal", m.mealType.label, esc(names), esc(ratings), "", "", "", "", "", "", esc(m.note)].joined(separator: ","))
        }
        for s in symptoms {
            rows.append([fmt.string(from: s.date), "symptoms", "", "", "", "\(s.bloating)", "\(s.pain)", "\(s.gas)", "\(s.nausea)", "\(s.stress)", s.stoolType.map(String.init) ?? "", esc(s.note)].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }
}
