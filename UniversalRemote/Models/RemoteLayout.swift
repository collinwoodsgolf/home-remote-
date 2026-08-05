import Foundation

/// Declarative description of a remote face: an ordered list of rows, each row
/// holding one or more buttons. Views render this generically so adding a new
/// device is just data, not new UI code.
struct RemoteLayout {
    struct Row: Identifiable {
        let id = UUID()
        let buttons: [RemoteButtonID]
        /// When true the row is rendered as a centered D-pad cluster.
        var isDPad: Bool = false
    }

    let rows: [Row]

    static func layout(for kind: DeviceKind) -> RemoteLayout {
        switch kind {
        case .fireTV:          return fireTV
        case .tclSpeaker:      return tclSpeaker
        case .frigidaireAC:    return frigidaireAC
        case .yaberProjector:  return yaberProjector
        case .towerFan:        return towerFan
        case .projectorScreen: return projectorScreen
        }
    }

    // MARK: - Per-device faces

    static let fireTV = RemoteLayout(rows: [
        Row(buttons: [.power]),
        Row(buttons: [.up], isDPad: true),
        Row(buttons: [.left, .select, .right], isDPad: true),
        Row(buttons: [.down], isDPad: true),
        Row(buttons: [.back, .home, .menu]),
        Row(buttons: [.rewind, .playPause, .fastForward]),
        Row(buttons: [.volumeDown, .mute, .volumeUp]),
    ])

    static let tclSpeaker = RemoteLayout(rows: [
        Row(buttons: [.power]),
        Row(buttons: [.previousTrack, .playPause, .nextTrack]),
        Row(buttons: [.volumeDown, .mute, .volumeUp]),
        Row(buttons: [.bass, .treble]),
        Row(buttons: [.inputSource, .bluetoothPairing]),
    ])

    static let frigidaireAC = RemoteLayout(rows: [
        Row(buttons: [.power]),
        Row(buttons: [.tempDown, .tempUp]),
        Row(buttons: [.modeCool, .modeFan, .modeEco, .modeDry]),
        Row(buttons: [.fanLow, .fanMedium, .fanHigh, .fanAuto]),
        Row(buttons: [.swing, .timer, .sleep]),
    ])

    static let yaberProjector = RemoteLayout(rows: [
        Row(buttons: [.power]),
        Row(buttons: [.up], isDPad: true),
        Row(buttons: [.left, .select, .right], isDPad: true),
        Row(buttons: [.down], isDPad: true),
        Row(buttons: [.back, .home, .menu]),
        Row(buttons: [.playPause, .stop, .inputSource]),
        Row(buttons: [.focusMinus, .focusPlus]),
        Row(buttons: [.keystoneDown, .keystoneUp]),
        Row(buttons: [.zoomOut, .zoomIn]),
        Row(buttons: [.volumeDown, .mute, .volumeUp]),
    ])

    static let towerFan = RemoteLayout(rows: [
        Row(buttons: [.power]),
        Row(buttons: [.speedDown, .speedUp]),
        Row(buttons: [.oscillate, .naturalWind]),
        Row(buttons: [.timer, .sleepMode]),
    ])

    // The auto-lower control is rendered separately (ScreenControl); these are
    // the raw Up/Stop/Down keys used for learning and manual nudging.
    static let projectorScreen = RemoteLayout(rows: [
        Row(buttons: [.screenUp, .screenStop, .screenDown]),
    ])
}
