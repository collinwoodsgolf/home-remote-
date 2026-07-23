import SwiftUI

/// Every past lesson with its auto-uploaded Plaud note and Swing Catalyst
/// videos. Content lands here automatically via the backend agents
/// (docs/AGENTS.md) — the student never uploads anything.
struct LessonHistoryView: View {
    @Environment(SessionStore.self) private var session

    @State private var lessons: [Lesson] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                CWTheme.cream.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if lessons.isEmpty {
                    CWEmptyState(
                        icon: "book.closed",
                        title: "No lessons yet",
                        message: "After each session, Coach Woods' notes and your Swing Catalyst videos appear here automatically.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(lessons) { lesson in
                                NavigationLink {
                                    LessonDetailView(lesson: lesson)
                                } label: {
                                    LessonRow(lesson: lesson)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(18)
                    }
                }
            }
            .navigationTitle("Lesson History")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        lessons = (try? await session.backend.lessonHistory()) ?? []
        isLoading = false
    }
}

struct LessonRow: View {
    let lesson: Lesson

    var body: some View {
        CWCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(lesson.date, format: .dateTime.month(.wide).day().year())
                        .font(CWTheme.body(12, weight: .semibold))
                        .foregroundStyle(CWTheme.pine)
                    Spacer()
                    if !lesson.videos.isEmpty {
                        Label("\(lesson.videos.count)", systemImage: "video.fill")
                            .font(CWTheme.body(12, weight: .medium))
                            .foregroundStyle(CWTheme.stone)
                    }
                    if lesson.note != nil {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(CWTheme.stone)
                    }
                }
                Text(lesson.title)
                    .font(CWTheme.body(17, weight: .semibold))
                    .foregroundStyle(CWTheme.charcoal)
                if let summary = lesson.note?.summary {
                    Text(summary)
                        .font(CWTheme.body(13))
                        .foregroundStyle(CWTheme.stone)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    ForEach(lesson.focusAreas, id: \.self) { area in
                        Text(area)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CWTheme.pine.opacity(0.1))
                            .foregroundStyle(CWTheme.pine)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

#Preview {
    LessonHistoryView().environment(previewSession())
}
