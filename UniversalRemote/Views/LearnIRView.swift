import SwiftUI

/// Learning flow for a single button. Handles both IR (point-and-press) and the
/// two-phase RF sweep (hold to find the frequency, then tap to capture the
/// packet), chosen per device via `usesRFLearning`.
struct LearnIRView: View {
    let deviceID: UUID
    let button: RemoteButtonID

    @EnvironmentObject private var store: DeviceStore
    @EnvironmentObject private var controller: RemoteController
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case preparing
        case waiting        // IR: press once
        case rfHold         // RF: press & hold to find the frequency
        case rfTap          // RF: tap the same button to capture the packet
        case success
        case failed(String)
    }

    @State private var phase: Phase = .preparing

    private var device: Device? { store.devices.first(where: { $0.id == deviceID }) }
    private var isRF: Bool { device?.usesRFLearning ?? false }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            icon
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            if case .failed = phase {
                Button("Try Again") { start() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Close") { dismiss() }
                .padding(.bottom)
        }
        .padding()
        .task { start() }
    }

    @ViewBuilder
    private var icon: some View {
        switch phase {
        case .preparing, .waiting, .rfHold, .rfTap:
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 64)).symbolEffect(.variableColor.iterative, isActive: true)
                .foregroundStyle(.blue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64)).foregroundStyle(.red)
        }
    }

    private var title: String {
        switch phase {
        case .preparing: return "Preparing hub…"
        case .waiting:   return "Press “\(button.label)” now"
        case .rfHold:    return "Press & hold “\(button.label)”"
        case .rfTap:     return "Now tap “\(button.label)”"
        case .success:   return "Learned!"
        case .failed:    return "Couldn’t learn"
        }
    }

    private var subtitle: String {
        switch phase {
        case .preparing:
            return isRF ? "Putting the RF hub into scan mode." : "Putting the IR hub into learning mode."
        case .waiting:
            return "Point your physical remote at the hub and press the \(button.label) key once."
        case .rfHold:
            return "Hold your screen's handheld remote near the hub and keep the \(button.label) button pressed until it locks on."
        case .rfTap:
            return "Frequency locked. Now tap the \(button.label) button a few times to capture the code."
        case .success:
            return "The \(button.label) button is ready to use."
        case .failed(let message):
            return message
        }
    }

    private func start() {
        phase = .preparing
        guard let device else { phase = .failed("Device unavailable."); return }
        if isRF {
            startRF(device)
        } else {
            startIR(device)
        }
    }

    // MARK: - IR

    private func startIR(_ device: Device) {
        Task {
            do {
                let hub = try await controller.authenticatedHub(for: device)
                try await hub.enterLearning()
                await MainActor.run { phase = .waiting }

                for _ in 0..<30 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    if let code = try? await hub.readLearnedCode(), !code.isEmpty {
                        await MainActor.run {
                            store.storeLearnedCode(code, for: button, on: device)
                            phase = .success
                        }
                        return
                    }
                }
                await MainActor.run { phase = .failed("No IR signal detected. Make sure the remote points at the hub and try again.") }
            } catch {
                await MainActor.run { phase = .failed(error.localizedDescription) }
            }
        }
    }

    // MARK: - RF (RM Pro / RM4 Pro)

    private func startRF(_ device: Device) {
        Task {
            var hub: BroadlinkHub?
            do {
                let h = try await controller.authenticatedHub(for: device)
                hub = h
                try await h.startRFSweep()
                await MainActor.run { phase = .rfHold }

                // Phase 1: find the carrier frequency while the user holds the button.
                var found = false
                for _ in 0..<40 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    if (try? await h.checkFrequencyFound()) == true { found = true; break }
                }
                guard found else {
                    await h.cancelRFSweep()
                    await MainActor.run { phase = .failed("No RF signal found. Hold the button on your screen's handheld remote close to the hub, then try again.") }
                    return
                }

                // Phase 2: capture the actual packet on subsequent taps.
                try await h.findRFPacket()
                await MainActor.run { phase = .rfTap }
                for _ in 0..<40 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    if let code = try? await h.readLearnedCode(), !code.isEmpty {
                        await MainActor.run {
                            store.storeLearnedCode(code, for: button, on: device)
                            phase = .success
                        }
                        return
                    }
                }
                await h.cancelRFSweep()
                await MainActor.run { phase = .failed("Frequency locked, but no code captured. Tap the \(button.label) button a few times and try again.") }
            } catch {
                await hub?.cancelRFSweep()
                await MainActor.run { phase = .failed(error.localizedDescription) }
            }
        }
    }
}
