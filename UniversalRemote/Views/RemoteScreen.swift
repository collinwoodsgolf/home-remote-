import SwiftUI
import UIKit

/// Generic remote face. Renders whatever `RemoteLayout` the device declares, so
/// every device (Fire TV, AC, projector, fan, speaker) reuses this one screen.
struct RemoteScreen: View {
    let deviceID: UUID

    @EnvironmentObject private var store: DeviceStore
    @EnvironmentObject private var controller: RemoteController
    @State private var showingSettings = false

    private var device: Device? { store.devices.first(where: { $0.id == deviceID }) }

    var body: some View {
        Group {
            if let device {
                content(for: device)
            } else {
                ContentUnavailableView("Device removed", systemImage: "exclamationmark.triangle")
            }
        }
    }

    @ViewBuilder
    private func content(for device: Device) -> some View {
        let layout = RemoteLayout.layout(for: device.kind)
        ScrollView {
            VStack(spacing: 16) {
                if needsSetup(device) {
                    SetupBanner(device: device)
                }
                ForEach(layout.rows) { row in
                    if row.isDPad {
                        DPadRow(buttons: row.buttons, device: device)
                    } else {
                        HStack(spacing: 12) {
                            ForEach(row.buttons, id: \.self) { button in
                                buttonView(button, device: device)
                            }
                        }
                    }
                }

                if device.kind == .fireTV {
                    AppShortcutsGrid(device: device)
                }
            }
            .padding()
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $showingSettings) {
            DeviceSettingsView(deviceID: device.id)
        }
        .overlay(alignment: .bottom) {
            if let error = controller.lastError {
                ErrorToast(message: error)
                    .padding(.bottom, 12)
            }
        }
    }

    private func buttonView(_ button: RemoteButtonID, device: Device) -> some View {
        RemoteButtonView(
            button: button,
            isConfigured: device.canSend(button),
            isBusy: controller.busyButton == button
        ) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            controller.press(button, on: device)
        }
    }

    private func needsSetup(_ device: Device) -> Bool {
        switch device.transport {
        case .network: return (device.networkHost ?? "").isEmpty
        case .infrared: return store.hub(for: device) == nil || device.learnedCodes.isEmpty
        }
    }

    @ViewBuilder
    private func DPadRow(buttons: [RemoteButtonID], device: Device) -> some View {
        HStack {
            Spacer()
            HStack(spacing: 12) {
                ForEach(buttons, id: \.self) { button in
                    buttonView(button, device: device)
                }
            }
            Spacer()
        }
    }
}

private struct SetupBanner: View {
    let device: Device
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
            Text(device.transport == .network
                 ? "Add this Fire TV's IP address in settings to enable control."
                 : "Pair an IR hub and learn buttons from your physical remote (gear icon).")
                .font(.footnote)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// One-tap streaming app launchers, shown only for the Fire TV.
private struct AppShortcutsGrid: View {
    let device: Device
    @EnvironmentObject private var controller: RemoteController

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apps")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(FireTVAppShortcut.defaults) { shortcut in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        controller.launchApp(shortcut, on: device)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: shortcut.symbol)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(shortcut.tint)
                            Text(shortcut.name)
                                .font(.caption2)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .padding(.top, 8)
    }
}

private struct ErrorToast: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.red.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
            .shadow(radius: 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
