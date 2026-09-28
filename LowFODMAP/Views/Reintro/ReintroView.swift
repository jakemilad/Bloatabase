import SwiftData
import SwiftUI
import UserNotifications

struct ReintroView: View {
    @Query(sort: \ChallengeRecord.startDate, order: .reverse) private var records: [ChallengeRecord]
    @AppStorage("dietPhase") private var phaseRaw = DietPhase.elimination.rawValue

    private var active: ChallengeRecord? { records.first { !$0.finished && !$0.shouldStop } }
    private var tolerance: ToleranceProfile { ToleranceProfile(records: records) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageIntro(title: "Find your freedom", subtitle: "Test one group at a time. Keep what works for you.")
                        .padding(.bottom, 3)
                    if phaseRaw == DietPhase.elimination.rawValue && records.isEmpty {
                        intro
                    }
                    if let active, let challenge = Challenge.find(active.challengeID) {
                        NavigationLink(value: challenge) {
                            ActiveChallengeCard(record: active, challenge: challenge)
                        }
                        .buttonStyle(.plain)
                    } else if let washout = washoutRemaining {
                        washoutCard(days: washout)
                    }
                    profile
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Challenges")
                        ForEach(Challenge.all) { c in
                            NavigationLink(value: c) {
                                ChallengeRow(challenge: c, record: latest(for: c))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.pageBackground)
            .navigationTitle(" ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Challenge.self) { ChallengeDetailView(challenge: $0) }
        }
    }

    private func latest(for c: Challenge) -> ChallengeRecord? {
        records.first { $0.challengeID == c.id }
    }

    /// Days left in the washout after the most recently finished challenge.
    private var washoutRemaining: Int? {
        guard let last = records.compactMap(\.finishedAt).max() else { return nil }
        let end = Calendar.current.date(byAdding: .day, value: Challenge.washoutDays, to: last)!
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: end)).day ?? 0
        return days > 0 ? days : nil
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 31, weight: .ultraLight))
                .foregroundStyle(AppStyle.mist)
            Text("Ready to explore?")
                .font(AppStyle.display(28))
                .foregroundStyle(.white)
            Text("After 2–6 weeks of low FODMAP eating, start testing one FODMAP group at a time. Each challenge takes 3 days with increasing doses, followed by a 3-day break. You'll finish with your personal tolerance profile.")
                .font(.subheadline)
                .foregroundStyle(AppStyle.mist)
            Button("Start reintroduction") {
                phaseRaw = DietPhase.reintroduction.rawValue
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppStyle.pine)
            .padding(.horizontal, 17)
            .padding(.vertical, 12)
            .background(AppStyle.mist, in: Capsule())
        }
        .padding(23)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.pine, in: RoundedRectangle(cornerRadius: 26))
    }

    private func washoutCard(days: Int) -> some View {
        Card {
            HStack(spacing: 14) {
                Text("⏸️").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Washout · \(days) day\(days == 1 ? "" : "s") to go").font(.headline)
                    Text("Go back to strict low FODMAP eating so your gut settles before the next challenge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var profile: some View {
        Card {
            Text("My tolerance profile").font(AppStyle.display(23)).foregroundStyle(AppStyle.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(FodmapGroup.allCases) { g in
                    let status = tolerance.status(for: g)
                    let color = status?.rating?.color ?? .secondary
                    VStack(spacing: 4) {
                        Text(g.emoji).font(.title2)
                        Text(g.name).font(.caption.weight(.semibold))
                        Text(status?.label ?? "Not tested")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(color)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(color.opacity(status == nil ? 0.06 : 0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            if !tolerance.isEmpty {
                Text("Food ratings across the app are personalised using these results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ActiveChallengeCard: View {
    let record: ChallengeRecord
    let challenge: Challenge

    var body: some View {
        let day = record.currentDayIndex ?? 2
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("In progress").font(.caption.weight(.bold)).opacity(0.8)
                Spacer()
                Text("Day \(day + 1) of 3").font(.caption.weight(.bold))
            }
            HStack(spacing: 14) {
                Text(challenge.emoji).font(.system(size: 44))
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title).font(.title3.weight(.bold))
                    Text("Today: \(challenge.doses[day]) \(challenge.food.lowercased())")
                        .font(.subheadline.weight(.medium))
                }
            }
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i < record.loggedDays ? Color.white : Color.white.opacity(0.3))
                        .frame(height: 6)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(AppStyle.pine, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct ChallengeRow: View {
    let challenge: Challenge
    let record: ChallengeRecord?

    var body: some View {
        let status = record?.status ?? .notStarted
        HStack(spacing: 12) {
            EmojiTile(emoji: challenge.emoji, rating: status.rating, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title).font(.subheadline.weight(.semibold))
                Text("\(challenge.food) · \(challenge.doses.first ?? "") → \(challenge.doses.last ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.rating?.color ?? .secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ChallengeDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ChallengeRecord.startDate, order: .reverse) private var records: [ChallengeRecord]
    @AppStorage("challengeReminders") private var remindersOn = true

    let challenge: Challenge

    @State private var confirmRestart = false

    private var record: ChallengeRecord? { records.first { $0.challengeID == challenge.id } }
    private var otherActive: ChallengeRecord? {
        records.first { $0.challengeID != challenge.id && !$0.finished && !$0.shouldStop }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let record {
                    doses(record)
                    outcome(record)
                } else {
                    startCard
                }
                howTo
            }
            .padding(20)
        }
        .background(Color.pageBackground)
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if record != nil {
                Menu {
                    Button("Restart challenge", systemImage: "arrow.counterclockwise") { confirmRestart = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Restart this challenge? Your logged results will be cleared.", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Restart", role: .destructive) {
                if let record { context.delete(record) }
                ChallengeReminders.cancel(challenge)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(challenge.emoji).font(.system(size: 54))
            VStack(alignment: .leading, spacing: 4) {
                Text("Testing \(challenge.group.name)").font(.headline)
                Text("with \(challenge.food.lowercased())").font(.subheadline).foregroundStyle(.secondary)
                Text(challenge.tip).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var startCard: some View {
        Card {
            if let otherActive, let other = Challenge.find(otherActive.challengeID) {
                Label("You're still testing \(other.title). Finish that first so results don't overlap.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.fodmapAmber)
            }
            Text("Over 3 days, eat an increasing amount of \(challenge.food.lowercased()) once a day and record how you feel. Keep everything else low FODMAP.")
                .font(.subheadline)
            Toggle("Daily reminder at 9am", isOn: $remindersOn)
                .font(.subheadline)
            Button {
                let r = ChallengeRecord(challengeID: challenge.id, group: challenge.group)
                context.insert(r)
                if remindersOn { ChallengeReminders.schedule(challenge, start: r.startDate) }
            } label: {
                Label("Start today", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(otherActive != nil)
        }
    }

    private func doses(_ record: ChallengeRecord) -> some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                DoseCard(
                    day: i,
                    dose: challenge.doses[i],
                    food: challenge.food,
                    date: Calendar.current.date(byAdding: .day, value: i, to: record.startDate)!,
                    reaction: record.reactions[i] >= 0 ? ReactionLevel(rawValue: record.reactions[i]) : nil,
                    isCurrent: record.currentDayIndex == i && !record.shouldStop && !record.finished,
                    isLocked: (record.currentDayIndex ?? 3) < i || (record.shouldStop && record.reactions[i] < 0)
                ) { level in
                    var r = record.reactions
                    r[i] = level.rawValue
                    record.reactions = r
                    if level.rawValue >= 2 || i == 2 {
                        record.finished = true
                        record.finishedAt = .now
                        ChallengeReminders.cancel(challenge)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func outcome(_ record: ChallengeRecord) -> some View {
        if record.finished || record.shouldStop {
            let status = record.status
            let rating = status.rating ?? .low
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: rating.symbol).font(.title2)
                    Text("Result: \(status.label)").font(.headline)
                }
                Text(outcomeMessage(record)).font(.subheadline)
                Text("Now take a \(Challenge.washoutDays)-day washout of strict low FODMAP eating before your next challenge.")
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rating.color.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func outcomeMessage(_ record: ChallengeRecord) -> String {
        switch record.status {
        case .tolerated:
            return "You handled the full dose of \(challenge.food.lowercased()) with no real symptoms. \(challenge.group.name) is probably not a trigger for you."
        case .partlyTolerated:
            let okDay = (record.reactions.lastIndex(where: { $0 >= 0 && $0 <= 1 }) ?? 0)
            return "You're OK with about \(challenge.doses[okDay]) — larger amounts caused symptoms. Keep \(challenge.group.name.lowercased()) portions small."
        case .notTolerated:
            return "Even the smallest dose caused symptoms. \(challenge.group.name) looks like a trigger for you — you can retest in a few months."
        default:
            return ""
        }
    }

    private var howTo: some View {
        Card {
            Label("How it works", systemImage: "info.circle.fill").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Eat the dose for the day, ideally with a low FODMAP meal.")
                Text("2. Log how you feel later that day or the next morning.")
                Text("3. If you get moderate or severe symptoms, stop — that's your answer.")
                Text("4. Mild symptoms? You can keep going, but don't go beyond what's comfortable.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

struct DoseCard: View {
    let day: Int
    let dose: String
    let food: String
    let date: Date
    let reaction: ReactionLevel?
    let isCurrent: Bool
    let isLocked: Bool
    let onLog: (ReactionLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(day + 1) · \(date.formatted(.dateTime.weekday(.abbreviated).day().month()))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(dose) \(food.lowercased())").font(.headline)
                }
                Spacer()
                if let reaction {
                    Text("\(reaction.emoji) \(reaction.label)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(reactionColor(reaction).opacity(0.15), in: Capsule())
                } else if isLocked {
                    Image(systemName: "lock.fill").foregroundStyle(.tertiary)
                }
            }
            if isCurrent {
                Text("How did you feel after this dose?").font(.subheadline)
                HStack(spacing: 6) {
                    ForEach(ReactionLevel.allCases) { level in
                        Button {
                            onLog(level)
                        } label: {
                            VStack(spacing: 2) {
                                Text(level.emoji).font(.title3)
                                Text(level.label).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(reactionColor(level).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isCurrent ? Color.accentColor : .clear, lineWidth: 2))
        .opacity(isLocked ? 0.55 : 1)
    }

    private func reactionColor(_ r: ReactionLevel) -> Color {
        switch r {
        case .none: .fodmapGreen
        case .mild: .fodmapGreen.opacity(0.7)
        case .moderate: .fodmapAmber
        case .severe: .fodmapRed
        }
    }
}

enum ChallengeReminders {
    static func schedule(_ c: Challenge, start: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let cal = Calendar.current
            for i in 0..<3 {
                guard let day = cal.date(byAdding: .day, value: i, to: start) else { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: day)
                comps.hour = 9
                let fire = cal.date(from: comps) ?? day
                // Day 1 reminder is skipped if it's already past 9am
                if fire < .now { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(c.emoji) \(c.title) · Day \(i + 1)"
                content.body = "Today's dose: \(c.doses[i]) \(c.food.lowercased()). Log how you feel afterwards."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "\(c.id)-\(i)", content: content, trigger: trigger))
            }
        }
    }

    static func cancel(_ c: Challenge) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (0..<3).map { "\(c.id)-\($0)" })
    }
}
