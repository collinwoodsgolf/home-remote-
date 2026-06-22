import SwiftUI

/// A single tactile remote key. Shows a symbol or text label, a busy spinner
/// while a command is in flight, and a subtle "not configured" treatment when
/// no code/handler is available yet.
struct RemoteButtonView: View {
    let button: RemoteButtonID
    let isConfigured: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView()
                } else if let symbol = button.symbolName {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                } else {
                    Text(button.label)
                        .font(.system(size: 15, weight: .semibold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 64, minHeight: 56)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isConfigured ? Color.clear : Color.orange.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [4]))
            )
            .opacity(isConfigured ? 1 : 0.55)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isBusy)
    }
}

/// Adds a quick scale-down on press for a physical feel.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
