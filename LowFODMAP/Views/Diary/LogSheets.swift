import SwiftData
import SwiftUI

struct LogMealSheet: View {
    @Environment(FoodStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: MealLog?

    @State private var date: Date
    @State private var type: MealType
    @State private var foodIDs: [String]
    @State private var extras: [String]
    @State private var extraDraft = ""
    @State private var note: String
    @State private var showPicker = false

    init(date: Date = .now) {
        existing = nil
        _date = State(initialValue: date)
        _type = State(initialValue: MealType.suggested(for: date))
        _foodIDs = State(initialValue: [])
        _extras = State(initialValue: [])
        _note = State(initialValue: "")
    }

    init(existing: MealLog) {
        self.existing = existing
        _date = State(initialValue: existing.date)
        _type = State(initialValue: existing.mealType)
        _foodIDs = State(initialValue: existing.foodIDs)
        _extras = State(initialValue: existing.extraFoods)
        _note = State(initialValue: existing.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Meal", selection: $type) {
                        ForEach(MealType.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                    }
                    DatePicker("Time", selection: $date, in: ...Date.now.addingTimeInterval(3600))
                }
                Section {
                    ForEach(foodIDs.compactMap { store.food($0) }) { food in
                        FoodRow(food: food)
                    }
                    .onDelete { foodIDs.remove(atOffsets: $0) }
                    ForEach(extras, id: \.self) { e in
                        HStack {
                            Text("✏️")
                            Text(e)
                        }
                    }
                    .onDelete { extras.remove(atOffsets: $0) }
                    Button {
                        showPicker = true
                    } label: {
                        Label("Add from food guide", systemImage: "magnifyingglass")
                    }
                    HStack {
                        TextField("Something else (free text)", text: $extraDraft)
                            .onSubmit(addExtra)
                        if !extraDraft.isEmpty {
                            Button("Add", action: addExtra)
                        }
                    }
                } header: {
                    Text("What did you eat?")
                } footer: {
                    if let worst = foodIDs.compactMap({ store.food($0)?.rating }).max(), worst != .low {
                        Label("Contains \(worst.label.lowercased()) FODMAP foods", systemImage: worst.symbol)
                            .foregroundStyle(worst.color)
                    }
                }
                Section("Note") {
                    TextField("Portion, restaurant, how it was cooked…", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(existing == nil ? "Log food" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(foodIDs.isEmpty && extras.isEmpty && extraDraft.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                FoodPickerSheet(selection: $foodIDs)
            }
        }
    }

    private func addExtra() {
        let t = extraDraft.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        // prefer a proper match from the guide so it counts in insights
        if let match = store.bestMatch(for: t), !foodIDs.contains(match.id) {
            foodIDs.append(match.id)
        } else {
            extras.append(t)
        }
        extraDraft = ""
    }

    private func save() {
        addExtra()
        if let existing {
            existing.date = date
            existing.mealTypeRaw = type.rawValue
            existing.foodIDs = foodIDs
            existing.extraFoods = extras
            existing.note = note
        } else {
            context.insert(MealLog(date: date, mealType: type, foodIDs: foodIDs, extraFoods: extras, note: note))
        }
        dismiss()
    }
}

struct LogSymptomsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: SymptomLog?

    @State private var date: Date
    @State private var bloating: Double
    @State private var pain: Double
    @State private var gas: Double
    @State private var nausea: Double
    @State private var stress: Double
    @State private var stool: Int?
    @State private var note: String

    init(date: Date = .now) {
        existing = nil
        _date = State(initialValue: date)
        _bloating = State(initialValue: 0)
        _pain = State(initialValue: 0)
        _gas = State(initialValue: 0)
        _nausea = State(initialValue: 0)
        _stress = State(initialValue: 0)
        _stool = State(initialValue: nil)
        _note = State(initialValue: "")
    }

    init(existing: SymptomLog) {
        self.existing = existing
        _date = State(initialValue: existing.date)
        _bloating = State(initialValue: Double(existing.bloating))
        _pain = State(initialValue: Double(existing.pain))
        _gas = State(initialValue: Double(existing.gas))
        _nausea = State(initialValue: Double(existing.nausea))
        _stress = State(initialValue: Double(existing.stress))
        _stool = State(initialValue: existing.stoolType)
        _note = State(initialValue: existing.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $date, in: ...Date.now.addingTimeInterval(3600))
                    Button("All good — no symptoms") {
                        bloating = 0; pain = 0; gas = 0; nausea = 0
                    }
                }
                Section("Symptoms (0 = none, 10 = worst)") {
                    slider("Bloating", "🎈", $bloating)
                    slider("Pain / cramps", "⚡️", $pain)
                    slider("Gas / wind", "💨", $gas)
                    slider("Nausea", "🤢", $nausea)
                }
                Section {
                    slider("Stress", "🧠", $stress)
                } footer: {
                    Text("Stress can trigger gut symptoms on its own, so it helps to track it separately.")
                }
                Section("Bowel movement") {
                    Picker("Bristol type", selection: $stool) {
                        Text("None / skip").tag(Int?.none)
                        ForEach(1...7, id: \.self) { t in
                            Text("Type \(t) · \(BristolScale.describe(t))").tag(Int?.some(t))
                        }
                    }
                    if let stool {
                        HStack(spacing: 4) {
                            ForEach(1...7, id: \.self) { t in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(t == stool ? BristolScale.color(t) : Color.secondary.opacity(0.15))
                                    .frame(height: 8)
                            }
                        }
                    }
                }
                Section("Note") {
                    TextField("Anything else? Period, poor sleep, exercise…", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(existing == nil ? "How do you feel?" : "Edit check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
            }
        }
    }

    private func slider(_ label: String, _ emoji: String, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(emoji) \(label)")
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(severityColor(value.wrappedValue))
            }
            Slider(value: value, in: 0...10, step: 1)
                .tint(severityColor(value.wrappedValue))
        }
        .sensoryFeedback(.selection, trigger: value.wrappedValue)
    }

    private func save() {
        let log = existing ?? SymptomLog()
        log.date = date
        log.bloating = Int(bloating)
        log.pain = Int(pain)
        log.gas = Int(gas)
        log.nausea = Int(nausea)
        log.stress = Int(stress)
        log.stoolType = stool
        log.note = note
        if existing == nil { context.insert(log) }
        dismiss()
    }
}
