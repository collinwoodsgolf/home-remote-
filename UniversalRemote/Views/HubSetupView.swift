import SwiftUI

/// Discovers Broadlink IR hubs on the LAN and lets the user pair them.
struct HubSetupView: View {
    @EnvironmentObject private var store: DeviceStore

    @State private var isScanning = false
    @State private var found: [BroadlinkHubInfo] = []
    @State private var manualIP = ""
    @State private var manualProbeError: String?

    var body: some View {
        List {
            Section {
                ForEach(store.hubs) { hub in
                    HubRow(hub: hub, paired: true)
                }
                if store.hubs.isEmpty {
                    Text("No hubs paired yet.").foregroundStyle(.secondary)
                }
            } header: {
                Text("Paired Hubs")
            }

            Section {
                if isScanning {
                    HStack { ProgressView(); Text("Scanning the local network…") }
                } else {
                    Button {
                        scan()
                    } label: {
                        Label("Scan for Hubs", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                ForEach(found.filter { hub in !store.hubs.contains(where: { $0.id == hub.id }) }) { hub in
                    Button {
                        store.addHub(hub)
                    } label: {
                        HubRow(hub: hub, paired: false)
                    }
                }
            } header: {
                Text("Discovered")
            } footer: {
                Text("Make sure your iPhone and the Broadlink hub (RM4 Mini / RM Pro) are on the same Wi-Fi network, and the hub has already been added to your Wi-Fi using the Broadlink app once.")
            }

            Section {
                TextField("Hub IP address (e.g. 192.168.1.50)", text: $manualIP)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                Button("Add by IP") { probeManual() }
                    .disabled(manualIP.isEmpty)
                if let manualProbeError {
                    Text(manualProbeError).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Add Manually")
            } footer: {
                Text("If discovery is blocked (no multicast entitlement), enter the hub's IP. The app probes it directly to read its type and MAC.")
            }
        }
        .navigationTitle("IR Hubs")
        .task {
            if store.hubs.isEmpty { scan() }
        }
    }

    private func scan() {
        isScanning = true
        Task {
            let hubs = await BroadlinkDiscovery.scan()
            await MainActor.run {
                found = hubs
                isScanning = false
            }
        }
    }

    /// Probe a manually entered IP with a unicast discovery packet to read the
    /// hub's MAC and device type, then pair it.
    private func probeManual() {
        manualProbeError = nil
        let ip = manualIP.trimmingCharacters(in: .whitespaces)
        Task {
            if let hub = await BroadlinkDiscovery.probe(host: ip) {
                await MainActor.run {
                    store.addHub(hub)
                    manualIP = ""
                }
            } else {
                await MainActor.run {
                    manualProbeError = "No Broadlink hub answered at \(ip)."
                }
            }
        }
    }
}

private struct HubRow: View {
    let hub: BroadlinkHubInfo
    let paired: Bool

    var body: some View {
        HStack {
            Image(systemName: "wifi.router.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(hub.name).font(.headline)
                Text("\(hub.host) · \(hub.id)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if paired {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Text("Add").foregroundStyle(.blue)
            }
        }
    }
}
