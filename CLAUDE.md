# Project notes for Claude

## Owner / environment
- The user has a **paid Apple Developer Program membership ($99/yr)**, active.
  Real-device deployment, managed entitlements (multicast/networking),
  TestFlight, and App Store distribution are all available. Keep the multicast
  entitlement in the project; don't strip it for free-provisioning.

## What this repo is
Universal Remote — a SwiftUI iOS app that controls the user's home devices:
Amazon Fire TV Stick (Wi‑Fi/ADB), and via a Broadlink Wi‑Fi→IR/RF hub: Yaber
projector, Frigidaire window AC, TCL speaker, Drew tower fan, and a motorized
projector screen (one‑tap lower with calibrated auto‑stop at the endpoint).

## Conventions
- Adding a device = data: a `DeviceKind`, a `RemoteLayout`, and (for network
  devices) a key map. The generic `RemoteScreen` renders any device.
- Persisted models decode defensively (`decodeIfPresent`) so new fields don't
  break previously‑saved data.
