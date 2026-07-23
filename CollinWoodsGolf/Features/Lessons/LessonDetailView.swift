import SwiftUI
import AVKit

struct LessonDetailView: View {
    let lesson: Lesson

    @State private var playingVideo: SwingVideo?

    var body: some View {
        ZStack {
            CWTheme.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lesson.date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                            .font(CWTheme.body(13, weight: .semibold))
                            .foregroundStyle(CWTheme.pine)
                        Text(lesson.title)
                            .font(CWTheme.display(26))
                            .foregroundStyle(CWTheme.charcoal)
                        Label(lesson.location, systemImage: "mappin.and.ellipse")
                            .font(CWTheme.body(13))
                            .foregroundStyle(CWTheme.stone)
                    }

                    if !lesson.videos.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            CWSectionHeader(title: "Swing Videos")
                            ForEach(lesson.videos) { video in
                                Button { playingVideo = video } label: {
                                    SwingVideoRow(video: video)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let note = lesson.note {
                        VStack(alignment: .leading, spacing: 10) {
                            CWSectionHeader(title: "Coach's Notes")
                            CWCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(note.summary)
                                        .font(CWTheme.body(15))
                                        .foregroundStyle(CWTheme.charcoal)

                                    noteList("Key Takeaways", items: note.keyTakeaways, icon: "checkmark.circle.fill", color: CWTheme.fairway)
                                    noteList("Homework", items: note.homework, icon: "figure.golf", color: CWTheme.gold)

                                    Label("Auto-generated from \(note.source) recording", systemImage: "waveform")
                                        .font(CWTheme.body(11))
                                        .foregroundStyle(CWTheme.stone)
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $playingVideo) { video in
            VideoPlayerSheet(video: video)
        }
    }

    private func noteList(_ title: String, items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(1)
                .foregroundStyle(CWTheme.stone)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(color)
                        .padding(.top, 2)
                    Text(item)
                        .font(CWTheme.body(14))
                        .foregroundStyle(CWTheme.charcoal)
                }
            }
        }
    }
}

struct SwingVideoRow: View {
    let video: SwingVideo

    var body: some View {
        CWCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(CWTheme.pineDark)
                        .frame(width: 84, height: 56)
                    Image(systemName: "play.fill")
                        .foregroundStyle(CWTheme.cream)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(video.title)
                        .font(CWTheme.body(15, weight: .semibold))
                        .foregroundStyle(CWTheme.charcoal)
                    Text(video.angle)
                        .font(CWTheme.body(13))
                        .foregroundStyle(CWTheme.stone)
                    Label(video.source, systemImage: "arrow.down.circle")
                        .font(CWTheme.body(11))
                        .foregroundStyle(CWTheme.stone)
                }
                Spacer()
            }
        }
    }
}

struct VideoPlayerSheet: View {
    let video: SwingVideo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: video.url))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(video.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        LessonDetailView(lesson: MockData.lessons[0])
    }
}
