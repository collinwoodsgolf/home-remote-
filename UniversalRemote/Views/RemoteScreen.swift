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

                if device.kind == .projectorScreen {
                    ScreenControl(device: device)
                }

                if device.kind == .tclSpeaker {
                    VolumeSliderControl(device: device)
                }

                ForEach(layout.rows) { row in
                    // The speaker's Vol± keys are replaced by the slider above;
                    // they stay in the layout so Settings can still learn them.
                    let buttons = row.buttons.filter {
                        !(device.kind == .tclSpeaker && ($0 == .volumeUp || $0 == .volumeDown))
                    }
                    if !buttons.isEmpty {
                        if row.isDPad {
                            DPadRow(buttons: buttons, device: device)
                        } else {
                            HStack(spacing: 12) {
                                ForEach(buttons, id: \.self) { button in
                                    buttonView(button, device: device)
                                }
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

/// Percentage volume for IR speakers. IR is one-way, so this drives an assumed
/// level: dragging emits the matching number of Vol+/Vol− pulses, and the two
/// rails re-sync it — 0% floors the hardware, 100% pegs it (the TCL beeps at
/// max, confirming the sync).
private struct VolumeSliderControl: View {
    let device: Device
    @EnvironmentObject private var controller: RemoteController
    @State private var level: Double

    init(device: Device) {
        self.device = device
        _level = State(initialValue: Double(device.volumeLevel))
    }

    private var canAdjust: Bool { device.canSend(.volumeUp) && device.canSend(.volumeDown) }
    private var busy: Bool { controller.volumeBusy.contains(device.id) }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Volume", systemImage: "speaker.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Text("\(Int(level))%")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $level, in: 0...100, step: 1) { editing in
                if !editing {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    controller.setVolume(percent: Int(level), on: device)
                }
            }
            .disabled(!canAdjust || busy)
            Text(canAdjust
                 ? "Estimated level — drag to 0% or 100% to re-sync (max beeps)."
                 : "Learn Vol + and Vol – first (gear icon).")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: device.volumeLevel) { _, newLevel in
            if !busy { level = Double(newLevel) }
        }
    }
}

/// Primary control for a motorized projector screen: one-tap Lower/Raise that
/// automatically stops at the endpoint, with a live countdown and a manual Stop.
private struct ScreenControl: View {
    let device: Device
    @EnvironmentObject private var controller: RemoteController

    private var remaining: Int? { controller.screenCountdowns[device.id] }
    private var moving: Bool { remaining != nil }
    private var canLower: Bool { device.canSend(.screenDown) }
    private var canRaise: Bool { device.canSend(.screenUp) }
    private var total: Int { max(1, Int(device.screenTravelSeconds.rounded())) }

    var body: some View {
        VStack(spacing: 14) {
            if let remaining {
                VStack(spacing: 8) {
                    ProgressView(value: Double(total - remaining), total: Double(total))
                        .tint(.blue)
                    Text("Auto-stopping at the endpoint in \(remaining)s")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                bigButton(title: "Raise", system: "arrow.up.to.line",
                          enabled: canRaise && !moving) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    controller.raiseScreen(device)
                }
                bigButton(title: "Lower", system: "arrow.down.to.line",
                          enabled: canLower && !moving) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    controller.lowerScreen(device)
                }
            }

            if moving {
                Button(role: .destructive) {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    controller.stopScreen(device)
                } label: {
                    Label("Stop Now", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            if !canLower || !canRaise {
                Text("Learn the Raise / Stop / Lower keys from your screen's remote first (gear icon).")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func bigButton(title: String, system: String, enabled: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: system).font(.system(size: 30, weight: .semibold))
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(.blue.opacity(enabled ? 0.18 : 0.06),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(enabled ? Color.blue : Color.secondary)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
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
