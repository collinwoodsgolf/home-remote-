import Foundation

/// The complete set of logical buttons that can appear on any remote in the
/// app. A given device only uses a subset (see `RemoteLayout`). Using a single
/// flat namespace keeps the learned-code dictionary and the network key-map
/// simple and stable across app versions.
enum RemoteButtonID: String, Codable, CaseIterable {
    // Universal power
    case power
    case powerOn
    case powerOff

    // Navigation / D-pad (Fire TV, projector menus)
    case up, down, left, right, select
    case back, home, menu

    // Playback transport
    case play, pause, playPause, stop, rewind, fastForward, previousTrack, nextTrack

    // Volume / audio
    case volumeUp, volumeDown, mute
    case bass, treble, bluetoothPairing, inputSource

    // Climate (Frigidaire AC)
    case tempUp, tempDown
    case modeCool, modeFan, modeEco, modeDry
    case fanLow, fanMedium, fanHigh, fanAuto
    case swing, timer, sleep

    // Projector specific
    case focusPlus, focusMinus
    case keystoneUp, keystoneDown
    case zoomIn, zoomOut

    // Fan specific
    case speedUp, speedDown
    case oscillate, naturalWind, sleepMode

    var label: String {
        switch self {
        case .power:           return "Power"
        case .powerOn:         return "On"
        case .powerOff:        return "Off"
        case .up:              return "Up"
        case .down:            return "Down"
        case .left:            return "Left"
        case .right:           return "Right"
        case .select:          return "OK"
        case .back:            return "Back"
        case .home:            return "Home"
        case .menu:            return "Menu"
        case .play:            return "Play"
        case .pause:           return "Pause"
        case .playPause:       return "Play / Pause"
        case .stop:            return "Stop"
        case .rewind:          return "Rewind"
        case .fastForward:     return "Forward"
        case .previousTrack:   return "Previous"
        case .nextTrack:       return "Next"
        case .volumeUp:        return "Vol +"
        case .volumeDown:      return "Vol –"
        case .mute:            return "Mute"
        case .bass:            return "Bass"
        case .treble:          return "Treble"
        case .bluetoothPairing:return "Pair"
        case .inputSource:     return "Source"
        case .tempUp:          return "Temp +"
        case .tempDown:        return "Temp –"
        case .modeCool:        return "Cool"
        case .modeFan:         return "Fan"
        case .modeEco:         return "Eco"
        case .modeDry:         return "Dry"
        case .fanLow:          return "Low"
        case .fanMedium:       return "Med"
        case .fanHigh:         return "High"
        case .fanAuto:         return "Auto"
        case .swing:           return "Swing"
        case .timer:           return "Timer"
        case .sleep:           return "Sleep"
        case .focusPlus:       return "Focus +"
        case .focusMinus:      return "Focus –"
        case .keystoneUp:      return "Keystone +"
        case .keystoneDown:    return "Keystone –"
        case .zoomIn:          return "Zoom +"
        case .zoomOut:         return "Zoom –"
        case .speedUp:         return "Speed +"
        case .speedDown:       return "Speed –"
        case .oscillate:       return "Oscillate"
        case .naturalWind:     return "Natural"
        case .sleepMode:       return "Sleep"
        }
    }

    /// Optional SF Symbol; nil means render the text label.
    var symbolName: String? {
        switch self {
        case .power, .powerOn, .powerOff: return "power"
        case .up:           return "chevron.up"
        case .down:         return "chevron.down"
        case .left:         return "chevron.left"
        case .right:        return "chevron.right"
        case .back:         return "arrow.uturn.left"
        case .home:         return "house.fill"
        case .menu:         return "line.3.horizontal"
        case .play:         return "play.fill"
        case .pause:        return "pause.fill"
        case .playPause:    return "playpause.fill"
        case .stop:         return "stop.fill"
        case .rewind:       return "backward.fill"
        case .fastForward:  return "forward.fill"
        case .previousTrack:return "backward.end.fill"
        case .nextTrack:    return "forward.end.fill"
        case .volumeUp:     return "speaker.wave.2.fill"
        case .volumeDown:   return "speaker.fill"
        case .mute:         return "speaker.slash.fill"
        case .bluetoothPairing: return "antenna.radiowaves.left.and.right"
        case .oscillate:    return "arrow.left.and.right"
        default:            return nil
        }
    }
}
