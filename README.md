# Universal Remote (iOS)

A SwiftUI iPhone/iPad app that replaces the physical remotes for:

| Device | How it's controlled |
| --- | --- |
| **Amazon Fire TV Stick** | Directly over Wi‑Fi (ADB network control) |
| **Yaber Projector** | Infrared, via a Wi‑Fi → IR bridge |
| **Frigidaire Window AC** | Infrared, via a Wi‑Fi → IR bridge |
| **TCL Speaker** | Infrared, via a Wi‑Fi → IR bridge |
| **Drew Tower Fan** | Infrared, via a Wi‑Fi → IR bridge |
| **Projector Screen** | Infrared (or RF) hub — one‑tap lower with auto‑stop |

## Read this first — the IR reality

**iPhones do not have an infrared blaster.** Four of your five remotes
(projector, AC, speaker, fan) are infrared, so the app cannot beam to them by
itself. It drives them through a small, cheap Wi‑Fi → IR bridge that sits in the
room and re‑emits the codes:

- **Recommended hardware:** a **Broadlink RM4 Mini** (~$20) or RM Pro. These are
  Wi‑Fi IR blasters that can *learn* the codes straight from your existing
  remotes — a perfect match for "all of my current remotes."
- One hub in the room covers the projector, AC, speaker, and fan at once.

The **Fire TV Stick** is different: it's on your Wi‑Fi, so the app talks to it
directly with no extra hardware.

## One‑time setup

### 1. Pair the IR hub
1. Add the Broadlink hub to your Wi‑Fi once using the official Broadlink app
   (this is just to get it on the network).
2. Open Universal Remote → tap the **router icon** (top‑right) → **Scan for
   Hubs** → **Add**. The hub is auto‑assigned to all IR devices.
   - *Discovery uses a UDP broadcast and needs the multicast entitlement (see
     "Entitlements" below). If your build doesn't have it, you can still pair by
     entering the hub's IP — discovery is the only step that needs broadcast.*

### 2. Learn each IR button
For the projector / AC / speaker / fan: open the device → **gear icon** → tap a
button (e.g. *Power*) → point the real remote at the hub and press the matching
key. A green check means it's learned. Repeat for the buttons you use.

### 3. Set up the Fire TV
1. On the Fire TV: **Settings → My Fire TV → Developer Options → ADB Debugging =
   ON**.
2. Find its IP under **Settings → My Fire TV → About → Network**.
3. In the app: open the Fire TV → **gear icon** → enter the IP address.
4. First button press shows an *"Allow USB debugging?"* prompt **on the TV** —
   check "Always allow" and accept. After that it just works.

## How it works (architecture)

```
SwiftUI views ─► RemoteController ─┬─► BroadlinkHub  (IR: AES‑128 UDP protocol)
   (RemoteScreen renders a          │      • discovery, auth handshake
    declarative RemoteLayout)       │      • IR learn + IR send
                                    └─► FireTVController ─► ADBClient
                                           • RSA‑authenticated ADB over TCP
                                           • `input keyevent <N>`
```

- **`UniversalRemote/Models`** — `Device`, `DeviceKind`, `RemoteButtonID`,
  `RemoteLayout` (each remote face is just data), and `DeviceStore`
  (persistence via `UserDefaults`).
- **`UniversalRemote/Networking`** — the Broadlink protocol
  (`BroadlinkHub`, `BroadlinkDiscovery`, `AESCBC`), and the Fire TV path
  (`ADBClient`, `ADBKey`, `BigUInt` for the Android RSA public‑key encoding,
  `TCPChannel`/`UDPChannel`).
- **`UniversalRemote/Controllers`** — `RemoteController` routes a button press
  to IR or network; `FireTVController` maps buttons to Android key codes.
- **`UniversalRemote/Views`** — one generic `RemoteScreen` renders every
  device, plus settings, hub setup, and the IR‑learning flow.

Adding a new device later is mostly data: add a `DeviceKind`, a `RemoteLayout`,
and (for network devices) a key map.

## Build & run

1. Open `UniversalRemote.xcodeproj` in **Xcode 16+** (iOS 17 deployment target).
2. Select your team under **Signing & Capabilities** (bundle id
   `com.collinwoodsgolf.UniversalRemote` — change if needed).
3. Run on a real device on the **same Wi‑Fi** as your hub and Fire TV.
   (The Simulator can't reach LAN devices reliably and has no real network
   identity for ADB.)

### Entitlements
`SupportingFiles/UniversalRemote.entitlements` requests
`com.apple.developer.networking.multicast`, which iOS requires to broadcast the
discovery packet. It's an Apple‑managed entitlement — request it at
<https://developer.apple.com/contact/request/networking-multicast> and include
it in your provisioning profile. Everything except hub auto‑discovery works
without it (enter the hub IP manually).

## Notes & limitations

- **TCL speaker:** handled as IR here. Many TCL portable/soundbar speakers are
  Bluetooth‑only with no public control protocol; if yours has *no* IR remote,
  IR learning won't apply and you'd need its own app for transport control.
- **Fire TV power:** `KEYCODE_POWER` sleeps/wakes the device; full TV power
  depends on HDMI‑CEC support of your TV.
- **Scenes:** the home screen has one‑tap scene chips that chain actions across
  devices, with per‑step delays. Two are seeded — **Movie Night** (projector on
  → screen down → Fire TV) and **All Off** (screen up → projector/fan/AC off).
  Steps that reference a device you haven't set up are skipped safely. Scenes
  are stored in `DeviceStore` (`seedDefaultScenes`); a visual editor is a
  natural next addition.
- **Fire TV app shortcuts:** the Fire TV face includes one‑tap launchers
  (Netflix, Prime Video, YouTube, Disney+, Hulu, Spotify) that fire a launcher
  intent for the app's Fire OS package. Edit `FireTVAppShortcut.defaults` to add
  your own.
- **Projector screen (auto‑lower):** the screen face has one‑tap **Lower** /
  **Raise** that send the command and then automatically send **Stop** after a
  calibrated travel time, so the screen stops itself at the bottom/top endpoint
  — no need to watch it. Set the travel time under the gear icon (tap Lower,
  count the seconds to fully down, enter that). A live countdown and a manual
  **Stop Now** button are shown while it moves.
  - *Many motorized screens (e.g. the TP‑06RF, **315 MHz**) are **RF**, not IR.
    Turn on **RF remote** in the device's settings to use the two‑phase RF learn
    (hold the button to lock the frequency, then tap to capture). This needs an
    **RM4 Pro / RM Pro** (the RM4 **Mini** is IR‑only) **and a handheld RF
    transmitter to learn from** — an RF **receiver** box with local buttons
    emits nothing to capture.*
- The Broadlink implementation supports both the original RM mini/Pro framing
  and the RM4 generation (auto‑selected from the reported device type).
- Codes and hub pairings are stored locally on the device; nothing leaves your
  network.
