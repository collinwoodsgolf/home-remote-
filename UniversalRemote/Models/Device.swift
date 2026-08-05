import Foundation

/// The kinds of physical devices this app can act as a remote for.
/// Each maps to one of the user's real-world remotes.
enum DeviceKind: String, Codable, CaseIterable, Identifiable {
    case tclSpeaker
    case fireTV
    case frigidaireAC
    case yaberProjector
    case towerFan
    case projectorScreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tclSpeaker:      return "TCL Speaker"
        case .fireTV:          return "Amazon Fire TV Stick"
        case .frigidaireAC:    return "Frigidaire Window AC"
        case .yaberProjector:  return "Yaber Projector"
        case .towerFan:        return "Tower Fan"
        case .projectorScreen: return "Projector Screen"
        }
    }

    /// SF Symbol used for the device tile.
    var symbolName: String {
        switch self {
        case .tclSpeaker:      return "hifispeaker.fill"
        case .fireTV:          return "tv.fill"
        case .frigidaireAC:    return "snowflake"
        case .yaberProjector:  return "videoprojector.fill"
        case .towerFan:        return "fan.fill"
        case .projectorScreen: return "rectangle.arrowtriangle.2.inward"
        }
    }

    /// How this device is reached. Most home remotes are infrared and must go
    /// through a WiFi→IR bridge; the Fire TV can additionally be driven over
    /// the network directly.
    var defaultTransport: Transport {
        switch self {
        case .fireTV:          return .network        // ADB over WiFi (with IR fallback)
        case .tclSpeaker,
             .frigidaireAC,
             .yaberProjector,
             .towerFan,
             .projectorScreen: return .infrared       // via Broadlink hub
        }
    }
}

/// Transport used to deliver a command to a device.
enum Transport: String, Codable {
    case infrared   // sent as a learned IR burst through the Broadlink hub
    case network    // sent directly over the LAN (e.g. ADB to Fire TV)
}

/// A configured device instance the user owns. Holds the learned command
/// library and any transport-specific addressing.
struct Device: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: DeviceKind
    var name: String

    /// Transport currently selected for this device.
    var transport: Transport

    /// For `.infrared` devices: the id of the Broadlink hub that should emit
    /// the codes. Nil until a hub is paired.
    var hubID: String?

    /// For `.network` devices (Fire TV): the LAN IP address.
    var networkHost: String?
    var networkPort: Int = 5555

    /// Learned IR codes keyed by the logical button identifier (see RemoteButtonID).
    /// Stored as base64 of the raw Broadlink IR payload.
    var learnedCodes: [String: String] = [:]

    /// For a motorized projector screen: how many seconds it takes to travel
    /// fully from top to bottom. Used to auto-stop at the endpoint so the app
    /// can lower the screen with one tap and stop it by itself.
    var screenTravelSeconds: Double = 25

    /// When true, learning uses the RF sweep flow (315/433 MHz) instead of IR.
    /// Requires an RF-capable hub (RM Pro / RM4 Pro). Sending a learned code is
    /// identical for IR and RF, so only learning differs.
    var usesRFLearning: Bool = false

    init(kind: DeviceKind, name: String? = nil) {
        self.kind = kind
        self.name = name ?? kind.displayName
        self.transport = kind.defaultTransport
        // Motorized screens are almost always RF; default their learning to RF.
        self.usesRFLearning = (kind == .projectorScreen)
    }

    // Upgrade-safe decoding: fields added in later versions fall back to
    // sensible defaults so previously-saved devices (and their learned codes)
    // survive an app update instead of failing to decode.
    enum CodingKeys: String, CodingKey {
        case id, kind, name, transport, hubID, networkHost, networkPort
        case learnedCodes, screenTravelSeconds, usesRFLearning
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decode(DeviceKind.self, forKey: .kind)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? kind.displayName
        transport = try c.decodeIfPresent(Transport.self, forKey: .transport) ?? kind.defaultTransport
        hubID = try c.decodeIfPresent(String.self, forKey: .hubID)
        networkHost = try c.decodeIfPresent(String.self, forKey: .networkHost)
        networkPort = try c.decodeIfPresent(Int.self, forKey: .networkPort) ?? 5555
        learnedCodes = try c.decodeIfPresent([String: String].self, forKey: .learnedCodes) ?? [:]
        screenTravelSeconds = try c.decodeIfPresent(Double.self, forKey: .screenTravelSeconds) ?? 25
        usesRFLearning = try c.decodeIfPresent(Bool.self, forKey: .usesRFLearning) ?? (kind == .projectorScreen)
    }

    /// Whether the given logical button has a code/handler ready to fire.
    func canSend(_ button: RemoteButtonID) -> Bool {
        switch transport {
        case .network:
            return networkHost?.isEmpty == false
        case .infrared:
            return learnedCodes[button.rawValue] != nil
        }
    }
}
