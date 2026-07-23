import SwiftUI

@main
struct CollinWoodsGolfApp: App {
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(CWTheme.pine)
                .task { await session.restore() }
        }
    }
}

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.phase {
            case .loading:
                ZStack {
                    CWTheme.cream.ignoresSafeArea()
                    CWMonogram(size: 88)
                }
            case .signedOut:
                SignInView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.phase)
    }
}
