import SwiftUI

/// IR-learning flow: enters learning mode on the hub, polls for the captured
/// code while the user presses their physical remote, and stores the result.
struct LearnIRView: View {
    let deviceID: UUID
    let button: RemoteButtonID

    @EnvironmentObject private var store: DeviceStore
    @EnvironmentObject private var controller: RemoteController
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case preparing
        case waiting
        case success
        case failed(String)
    }

    @State private var phase: Phase = .preparing

    private var device: Device? { store.devices.first(where: { $0.id == deviceID }) }

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
        case .preparing, .waiting:
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
        case .success:   return "Learned!"
        case .failed:    return "Couldn’t learn"
        }
    }

    private var subtitle: String {
        switch phase {
        case .preparing: return "Putting the IR hub into learning mode."
        case .waiting:   return "Point your physical remote at the hub and press the \(button.label) key once."
        case .success:   return "The \(button.label) button is ready to use."
        case .failed(let message): return message
        }
    }

    private func start() {
        phase = .preparing
        guard let device else { phase = .failed("Device unavailable."); return }
        Task {
            do {
                let hub = try await controller.authenticatedHub(for: device)
                try await hub.enterLearning()
                await MainActor.run { phase = .waiting }

                // Poll for up to ~30s for the user to press their remote.
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
}
