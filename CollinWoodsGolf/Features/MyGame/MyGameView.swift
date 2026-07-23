import SwiftUI
import Charts

/// Handicap tracking (GHIN), recent rounds, and connections to game-data
/// providers (GHIN, Arccos, UpGame, TheGrint) so the coach can see the whole game.
struct MyGameView: View {
    @Environment(SessionStore.self) private var session

    @State private var handicapHistory: [HandicapEntry] = []
    @State private var rounds: [RoundSummary] = []
    @State private var connections: [IntegrationConnection] = []
    @State private var isLoading = true
    @State private var showGHINEntry = false

    var body: some View {
        NavigationStack {
            ZStack {
                CWTheme.cream.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            handicapCard

                            VStack(alignment: .leading, spacing: 10) {
                                CWSectionHeader(title: "Recent Rounds")
                                if rounds.isEmpty {
                                    CWEmptyState(
                                        icon: "flag",
                                        title: "No rounds yet",
                                        message: "Connect GHIN or a shot-tracking app below and your rounds sync automatically.")
                                } else {
                                    ForEach(rounds) { round in RoundRow(round: round) }
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                CWSectionHeader(title: "Connected Apps")
                                Text("Connected data flows into your coaching plan and the AI caddie's memory.")
                                    .font(CWTheme.body(13))
                                    .foregroundStyle(CWTheme.stone)
                                ForEach(connections) { connection in
                                    IntegrationRow(connection: connection) { connected in
                                        Task { await toggle(connection.provider, connected: connected) }
                                    }
                                }
                            }
                        }
                        .padding(18)
                    }
                }
            }
            .navigationTitle("My Game")
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showGHINEntry) {
                GHINEntrySheet()
                    .presentationDetents([.height(280)])
            }
        }
    }

    private var handicapCard: some View {
        CWCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HANDICAP INDEX")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1.2)
                            .foregroundStyle(CWTheme.stone)
                        Text(currentIndex)
                            .font(CWTheme.display(40))
                            .foregroundStyle(CWTheme.pine)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if let ghin = session.client?.ghinNumber {
                            Text("GHIN #\(ghin)")
                                .font(CWTheme.body(13, weight: .semibold))
                                .foregroundStyle(CWTheme.charcoal)
                        }
                        Button(session.client?.ghinNumber == nil ? "Add GHIN number" : "Edit") {
                            showGHINEntry = true
                        }
                        .font(CWTheme.body(13, weight: .medium))
                        .foregroundStyle(CWTheme.pine)
                    }
                }

                if handicapHistory.count > 1 {
                    Chart(handicapHistory) { entry in
                        LineMark(x: .value("Date", entry.date), y: .value("Index", entry.index))
                            .foregroundStyle(CWTheme.pine)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", entry.date), y: .value("Index", entry.index))
                            .foregroundStyle(CWTheme.gold)
                    }
                    .chartYScale(domain: yDomain)
                    .frame(height: 140)

                    if let trend {
                        Label(trend, systemImage: "arrow.down.right")
                            .font(CWTheme.body(12, weight: .semibold))
                            .foregroundStyle(CWTheme.fairway)
                    }
                }
            }
        }
    }

    private var currentIndex: String {
        handicapHistory.last.map { String(format: "%.1f", $0.index) } ?? "—"
    }

    private var yDomain: ClosedRange<Double> {
        let values = handicapHistory.map(\.index)
        guard let min = values.min(), let max = values.max() else { return 0...20 }
        return (min - 1)...(max + 1)
    }

    private var trend: String? {
        guard let first = handicapHistory.first, let last = handicapHistory.last,
              last.index < first.index else { return nil }
        return String(format: "Down %.1f strokes since %@", first.index - last.index,
                      first.date.formatted(.dateTime.month(.wide)))
    }

    private func load() async {
        do {
            async let history = session.backend.handicapHistory()
            async let recent = session.backend.recentRounds()
            async let integrations = session.backend.integrations()
            handicapHistory = try await history
            rounds = try await recent
            connections = try await integrations
        } catch {
            // leave whatever loaded
        }
        isLoading = false
    }

    private func toggle(_ provider: IntegrationProvider, connected: Bool) async {
        if let updated = try? await session.backend.setIntegration(provider, connected: connected) {
            connections = updated
        }
    }
}

struct RoundRow: View {
    let round: RoundSummary

    var body: some View {
        CWCard(padding: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(round.course)
                        .font(CWTheme.body(15, weight: .semibold))
                        .foregroundStyle(CWTheme.charcoal)
                    Text("\(round.date.formatted(date: .abbreviated, time: .omitted)) · via \(round.source)")
                        .font(CWTheme.body(12))
                        .foregroundStyle(CWTheme.stone)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(round.score)")
                        .font(CWTheme.display(22))
                        .foregroundStyle(CWTheme.pine)
                    Text(round.toPar >= 0 ? "+\(round.toPar)" : "\(round.toPar)")
                        .font(CWTheme.body(12, weight: .semibold))
                        .foregroundStyle(CWTheme.stone)
                }
            }
        }
    }
}

struct IntegrationRow: View {
    let connection: IntegrationConnection
    var onToggle: (Bool) -> Void

    var body: some View {
        CWCard(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: connection.provider.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(connection.isConnected ? CWTheme.pine : CWTheme.stone)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.provider.rawValue)
                        .font(CWTheme.body(15, weight: .semibold))
                        .foregroundStyle(CWTheme.charcoal)
                    Text(statusLine)
                        .font(CWTheme.body(12))
                        .foregroundStyle(CWTheme.stone)
                        .lineLimit(2)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { connection.isConnected }, set: onToggle))
                    .labelsHidden()
                    .tint(CWTheme.pine)
            }
        }
    }

    private var statusLine: String {
        if connection.isConnected {
            var parts: [String] = []
            if let label = connection.accountLabel { parts.append(label) }
            if let synced = connection.lastSyncedAt {
                parts.append("synced \(synced.formatted(.relative(presentation: .named)))")
            }
            return parts.isEmpty ? "Connected" : parts.joined(separator: " · ")
        }
        return connection.provider.subtitle
    }
}

struct GHINEntrySheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var number = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Your GHIN number links your official handicap index and score history to your coaching profile.")
                    .font(CWTheme.body(13))
                    .foregroundStyle(CWTheme.stone)

                TextField("GHIN number", text: $number)
                    .keyboardType(.numberPad)
                    .font(CWTheme.body(20, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(CWTheme.creamCard)
                    .clipShape(RoundedRectangle(cornerRadius: CWTheme.cornerRadius))

                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView().tint(CWTheme.cream) } else { Text("Save") }
                }
                .buttonStyle(CWPrimaryButtonStyle())
                .disabled(number.isEmpty || isSaving)

                Spacer()
            }
            .padding(20)
            .background(CWTheme.cream)
            .navigationTitle("GHIN Number")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { number = session.client?.ghinNumber ?? "" }
        }
    }

    private func save() async {
        isSaving = true
        if let updated = try? await session.backend.updateGHIN(number: number) {
            session.update(client: updated)
        }
        isSaving = false
        dismiss()
    }
}

#Preview {
    MyGameView().environment(previewSession())
}
