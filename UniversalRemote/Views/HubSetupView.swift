import SwiftUI

/// Discovers Broadlink IR hubs on the LAN and lets the user pair them.
struct HubSetupView: View {
    @EnvironmentObject private var store: DeviceStore

    @State private var isScanning = false
    @State private var found: [BroadlinkHubInfo] = []
    @State private var manualIP = ""
    @State private var manualProbeError: String?
    @State private var diagnostics: String?
    @State private var isTesting = false

    var body: some View {
        List {
            Section {
                ForEach(store.hubs) { hub in
                    HubRow(hub: hub, paired: true)
                }
                if store.hubs.isEmpty {
                    Text("No hubs paired yet.").foregroundStyle(.secondary)
                }
                if let hub = store.hubs.first {
                    Button {
                        runDiagnostics(hub)
                    } label: {
                        if isTesting {
                            HStack { ProgressView(); Text("Testing…") }
                        } else {
                            Label("Test Connection", systemImage: "stethoscope")
                        }
                    }
                    .disabled(isTesting)

                    if let diagnostics {
                        Text(diagnostics)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            } header: {
                Text("Paired Hubs")
            } footer: {
                Text("If a button never learns, run Test Connection — it names the exact step that fails.")
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

    private func runDiagnostics(_ info: BroadlinkHubInfo) {
        isTesting = true
        diagnostics = nil
        Task {
            let report = await BroadlinkHub(info: info).diagnose()
            await MainActor.run {
                diagnostics = report
                isTesting = false
            }
        }
    }

    private func scan() {
        isScanning = true
        Task {
            // Unicast subnet sweep: works without the multicast entitlement,
            // and finds hubs even after the router moves their address.
            let hubs = await BroadlinkDiscovery.scanSubnet()
            await MainActor.run {
                // Refresh the stored address of any already-paired hub that moved.
                for hub in hubs where store.hubs.contains(where: { $0.id == hub.id }) {
                    store.addHub(hub)
                }
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
