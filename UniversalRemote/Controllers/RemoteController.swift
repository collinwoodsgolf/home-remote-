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

    /// While a motorized screen is travelling, the seconds remaining until the
    /// app auto-stops it at the endpoint (keyed by device id). Drives the live
    /// countdown / progress in the UI.
    @Published var screenCountdowns: [UUID: Int] = [:]

    /// The scene currently running, if any (drives its tile's spinner).
    @Published var runningSceneID: UUID?

    /// Devices currently mid volume-slider adjustment (disables their slider).
    @Published var volumeBusy: Set<UUID> = []

    private var fireTVControllers: [UUID: FireTVController] = [:]
    private var hubControllers: [String: BroadlinkHub] = [:]
    private var screenTasks: [UUID: Task<Void, Never>] = [:]
    private var screenGeneration: [UUID: Int] = [:]

    init(store: DeviceStore) {
        self.store = store
    }

    /// Fire a button. Returns immediately; UI observes `busyButton`/`lastError`.
    func press(_ button: RemoteButtonID, on device: Device) {
        busyButton = button
        Task {
            do {
                try await perform(button, on: device)
                self.lastError = nil
            } catch {
                self.lastError = error.localizedDescription
            }
            self.busyButton = nil
        }
    }

    /// Perform a button on the right transport, awaiting completion. Shared by
    /// single presses and scene steps (which need ordered, awaited execution).
    private func perform(_ button: RemoteButtonID, on device: Device) async throws {
        // The Yaber shows an "OK to shut down?" dialog on power-off; pressing
        // OK confirms it (a second Power press is read as a fresh power-on and
        // turns it back on). When the projector is believed on, send Power then
        // auto-answer the dialog with Select so it fully shuts down.
        if device.kind == .yaberProjector, button == .power, device.assumedOn == true {
            try await sendInfrared(.power, device: device)
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            try await sendInfrared(.select, device: device)
            setAssumedPower(false, device: device)
            return
        }

        switch device.transport {
        case .network:
            try await sendNetwork(button, device: device)
        case .infrared:
            try await sendInfrared(button, device: device)
        }
        recordAssumedPower(button, device: device)
    }

    private func setAssumedPower(_ on: Bool, device: Device) {
        guard var updated = store.devices.first(where: { $0.id == device.id }) else { return }
        updated.assumedOn = on
        store.update(updated)
    }

    /// Track the best-effort power state after a successful send, so scenes
    /// can skip toggles that would turn a running device off.
    private func recordAssumedPower(_ button: RemoteButtonID, device: Device) {
        guard let current = store.devices.first(where: { $0.id == device.id }) else { return }
        var updated = current
        switch button {
        case .powerOn:  updated.assumedOn = true
        case .powerOff: updated.assumedOn = false
        case .power:    updated.assumedOn = !(current.assumedOn ?? false)
        default:        return
        }
        store.update(updated)
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
        do {
            try await controller.send(button)
        } catch {
            // The stick may have been moved to a new address. Sweep the subnet
            // for an open ADB port, rehome the device, and retry once.
            let candidates = await ADBDiscovery.scanSubnet(port: UInt16(device.networkPort))
            guard let newHost = candidates.first(where: { $0 != host }) else { throw error }
            var updated = device
            updated.networkHost = newHost
            store.update(updated)
            let fresh = FireTVController(host: newHost, port: updated.networkPort)
            fireTVControllers[device.id] = fresh
            try await fresh.send(button)
        }
    }

    private func sendInfrared(_ button: RemoteButtonID, device: Device) async throws {
        guard let code = store.learnedCode(for: button, on: device) else {
            throw RemoteError.notLearned
        }
        let hub = try hubController(for: device)
        do {
            try await hub.authenticateIfNeeded()
            try await hub.sendIR(code)
        } catch {
            // A hub that answered yesterday but is unreachable now has usually
            // been moved to a new address by the router. Sweep the subnet for
            // the same hub (matched by MAC), rehome it, and retry once.
            if case RemoteError.deviceError = error { throw error }
            guard let fresh = try await relocatedHub(for: device) else { throw error }
            try await fresh.authenticateIfNeeded()
            try await fresh.sendIR(code)
        }
    }

    /// Sweeps the subnet for the device's paired hub after its stored address
    /// stops answering. Returns a fresh controller at the new address, or nil
    /// if the hub genuinely isn't on the network.
    private func relocatedHub(for device: Device) async throws -> BroadlinkHub? {
        guard let info = store.hub(for: device) else { throw RemoteError.noHubPaired }
        let candidates = await BroadlinkDiscovery.scanSubnet()
        guard let match = candidates.first(where: { $0.id == info.id }),
              match.host != info.host else { return nil }
        store.addHub(match)                    // upserts by MAC, new address
        hubControllers[match.id] = BroadlinkHub(info: match)
        return hubControllers[match.id]
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
    /// wants a guaranteed-live session before entering learn mode). Rehomes
    /// the hub automatically if its address has changed.
    func authenticatedHub(for device: Device) async throws -> BroadlinkHub {
        let hub = try hubController(for: device)
        do {
            try await hub.authenticate()
            return hub
        } catch {
            if case RemoteError.deviceError = error { throw error }
            guard let fresh = try await relocatedHub(for: device) else { throw error }
            try await fresh.authenticate()
            return fresh
        }
    }

    func invalidate(_ device: Device) {
        fireTVControllers[device.id] = nil
    }

    // MARK: - Scenes

    /// Run a scene's steps in order, honoring each step's delay. Screen
    /// lower/raise steps use the auto-stop behavior; everything else is an
    /// awaited button press so ordering is preserved.
    func runScene(_ scene: RemoteScene) {
        guard runningSceneID == nil else { return }   // ignore double-taps
        runningSceneID = scene.id
        Task {
            for step in scene.steps {
                if step.delaySeconds > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(step.delaySeconds * 1_000_000_000))
                }
                guard let device = store.devices.first(where: { $0.id == step.deviceID }) else { continue }
                if step.skipIfOn && device.assumedOn == true { continue }
                if step.skipIfOff && device.assumedOn == false { continue }

                if device.kind == .projectorScreen && step.button == .screenDown {
                    lowerScreen(device)
                } else if device.kind == .projectorScreen && step.button == .screenUp {
                    raiseScreen(device)
                } else {
                    do { try await perform(step.button, on: device) }
                    catch { self.lastError = error.localizedDescription }
                }
            }
            self.runningSceneID = nil
        }
    }

    // MARK: - Volume slider (IR pseudo-absolute)

    /// Move an IR device's volume to `percent`. IR has no feedback channel, so
    /// the app tracks an assumed level and emits the number of Vol+/Vol−
    /// pulses needed to reach the target. Dragging to 0 sends a full-range
    /// down-burst, which forces the hardware to its floor and re-syncs the
    /// assumed level with reality.
    func setVolume(percent: Int, on device: Device) {
        let target = max(0, min(100, percent))
        guard !volumeBusy.contains(device.id) else { return }

        let steps = max(1, device.volumeSteps)
        let presses: Int
        let button: RemoteButtonID
        if target == 0 {
            presses = steps                      // full floor: guaranteed sync
            button = .volumeDown
        } else if target == 100 {
            presses = steps                      // full ceiling: the speaker's
            button = .volumeUp                   // max beep confirms the sync
        } else {
            let delta = target - device.volumeLevel
            if delta == 0 { return }
            presses = max(1, Int((Double(abs(delta)) / 100.0 * Double(steps)).rounded()))
            button = delta > 0 ? .volumeUp : .volumeDown
        }

        volumeBusy.insert(device.id)
        Task {
            var sent = 0
            var failure: String?
            for _ in 0..<presses {
                do {
                    try await sendInfrared(button, device: device)
                    sent += 1
                } catch {
                    failure = error.localizedDescription
                    break
                }
                // Receivers need breathing room between distinct presses.
                try? await Task.sleep(nanoseconds: 180_000_000)
            }

            // Record where we believe the hardware landed. On a partial send,
            // estimate from the pulses that actually went out.
            var updated = device
            if failure == nil {
                updated.volumeLevel = target
            } else {
                let perStep = 100.0 / Double(steps)
                let moved = Int((Double(sent) * perStep).rounded()) * (button == .volumeUp ? 1 : -1)
                updated.volumeLevel = max(0, min(100, device.volumeLevel + moved))
            }
            store.update(updated)
            self.lastError = failure
            self.volumeBusy.remove(device.id)
        }
    }

    // MARK: - Motorized projector screen

    /// True while this screen is travelling under app control.
    func isScreenMoving(_ device: Device) -> Bool {
        screenCountdowns[device.id] != nil
    }

    /// Lower the screen and automatically stop it at the bottom endpoint after
    /// the calibrated travel time — one tap, no need to watch and hit stop.
    func lowerScreen(_ device: Device) {
        moveScreen(device, direction: .screenDown)
    }

    /// Raise the screen fully. No timed stop here: screens end retraction on
    /// their own top limit switch, and a timer calibrated for the (different)
    /// lowering duration would park the screen halfway up — seen in the
    /// "All Off" scene. The manual Stop key still works mid-raise.
    func raiseScreen(_ device: Device) {
        screenTasks[device.id]?.cancel()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.sendInfrared(.screenUp, device: device)
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    /// Stop a screen that's currently travelling (cancels the auto-stop timer;
    /// the stop command is still sent immediately).
    func stopScreen(_ device: Device) {
        // Cancelling the task makes its sleep throw, so it falls through to the
        // stop command and clears the countdown.
        screenTasks[device.id]?.cancel()
    }

    private func moveScreen(_ device: Device, direction: RemoteButtonID) {
        guard direction == .screenDown || direction == .screenUp else { return }
        // Restart cleanly if it's already moving.
        screenTasks[device.id]?.cancel()

        // A generation token lets a superseded task exit without clobbering the
        // state of the newer one that replaced it.
        let gen = (screenGeneration[device.id] ?? 0) + 1
        screenGeneration[device.id] = gen
        let seconds = max(1, Int(device.screenTravelSeconds.rounded()))

        let task = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await self.sendInfrared(direction, device: device)
            } catch {
                if self.screenGeneration[device.id] == gen {
                    self.lastError = error.localizedDescription
                    self.screenCountdowns[device.id] = nil
                }
                return
            }

            // Count down to the endpoint. A manual Stop cancels the task, which
            // makes the sleep throw and breaks out to send the stop early.
            for remaining in stride(from: seconds, through: 1, by: -1) {
                if self.screenGeneration[device.id] != gen { return }
                self.screenCountdowns[device.id] = remaining
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    break
                }
            }

            // Endpoint reached (or user stopped): halt the motor. Screens with
            // built-in limit switches ignore a redundant stop harmlessly.
            try? await self.sendInfrared(.screenStop, device: device)
            if self.screenGeneration[device.id] == gen {
                self.screenCountdowns[device.id] = nil
                self.screenTasks[device.id] = nil
            }
        }
        screenTasks[device.id] = task
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
