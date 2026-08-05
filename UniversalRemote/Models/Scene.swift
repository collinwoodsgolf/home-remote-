import Foundation

/// One action within a scene: fire a button on a device, optionally after a
/// short delay (so a projector has time to warm up before the screen drops,
/// etc.).
struct SceneStep: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var deviceID: UUID
    var button: RemoteButtonID
    /// Seconds to wait *before* performing this step.
    var delaySeconds: Double = 0
}

/// A one-tap macro that runs a sequence of steps across multiple devices.
/// Named `RemoteScene` (not `Scene`) to avoid shadowing SwiftUI's `Scene`
/// protocol used by the App's `some Scene` body.
struct RemoteScene: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var symbol: String
    var steps: [SceneStep]
}
