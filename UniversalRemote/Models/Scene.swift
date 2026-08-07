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
    /// Skip this step when the app believes the device is already on — used
    /// for toggle-power devices where re-sending the code would turn them off.
    var skipIfOn: Bool = false
    /// Mirror guard: skip when the device is believed to already be off
    /// (protects "off" toggles from switching an idle device back on).
    var skipIfOff: Bool = false

    init(id: UUID = UUID(), deviceID: UUID, button: RemoteButtonID,
         delaySeconds: Double = 0, skipIfOn: Bool = false, skipIfOff: Bool = false) {
        self.id = id
        self.deviceID = deviceID
        self.button = button
        self.delaySeconds = delaySeconds
        self.skipIfOn = skipIfOn
        self.skipIfOff = skipIfOff
    }

    enum CodingKeys: String, CodingKey {
        case id, deviceID, button, delaySeconds, skipIfOn, skipIfOff
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        deviceID = try c.decode(UUID.self, forKey: .deviceID)
        button = try c.decode(RemoteButtonID.self, forKey: .button)
        delaySeconds = try c.decodeIfPresent(Double.self, forKey: .delaySeconds) ?? 0
        skipIfOn = try c.decodeIfPresent(Bool.self, forKey: .skipIfOn) ?? false
        skipIfOff = try c.decodeIfPresent(Bool.self, forKey: .skipIfOff) ?? false
    }
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
