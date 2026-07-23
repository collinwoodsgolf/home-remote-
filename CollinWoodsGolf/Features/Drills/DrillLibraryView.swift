import SwiftUI
import AVKit

/// Drill video library, grouped by category. Content is served by the backend
/// so Coach Woods can publish new drills without an app update.
struct DrillLibraryView: View {
    @Environment(SessionStore.self) private var session

    @State private var drills: [Drill] = []
    @State private var isLoading = true
    @State private var selectedCategory: String?

    private var categories: [String] {
        var seen = [String]()
        for drill in drills where !seen.contains(drill.category) {
            seen.append(drill.category)
        }
        return seen
    }

    private var filtered: [Drill] {
        guard let selectedCategory else { return drills }
        return drills.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CWTheme.cream.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if drills.isEmpty {
                    CWEmptyState(
                        icon: "figure.golf",
                        title: "Drills coming soon",
                        message: "Coach Woods is building out the drill video library. New content appears here automatically.")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    categoryChip(nil, label: "All")
                                    ForEach(categories, id: \.self) { category in
                                        categoryChip(category, label: category)
                                    }
                                }
                                .padding(.horizontal, 18)
                            }

                            LazyVStack(spacing: 12) {
                                ForEach(filtered) { drill in
                                    DrillCard(drill: drill)
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Drill Library")
            .task {
                drills = (try? await session.backend.drills()) ?? []
                isLoading = false
            }
        }
    }

    private func categoryChip(_ value: String?, label: String) -> some View {
        Button {
            selectedCategory = value
        } label: {
            Text(label)
                .font(CWTheme.body(13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selectedCategory == value ? CWTheme.pine : CWTheme.creamCard)
                .foregroundStyle(selectedCategory == value ? CWTheme.cream : CWTheme.charcoal)
                .clipShape(Capsule())
        }
    }
}

struct DrillCard: View {
    let drill: Drill
    @State private var isPlaying = false

    var body: some View {
        CWCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(drill.category.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(CWTheme.gold)
                    Spacer()
                    Label("\(drill.durationMinutes) min", systemImage: "clock")
                        .font(CWTheme.body(12))
                        .foregroundStyle(CWTheme.stone)
                }
                Text(drill.title)
                    .font(CWTheme.body(16, weight: .semibold))
                    .foregroundStyle(CWTheme.charcoal)
                Text(drill.details)
                    .font(CWTheme.body(13))
                    .foregroundStyle(CWTheme.stone)

                if drill.videoURL != nil {
                    Button {
                        isPlaying = true
                    } label: {
                        Label("Watch drill", systemImage: "play.circle.fill")
                            .font(CWTheme.body(14, weight: .semibold))
                            .foregroundStyle(CWTheme.pine)
                    }
                } else {
                    Label("Video coming soon", systemImage: "video.badge.ellipsis")
                        .font(CWTheme.body(12))
                        .foregroundStyle(CWTheme.stone.opacity(0.7))
                }
            }
        }
        .sheet(isPresented: $isPlaying) {
            if let url = drill.videoURL {
                VideoPlayerSheet(video: SwingVideo(
                    id: drill.id, title: drill.title, angle: drill.category,
                    url: url, thumbnailURL: drill.thumbnailURL,
                    capturedAt: .now, source: "Drill Library"))
            }
        }
    }
}

#Preview {
    DrillLibraryView().environment(previewSession())
}
