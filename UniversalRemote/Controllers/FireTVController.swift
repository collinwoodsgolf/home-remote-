import Foundation

/// Drives a Fire TV Stick over the network by translating logical remote
/// buttons into Android key events delivered via ADB.
actor FireTVController {
    private let adb: ADBClient

    init(host: String, port: Int = 5555) {
        self.adb = ADBClient(host: host, port: UInt16(port))
    }

    /// Android `KEYCODE_*` values for each supported button.
    static func keyEvent(for button: RemoteButtonID) -> Int? {
        switch button {
        case .power:        return 26   // KEYCODE_POWER
        case .up:           return 19
        case .down:         return 20
        case .left:         return 21
        case .right:        return 22
        case .select:       return 23   // DPAD_CENTER
        case .back:         return 4
        case .home:         return 3
        case .menu:         return 82
        case .playPause:    return 85   // MEDIA_PLAY_PAUSE
        case .play:         return 126
        case .pause:        return 127
        case .stop:         return 86
        case .rewind:       return 89
        case .fastForward:  return 90
        case .nextTrack:    return 87
        case .previousTrack:return 88
        case .volumeUp:     return 24
        case .volumeDown:   return 25
        case .mute:         return 164
        default:            return nil
        }
    }

    func connect() async throws {
        try await adb.connect()
    }

    func send(_ button: RemoteButtonID) async throws {
        // Power is stateful: KEYCODE_POWER pops Fire OS's sleep menu, but the
        // stick can be queried, so ask whether it's awake and send the direct
        // SLEEP (223) or WAKEUP (224) keycode instead — no on-screen prompt.
        if button == .power {
            let wakefulness = try await adb.shell("dumpsys power | grep -i wakefulness=")
            let isAwake = wakefulness.lowercased().contains("=awake")
            try await adb.shell("input keyevent \(isAwake ? 223 : 224)")
            return
        }
        guard let key = Self.keyEvent(for: button) else {
            throw RemoteError.invalidConfiguration("No Fire TV key mapping for \(button.label).")
        }
        try await adb.shell("input keyevent \(key)")
    }

    /// Launch an app by package name (e.g. Netflix), handy for shortcuts.
    func launchApp(packageName: String) async throws {
        try await adb.shell("monkey -p \(packageName) -c android.intent.category.LAUNCHER 1")
    }

    func disconnect() async {
        await adb.disconnect()
    }
}
