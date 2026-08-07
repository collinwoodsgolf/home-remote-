import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Home screen: one-tap scenes, a grid of the user's devices, and an entry
/// point to hub setup.
struct ContentView: View {
    @EnvironmentObject private var store: DeviceStore
    @EnvironmentObject private var controller: RemoteController

    @State private var showingImporter = false
    @State private var importMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !store.scenes.isEmpty {
                        ScenesRow()
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.devices) { device in
                            NavigationLink(value: device) {
                                DeviceTile(device: device)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Remotes")
            .navigationDestination(for: Device.self) { device in
                RemoteScreen(deviceID: device.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let url = store.exportFileURL() {
                            ShareLink(item: url) {
                                Label("Export Setup…", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button {
                            showingImporter = true
                        } label: {
                            Label("Import Setup…", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HubSetupView()
                    } label: {
                        Image(systemName: "wifi.router")
                    }
                }
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        try store.importBackup(from: url)
                        importMessage = "Setup imported — all devices, learned buttons, hub, and scenes are ready."
                    } catch {
                        importMessage = "Import failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    importMessage = "Import failed: \(error.localizedDescription)"
                }
            }
            .alert("Import Setup", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
        }
    }
}

/// Horizontal row of one-tap scene chips.
private struct ScenesRow: View {
    @EnvironmentObject private var store: DeviceStore
    @EnvironmentObject private var controller: RemoteController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scenes")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.scenes) { scene in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            controller.runScene(scene)
                        } label: {
                            HStack(spacing: 8) {
                                if controller.runningSceneID == scene.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: scene.symbol)
                                }
                                Text(scene.name).font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(.blue.opacity(0.16),
                                        in: Capsule())
                            .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(controller.runningSceneID != nil)
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
