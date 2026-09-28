import SwiftUI

struct Guide: Identifiable {
    struct Section: Identifiable {
        let heading: String
        let body: String
        var id: String { heading }
    }

    let id: String
    let emoji: String
    let title: String
    let subtitle: String
    let sections: [Section]

    static let all: [Guide] = [
        Guide(id: "what", emoji: "🤔", title: "What are FODMAPs?", subtitle: "The science in two minutes", sections: [
            .init(heading: "The acronym", body: "Fermentable Oligo-, Di-, Mono-saccharides And Polyols. They're short-chain carbs that are poorly absorbed in the small intestine."),
            .init(heading: "Why they cause symptoms", body: "FODMAPs draw water into the bowel and are fermented by gut bacteria, producing gas. In people with IBS the gut is extra sensitive to this stretching, which causes bloating, pain, wind and changes in bowel habits."),
            .init(heading: "Not all bad", body: "FODMAPs feed good gut bacteria. The goal isn't to cut them forever — it's to find which ones and how much *you* can handle."),
        ]),
        Guide(id: "steps", emoji: "🪜", title: "The 3-step diet", subtitle: "Eliminate, reintroduce, personalise", sections: [
            .init(heading: "Step 1 · Low FODMAP (2–6 weeks)", body: "Swap high FODMAP foods for low FODMAP alternatives. This is a short-term reset, not a forever diet. Most people feel better within a few weeks."),
            .init(heading: "Step 2 · Reintroduction (6–8 weeks)", body: "Test each FODMAP group one at a time, over 3 days with increasing doses, then a 3-day washout. Keep your base diet low FODMAP while you test."),
            .init(heading: "Step 3 · Personalisation (long term)", body: "Bring back everything you tolerate and only limit your triggers. A varied diet is better for your gut microbiome and much easier to live with."),
        ]),
        Guide(id: "traffic", emoji: "🚦", title: "Reading the traffic lights", subtitle: "Serving size is everything", sections: [
            .init(heading: "🟢 Low", body: "Fine to eat in normal servings. Some green foods have a limit — e.g. 1 slice of wheat bread is low, but 3 slices isn't."),
            .init(heading: "🟠 Moderate", body: "OK in the listed serving size. Stick to one moderate food per group per meal to avoid stacking."),
            .init(heading: "🔴 High", body: "Avoid during step 1. These are the foods you'll test in step 2 — many people find they tolerate some of them."),
            .init(heading: "Stacking", body: "Two moderate foods from the same FODMAP group (say, a handful of almonds and some sweet corn) can add up to a high serve. The Check tab warns you about this."),
        ]),
        Guide(id: "hidden", emoji: "🕵️", title: "Hidden FODMAPs", subtitle: "What to watch for on labels", sections: [
            .init(heading: "Onion & garlic", body: "Hide in stock, gravy, spice mixes, sauces, sausages, marinades and anything labelled “natural flavours” or “seasoning”. Garlic-infused oil is a safe swap: fructans don't dissolve in oil."),
            .init(heading: "Added fibre", body: "Inulin, chicory root, FOS and oligofructose are added to “high fibre” breads, bars and yoghurts. All are fructans."),
            .init(heading: "Sweeteners", body: "Honey, agave, high-fructose corn syrup, fruit juice concentrate, and polyols ending in “-ol” (sorbitol, mannitol, xylitol, maltitol, isomalt) — common in sugar-free gum and mints."),
            .init(heading: "Dairy", body: "Milk solids, milk powder and whey add lactose. Butter, hard cheese and lactose-free products are fine."),
        ]),
        Guide(id: "eating-out", emoji: "🍽️", title: "Eating out", subtitle: "Stay on track at restaurants", sections: [
            .init(heading: "Safe bets", body: "Grilled meat or fish with rice or potato and plain vegetables. Sushi and sashimi (go easy on sauces). Steak and chips. Plain omelettes."),
            .init(heading: "Just ask", body: "Ask for no onion or garlic, sauce on the side, and dressing swapped for olive oil and lemon. Most kitchens are happy to help."),
            .init(heading: "Cuisine tips", body: "Thai and Vietnamese: rice noodles and rice paper are great, but check for garlic. Italian: gluten-free pasta with a simple tomato and basil sauce (no garlic). Mexican: corn tortillas, but beans and salsa are usually high."),
        ]),
        Guide(id: "swaps", emoji: "🔄", title: "Easy swaps", subtitle: "Keep the flavour, lose the FODMAPs", sections: [
            .init(heading: "Onion & garlic", body: "Garlic-infused oil, green tops of spring onions and leeks, chives, asafoetida (a pinch)."),
            .init(heading: "Bread & pasta", body: "Sourdough spelt, gluten-free bread, rice, rice noodles, quinoa, polenta, potato, oats (½ cup)."),
            .init(heading: "Milk", body: "Lactose-free milk, almond milk, rice milk, or soy milk made from soy protein. Hard cheeses like cheddar, parmesan and swiss."),
            .init(heading: "Sweet stuff", body: "Maple syrup, rice malt syrup, table sugar, dark chocolate (30 g). Swap apples and pears for oranges, kiwis, grapes, pineapple and strawberries."),
            .init(heading: "Snacks", body: "Peanuts, macadamias, walnuts, pumpkin seeds, rice cakes with peanut butter, popcorn, lactose-free yoghurt."),
        ]),
    ]
}

