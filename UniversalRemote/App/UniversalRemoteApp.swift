import SwiftUI

@main
struct UniversalRemoteApp: App {
    @StateObject private var store: DeviceStore
    @StateObject private var controller: RemoteController

    init() {
        let store = DeviceStore()
        _store = StateObject(wrappedValue: store)
        _controller = StateObject(wrappedValue: RemoteController(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(controller)
        }
    }
}
