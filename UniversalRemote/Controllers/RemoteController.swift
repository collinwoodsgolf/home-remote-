import Foundation

/// Routes a logical button press for a given device to the correct transport:
/// the Fire TV network controller or the Broadlink IR hub. Caches live
/// controllers/hubs so repeated presses reuse the same authenticated session.
@MainActor
final class RemoteController: ObservableObject {
    private let store: DeviceStore

    /// Per-device transient feedback shown in the UI.
    @Published var lastError: String?
    @Published var busyButton: RemoteButtonID?

    private var fireTVControllers: [UUID: FireTVController] = [:]
    private var hubControllers: [String: BroadlinkHub] = [:]

    init(store: DeviceStore) {
        self.store = store
    }

    /// Fire a button. Returns immediately; UI observes `busyButton`/`lastError`.
    func press(_ button: RemoteButtonID, on device: Device) {
        busyButton = button
        Task {
            do {
                switch device.transport {
                case .network:
                    try await sendNetwork(button, device: device)
                case .infrared:
                    try await sendInfrared(button, device: device)
                }
                await MainActor.run { self.lastError = nil }
            } catch {
                await MainActor.run { self.lastError = error.localizedDescription }
            }
            await MainActor.run { self.busyButton = nil }
        }
    }

    // MARK: - Transports

    private func sendNetwork(_ button: RemoteButtonID, device: Device) async throws {
        guard let host = device.networkHost, !host.isEmpty else {
            throw RemoteError.invalidConfiguration("Set the Fire TV's IP address in its settings first.")
        }
        let controller = fireTVControllers[device.id] ?? {
            let c = FireTVController(host: host, port: device.networkPort)
            fireTVControllers[device.id] = c
            return c
        }()
        try await controller.send(button)
    }

    private func sendInfrared(_ button: RemoteButtonID, device: Device) async throws {
        guard let code = store.learnedCode(for: button, on: device) else {
            throw RemoteError.notLearned
        }
        let hub = try hubController(for: device)
        try await hub.authenticateIfNeeded()
        try await hub.sendIR(code)
    }

    /// Returns the cached hub controller for the device, creating one on first
    /// use. Authentication is performed lazily by the caller.
    func hubController(for device: Device) throws -> BroadlinkHub {
        guard let info = store.hub(for: device) else { throw RemoteError.noHubPaired }
        if let existing = hubControllers[info.id] { return existing }
        let hub = BroadlinkHub(info: info)
        hubControllers[info.id] = hub
        return hub
    }

    /// Returns a freshly authenticated hub (used by the learning flow, which
    /// wants a guaranteed-live session before entering learn mode).
    func authenticatedHub(for device: Device) async throws -> BroadlinkHub {
        let hub = try hubController(for: device)
        try await hub.authenticate()
        return hub
    }

    func invalidate(_ device: Device) {
        fireTVControllers[device.id] = nil
    }

    /// Launch a streaming app on a Fire TV by package name.
    func launchApp(_ shortcut: FireTVAppShortcut, on device: Device) {
        Task {
            do {
                guard let host = device.networkHost, !host.isEmpty else {
                    throw RemoteError.invalidConfiguration("Set the Fire TV's IP address in its settings first.")
                }
                let controller = fireTVControllers[device.id] ?? {
                    let c = FireTVController(host: host, port: device.networkPort)
                    fireTVControllers[device.id] = c
                    return c
                }()
                try await controller.launchApp(packageName: shortcut.packageName)
                await MainActor.run { self.lastError = nil }
            } catch {
                await MainActor.run { self.lastError = error.localizedDescription }
            }
        }
    }
}
