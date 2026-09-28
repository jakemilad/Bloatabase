import SwiftData
import SwiftUI

@main
struct LowFODMAPApp: App {
    @State private var store = FoodStore()
    @State private var meal = MealBuilder()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(meal)
        }
        .modelContainer(for: [FoodPreference.self, ShoppingItem.self, MealLog.self, SymptomLog.self, ChallengeRecord.self])
    }
}

enum DietPhase: String, CaseIterable, Identifiable {
    case elimination, reintroduction, personalisation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elimination: "Step 1 · Low FODMAP"
        case .reintroduction: "Step 2 · Reintroduction"
        case .personalisation: "Step 3 · Personalisation"
        }
    }

    var shortTitle: String { rawValue.capitalized }

    var guidance: String {
        switch self {
        case .elimination: "Stick to green foods for 2–6 weeks and log how you feel. Most people notice a difference within a few weeks."
        case .reintroduction: "Test one FODMAP group at a time over 3 days, with a 3-day break in between. Keep your base diet low FODMAP."
        case .personalisation: "Bring back the foods you tolerate and only limit your personal triggers. Variety keeps your gut bugs happy."
        }
    }

    var emoji: String {
        switch self {
        case .elimination: "🌱"
        case .reintroduction: "🧪"
        case .personalisation: "🎯"
        }
    }
}

/// Foods queued up in the "Check a meal" builder; shared so any screen can add to it.
@Observable
final class MealBuilder {
    var foodIDs: [String] = []

    func add(_ food: Food) {
        if !foodIDs.contains(food.id) { foodIDs.append(food.id) }
    }

    func remove(_ id: String) { foodIDs.removeAll { $0 == id } }

    func contains(_ food: Food) -> Bool { foodIDs.contains(food.id) }
}

enum AppTab: Hashable {
    case foods, check, diary, reintro, more
}

struct RootView: View {
    @State private var tab: AppTab = DebugLaunch.initialTab
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    #if DEBUG
    @Environment(\.modelContext) private var context
    @Environment(FoodStore.self) private var store
    @Environment(MealBuilder.self) private var meal
    #endif

    var body: some View {
        TabView(selection: $tab) {
            FoodsView()
                .tabItem { Label("Foods", systemImage: "magnifyingglass") }
                .tag(AppTab.foods)
            CheckView()
                .tabItem { Label("Check", systemImage: "checklist.checked") }
                .tag(AppTab.check)
            DiaryView()
                .tabItem { Label("Diary", systemImage: "book.closed.fill") }
                .tag(AppTab.diary)
            ReintroView()
                .tabItem { Label("Reintroduce", systemImage: "flask.fill") }
                .tag(AppTab.reintro)
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(AppTab.more)
        }
        .tint(AppStyle.pine)
        .toolbarBackground(AppStyle.paper, for: .tabBar)
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView { hasOnboarded = true }
        }
        #if DEBUG
        .task { DebugLaunch.apply(context: context, store: store, meal: meal) }
        #endif
    }
}
