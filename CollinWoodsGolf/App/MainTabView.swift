import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            LessonHistoryView()
                .tabItem { Label("Lessons", systemImage: "book.closed.fill") }
            ChatHubView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
            DrillLibraryView()
                .tabItem { Label("Drills", systemImage: "figure.golf") }
            MyGameView()
                .tabItem { Label("My Game", systemImage: "chart.xyaxis.line") }
        }
    }
}

#Preview {
    MainTabView()
        .environment(previewSession())
        .tint(CWTheme.pine)
}

/// Signed-in session for SwiftUI previews.
@MainActor
func previewSession() -> SessionStore {
    let session = SessionStore()
    session.didSignIn(MockData.client)
    return session
}
