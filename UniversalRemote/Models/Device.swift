import Foundation

/// The kinds of physical devices this app can act as a remote for.
/// Each maps to one of the user's real-world remotes.
enum DeviceKind: String, Codable, CaseIterable, Identifiable {
    case tclSpeaker
    case fireTV
    case frigidaireAC
    case yaberProjector
    case towerFan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tclSpeaker:     return "TCL Speaker"
        case .fireTV:         return "Amazon Fire TV Stick"
        case .frigidaireAC:   return "Frigidaire Window AC"
        case .yaberProjector: return "Yaber Projector"
        case .towerFan:       return "Tower Fan"
        }
    }

    /// SF Symbol used for the device tile.
    var symbolName: String {
        switch self {
        case .tclSpeaker:     return "hifispeaker.fill"
        case .fireTV:         return "tv.fill"
        case .frigidaireAC:   return "snowflake"
        case .yaberProjector: return "videoprojector.fill"
        case .towerFan:       return "fan.fill"
        }
    }

    /// How this device is reached. Most home remotes are infrared and must go
    /// through a WiFi→IR bridge; the Fire TV can additionally be driven over
    /// the network directly.
    var defaultTransport: Transport {
        switch self {
        case .fireTV:         return .network        // ADB over WiFi (with IR fallback)
        case .tclSpeaker,
             .frigidaireAC,
             .yaberProjector,
             .towerFan:       return .infrared       // via Broadlink hub
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

    init(kind: DeviceKind, name: String? = nil) {
        self.kind = kind
        self.name = name ?? kind.displayName
        self.transport = kind.defaultTransport
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
