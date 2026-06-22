import SwiftUI

/// Home screen: a grid of the user's devices plus an entry point to hub setup.
struct ContentView: View {
    @EnvironmentObject private var store: DeviceStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.devices) { device in
                        NavigationLink(value: device) {
                            DeviceTile(device: device)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Remotes")
            .navigationDestination(for: Device.self) { device in
                RemoteScreen(deviceID: device.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HubSetupView()
                    } label: {
                        Image(systemName: "wifi.router")
                    }
                }
            }
        }
    }
}

private struct DeviceTile: View {
    let device: Device

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: device.kind.symbolName)
                .font(.system(size: 38))
                .frame(height: 44)
            Text(device.name)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(device.transport == .network ? "Wi-Fi" : "Infrared")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