struct GuideView: View {
    let guide: Guide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 26).fill(AppStyle.pine)
                    PlateMark(symbol: "book.closed", size: 145, tint: .white)
                        .opacity(0.28)
                        .offset(x: 220, y: 10)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(guide.title)
                            .font(AppStyle.display(29))
                            .foregroundStyle(.white)
                        Text(guide.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppStyle.mist)
                    }
                    .padding(22)
                }
                .frame(height: 155)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                ForEach(guide.sections) { s in
                    Card {
                        Text(s.heading).font(AppStyle.display(22)).foregroundStyle(AppStyle.ink)
                        Text(.init(s.body)).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if guide.id == "what" {
                    Card {
                        Text("The six groups").font(.headline)
                        ForEach(FodmapGroup.allCases) { g in
                            HStack(alignment: .top, spacing: 10) {
                                Text(g.emoji).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(g.name) · \(g.family)").font(.subheadline.weight(.semibold))
                                    Text(g.summary).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.pageBackground)
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @AppStorage("dietPhase") private var phaseRaw = DietPhase.elimination.rawValue
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                slide(symbol: "leaf", title: "Eat with confidence.",
                      text: "Search foods in seconds. Know the rating, the serving, and the reason behind it.")
                    .tag(0)
                slide(symbol: "viewfinder", title: "See the whole picture.",
                      text: "Build a meal to catch FODMAP stacking, or scan an ingredient list to spot hidden onion, garlic, inulin and more.")
                    .tag(1)
                slide(symbol: "waveform.path.ecg", title: "Learn what works for you.",
                      text: "Log meals and symptoms, then work through guided reintroduction challenges to build your personal tolerance profile.")
                    .tag(2)
                phasePicker.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < 3 { withAnimation { page += 1 } } else { onFinish() }
            } label: {
                Text(page < 3 ? "Next" : "Get started")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 51)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppStyle.pine)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(Color.pageBackground)
    }

    private func slide(symbol: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("fodmap.")
                .font(AppStyle.display(27))
                .tracking(-1.3)
                .foregroundStyle(AppStyle.pine)
                .padding(.top, 23)
            Spacer(minLength: 25)
            PlateMark(symbol: symbol, size: 245, tint: AppStyle.pine)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 32)
            Text(title)
                .font(AppStyle.display(42))
                .tracking(-1.5)
                .foregroundStyle(AppStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 13)
            Text(text)
                .font(.body)
                .foregroundStyle(AppStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 55)
        }
        .padding(.horizontal, 30)
    }

    private var phasePicker: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Where are you now?")
                .font(AppStyle.display(36))
                .foregroundStyle(AppStyle.ink)
            Text("You can change this at any time.").foregroundStyle(AppStyle.muted)
            VStack(spacing: 10) {
                ForEach(DietPhase.allCases) { p in
                    Button {
                        phaseRaw = p.rawValue
                    } label: {
                        HStack(spacing: 14) {
                            Text(p.emoji).font(.title)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.title).font(.headline)
                                Text(p.guidance).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: phaseRaw == p.rawValue ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(phaseRaw == p.rawValue ? Color.accentColor : .secondary)
                        }
                        .padding(14)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(phaseRaw == p.rawValue ? AppStyle.jade : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            Spacer()
        }
        .padding(24)
    }
}
