import SwiftUI

/// Per-device configuration: network address for the Fire TV, hub assignment
/// for IR devices, and per-button IR learning.
struct DeviceSettingsView: View {
    let deviceID: UUID

    @EnvironmentObject private var store: DeviceStore
    @EnvironmentObject private var controller: RemoteController
    @Environment(\.dismiss) private var dismiss

    @State private var learningButton: RemoteButtonID?

    private var device: Device? { store.devices.first(where: { $0.id == deviceID }) }

    var body: some View {
        NavigationStack {
            Group {
                if let device {
                    form(for: device)
                } else {
                    ContentUnavailableView("Device removed", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func form(for device: Device) -> some View {
        Form {
            Section("Name") {
                TextField("Name", text: Binding(
                    get: { device.name },
                    set: { var d = device; d.name = $0; store.update(d) }
                ))
            }

            if device.transport == .network {
                networkSection(device)
            } else {
                infraredSection(device)
            }
        }
        .sheet(item: $learningButton) { button in
            LearnIRView(deviceID: device.id, button: button)
        }
    }

    // MARK: - Fire TV (network)

    @ViewBuilder
    private func networkSection(_ device: Device) -> some View {
        Section {
            TextField("IP address (e.g. 192.168.1.42)", text: Binding(
                get: { device.networkHost ?? "" },
                set: { var d = device; d.networkHost = $0; store.update(d); controller.invalidate(d) }
            ))
            .keyboardType(.decimalPad)
            .autocorrectionDisabled()

            TextField("Port", text: Binding(
                get: { String(device.networkPort) },
                set: { var d = device; d.networkPort = Int($0) ?? 5555; store.update(d); controller.invalidate(d) }
            ))
            .keyboardType(.numberPad)
        } header: {
            Text("Fire TV Network")
        } footer: {
            Text("On the Fire TV enable Settings → My Fire TV → Developer Options → ADB Debugging. The first connection shows an authorization prompt on the TV — accept it. Find the IP under Settings → My Fire TV → About → Network.")
        }
    }

    // MARK: - IR devices

    @ViewBuilder
    private func infraredSection(_ device: Device) -> some View {
        Section("IR Hub") {
            if store.hubs.isEmpty {
                NavigationLink("Pair an IR hub") { HubSetupView() }
            } else {
                Picker("Hub", selection: Binding(
                    get: { device.hubID ?? store.hubs.first?.id ?? "" },
                    set: { var d = device; d.hubID = $0; store.update(d) }
                )) {
                    ForEach(store.hubs) { hub in
                        Text(hub.name).tag(hub.id)
                    }
                }
            }
        }

        Section {
            Toggle("RF remote (315 / 433 MHz)", isOn: Binding(
                get: { device.usesRFLearning },
                set: { var d = device; d.usesRFLearning = $0; store.update(d) }
            ))
        } footer: {
            Text(device.usesRFLearning
                 ? "Learning uses the RF sweep: hold the button to find the frequency, then tap to capture. Requires an RF-capable hub (RM Pro / RM4 Pro) and a handheld RF transmitter to learn from."
                 : "Turn on if this device's remote is radio-frequency (RF) rather than infrared — common for motorized projector screens and some ceiling fans.")
        }

        if device.kind == .projectorScreen {
            Section {
                Stepper(value: Binding(
                    get: { device.screenTravelSeconds },
                    set: { var d = device; d.screenTravelSeconds = $0; store.update(d) }
                ), in: 3...180, step: 1) {
                    HStack {
                        Text("Travel time")
                        Spacer()
                        Text("\(Int(device.screenTravelSeconds))s").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Auto-Stop Calibration")
            } footer: {
                Text("Time the screen takes to travel fully from top to bottom. Tap Lower once, count the seconds until it's all the way down, and set that here — the app then stops it there automatically. If your screen has built-in limit switches you can leave this generous; the extra Stop is harmless.")
            }
        }

        Section {
            ForEach(RemoteLayout.layout(for: device.kind).rows.flatMap(\.buttons), id: \.self) { button in
                Button {
                    learningButton = button
                } label: {
                    HStack {
                        Text(button.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if device.learnedCodes[button.rawValue] != nil {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Text("Learn").foregroundStyle(.blue)
                        }
                    }
                }
            }
        } header: {
            Text("Buttons")
        } footer: {
            Text("Tap a button, then point your physical \(device.name) remote at the hub and press the matching key to teach it.")
        }
    }
}

extension RemoteButtonID: Identifiable {
    var id: String { rawValue }
}
