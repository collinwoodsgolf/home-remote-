import SwiftUI

/// Two threads: direct messages with Coach Woods, and the AI caddie that
/// remembers the student's game (memory served by the backend).
struct ChatHubView: View {
    @State private var channel: ChatChannel = .coach

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Channel", selection: $channel) {
                    Text("Coach Woods").tag(ChatChannel.coach)
                    Text("AI Caddie").tag(ChatChannel.caddie)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(CWTheme.cream)

                ChatThreadView(channel: channel)
                    .id(channel)   // fresh state per thread
            }
            .background(CWTheme.cream)
            .navigationTitle(channel == .coach ? "Coach Woods" : "AI Caddie")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ChatThreadView: View {
    @Environment(SessionStore.self) private var session
    let channel: ChatChannel

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var showMemory = false

    var body: some View {
        VStack(spacing: 0) {
            if channel == .caddie {
                Button { showMemory = true } label: {
                    Label("What the caddie knows about your game", systemImage: "brain")
                        .font(CWTheme.body(13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(CWTheme.pine.opacity(0.08))
                        .foregroundStyle(CWTheme.pine)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if isLoading {
                            ProgressView().padding(.top, 40)
                        }
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if isSending && channel == .caddie {
                            HStack {
                                ProgressView()
                                Text("Thinking…")
                                    .font(CWTheme.body(13))
                                    .foregroundStyle(CWTheme.stone)
                                Spacer()
                            }
                            .padding(.leading, 8)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(
                    channel == .coach ? "Message Coach Woods…" : "Ask about your game…",
                    text: $draft, axis: .vertical
                )
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(CWTheme.creamCard)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(draft.isEmpty ? CWTheme.stone.opacity(0.4) : CWTheme.pine)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(CWTheme.cream)
        }
        .task { await load() }
        .sheet(isPresented: $showMemory) { GameMemorySheet() }
    }

    private func load() async {
        messages = (try? await session.backend.messages(in: channel)) ?? []
        isLoading = false
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        isSending = true
        if let updated = try? await session.backend.send(text, in: channel) {
            messages = updated
        }
        isSending = false
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromClient { Spacer(minLength: 48) }
            VStack(alignment: message.isFromClient ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(CWTheme.body(15))
                    .foregroundStyle(message.isFromClient ? CWTheme.cream : CWTheme.charcoal)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isFromClient ? AnyShapeStyle(CWTheme.pine) : AnyShapeStyle(CWTheme.creamCard))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(message.sentAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(CWTheme.body(10))
                    .foregroundStyle(CWTheme.stone)
            }
            if !message.isFromClient { Spacer(minLength: 48) }
        }
    }
}

struct GameMemorySheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var facts: [GameMemoryFact] = []

    var body: some View {
        NavigationStack {
            ZStack {
                CWTheme.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The caddie builds this profile from your lessons, rounds, and conversations, and uses it in every answer.")
                            .font(CWTheme.body(13))
                            .foregroundStyle(CWTheme.stone)

                        ForEach(facts) { fact in
                            CWCard(padding: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fact.category.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .kerning(1)
                                        .foregroundStyle(CWTheme.gold)
                                    Text(fact.fact)
                                        .font(CWTheme.body(14))
                                        .foregroundStyle(CWTheme.charcoal)
                                    Text(fact.learnedAt, format: .dateTime.month().day().year())
                                        .font(CWTheme.body(11))
                                        .foregroundStyle(CWTheme.stone)
                                }
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Game Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task {
                facts = (try? await session.backend.gameMemory()) ?? []
            }
        }
    }
}

#Preview {
    ChatHubView().environment(previewSession())
}
