import Foundation
import SwiftUI

/// Single source of truth for configured devices and paired hubs. Persists to
/// UserDefaults as JSON (small data, no need for a database) and is shared
/// through the SwiftUI environment.
@MainActor
final class DeviceStore: ObservableObject {
    @Published var devices: [Device] = []
    @Published var hubs: [BroadlinkHubInfo] = []

    private let devicesKey = "devices.v1"
    private let hubsKey = "hubs.v1"

    init() {
        load()
        if devices.isEmpty { seedDefaultDevices() }
    }

    // MARK: - Seeding

    /// Pre-populate the five remotes the user owns so the app is usable
    /// immediately; they just need codes learned / hosts set.
    private func seedDefaultDevices() {
        devices = [
            Device(kind: .fireTV),
            Device(kind: .tclSpeaker),
            Device(kind: .frigidaireAC),
            Device(kind: .yaberProjector),
            Device(kind: .towerFan),
        ]
        save()
    }

    // MARK: - Mutations

    func update(_ device: Device) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index] = device
        save()
    }

    func addHub(_ hub: BroadlinkHubInfo) {
        if let index = hubs.firstIndex(where: { $0.id == hub.id }) {
            hubs[index] = hub
        } else {
            hubs.append(hub)
        }
        // Auto-assign the first hub to every IR device that has none.
        for i in devices.indices where devices[i].transport == .infrared && devices[i].hubID == nil {
            devices[i].hubID = hub.id
        }
        save()
    }

    func hub(for device: Device) -> BroadlinkHubInfo? {
        guard let hubID = device.hubID else { return hubs.first }
        return hubs.first(where: { $0.id == hubID }) ?? hubs.first
    }

    func storeLearnedCode(_ code: [UInt8], for button: RemoteButtonID, on device: Device) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].learnedCodes[button.rawValue] = Data(code).base64EncodedString()
        save()
    }

    func learnedCode(for button: RemoteButtonID, on device: Device) -> [UInt8]? {
        guard let base64 = device.learnedCodes[button.rawValue],
              let data = Data(base64Encoded: base64) else { return nil }
        return [UInt8](data)
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(devices) {
            UserDefaults.standard.set(data, forKey: devicesKey)
        }
        if let data = try? encoder.encode(hubs) {
            UserDefaults.standard.set(data, forKey: hubsKey)
        }
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: devicesKey),
           let decoded = try? decoder.decode([Device].self, from: data) {
            devices = decoded
        }
        if let data = UserDefaults.standard.data(forKey: hubsKey),
           let decoded = try? decoder.decode([BroadlinkHubInfo].self, from: data) {
            hubs = decoded
        }
    }
}
