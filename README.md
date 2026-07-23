# Collin Woods Golf — iOS App

Branded client app for [Collin Woods Golf](https://www.collinwoodsgolf.com) — executive golf coaching at NEXUS Golf Club, Manhattan.

## Features

| Feature | Status | Where |
|---|---|---|
| Sign-in linked to Acuity account (email + one-time code) | UI complete, mock auth | `Features/Auth` |
| Home screen with member / non-member lesson booking via Acuity | UI complete, mock data | `Features/Home`, `Features/Booking` |
| Embedded full Acuity scheduler (WebView fallback) | Working (needs owner ID) | `Features/Booking/AcuityWebView.swift` |
| Lesson history with auto-uploaded Plaud notes + Swing Catalyst videos | UI complete, mock data | `Features/Lessons` |
| Direct chat with Coach Woods | UI complete, mock data | `Features/Chat` |
| AI caddie chat with persistent memory of the student's game | UI complete, mock replies | `Features/Chat` |
| Drill video library (remote content, updatable without app release) | UI complete, mock data | `Features/Drills` |
| GHIN number entry + handicap trend chart + recent rounds | UI complete, mock data | `Features/MyGame` |
| Integrations: GHIN, Arccos, UpGame, TheGrint | Connect/disconnect UI, mock | `Features/MyGame` |
| Referral portal (code, share sheet, reward tracking) | UI complete, mock data | `Features/Referrals` |

The app runs fully on sample data today (`AppConfig.useMockData = true`), so every screen is navigable in the simulator with no backend. All real functionality goes through one protocol (`BackendService`) with a live HTTP implementation already written against the API contract in [`docs/BACKEND_API.md`](docs/BACKEND_API.md).

## Getting started

1. Open `CollinWoodsGolf.xcodeproj` in **Xcode 16 or later**.
2. Select an iPhone simulator and run. You can sign in with any email and any code while mock mode is on.
3. To go live later: deploy the companion backend, set `AppConfig.apiBaseURL`, set your Acuity owner ID in `AppConfig.acuityOwnerID`, and flip `AppConfig.useMockData` to `false`.

## Architecture

```
CollinWoodsGolf/
├── App/         entry point, session store, tab navigation
├── Theme/       brand system (pine green / cream / gold) + reusable components
├── Models/      shared domain models (Client, Lesson, Drill, …)
├── Services/    BackendService protocol, live HTTP client, mock backend, config
└── Features/    one folder per screen area (Auth, Home, Booking, Lessons,
                 Chat, Drills, MyGame, Referrals, Profile)
```

- **SwiftUI + Observation**, iOS 17+, no third-party dependencies.
- **Acuity** is never called directly from the app — the backend proxies it with the API key so member/non-member appointment types, availability, and booking stay server-controlled (see docs).
- **Plaud notes and Swing Catalyst videos** are pushed into lesson history automatically by backend agents — the flow is specified in [`docs/AGENTS.md`](docs/AGENTS.md).
- **AI caddie memory** lives server-side (`/ai/memory`) so it persists across devices and can be enriched from lesson notes and synced rounds.

## Docs

- [`docs/BACKEND_API.md`](docs/BACKEND_API.md) — full endpoint contract the app is coded against.
- [`docs/AGENTS.md`](docs/AGENTS.md) — the Plaud → notes and Swing Catalyst → video automation pipelines, plus integration sync jobs (GHIN, Arccos, UpGame, TheGrint).
