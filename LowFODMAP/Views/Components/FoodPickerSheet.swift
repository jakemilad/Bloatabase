import SwiftUI

/// Multi-select food search used by the meal checker and diary.
struct FoodPickerSheet: View {
    @Environment(FoodStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var title = "Add foods"
    @Binding var selection: [String]

    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if !selection.isEmpty && query.isEmpty {
                    Section("Selected") {
                        ForEach(selection.compactMap { store.food($0) }) { food in
                            row(food)
                        }
                    }
                }
                Section(query.isEmpty ? "Recent" : "Results") {
                    let foods = query.isEmpty ? store.recents : Array(store.search(query).prefix(60))
                    if foods.isEmpty {
                        Text(query.isEmpty ? "Search for a food to add it." : "No matches.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(foods) { food in
                        row(food)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
            .autocorrectionDisabled()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func row(_ food: Food) -> some View {
        let isSelected = selection.contains(food.id)
        return Button {
            if isSelected { selection.removeAll { $0 == food.id } } else { selection.append(food.id) }
        } label: {
            HStack {
                FoodRow(food: food)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
