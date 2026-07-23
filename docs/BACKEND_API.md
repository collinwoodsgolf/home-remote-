# Backend API Contract

The iOS app's `LiveBackendService` is coded against this REST API. Base URL: `AppConfig.apiBaseURL` (e.g. `https://api.collinwoodsgolf.com/v1/`). All requests and responses are JSON with ISO-8601 dates. Authenticated endpoints take `Authorization: Bearer <token>`.

Any stack works (Node/Express, FastAPI, Rails, Supabase edge functions). The backend owns all third-party credentials — the app never holds the Acuity API key, LLM key, or integration secrets.

## Auth — matched to Acuity

Accounts are keyed to the Acuity Scheduling client list, so signing in *is* linking to the Acuity account.

| Endpoint | Body | Behavior |
|---|---|---|
| `POST auth/request-code` | `{ "email" }` | Look up the email in Acuity (`GET /api/v1/clients`). If found, email a 6-digit one-time code. If not found, still return 200 (don't leak the client list) but send an "ask about lessons" email instead. |
| `POST auth/verify` | `{ "email", "code" }` | Verify code → `{ "token", "client": Client }`. `Client.membership` is derived from an Acuity tag/label or membership product on the client record (`member` / `non_member`). |
| `GET me` | — | Current `Client` or 401. |

`Client`: `{ id, firstName, lastName, email, phone?, membership, acuityClientID?, ghinNumber?, homeClub?, referralCode }`

## Booking (Acuity proxy)

| Endpoint | Behavior |
|---|---|
| `GET booking/appointment-types?tier=` | Acuity `GET /appointment-types`, mapped to `AppointmentType[]`. Types tagged member-only in Acuity get `memberOnly: true`; the server filters what guests see. |
| `GET booking/availability?typeID=&date=YYYY-MM-DD` | Acuity `GET /availability/times` → `TimeSlot[]`. |
| `POST booking/book` `{ appointmentTypeID, start }` | Acuity `POST /appointments` on behalf of the signed-in client → `Booking`. Acuity sends its own confirmation email. |
| `GET booking/upcoming` | Client's future Acuity appointments → `Booking[]`. |
| `POST booking/{id}/cancel` | Acuity cancel → `{}`. |

## Lessons

| Endpoint | Behavior |
|---|---|
| `GET lessons` | `Lesson[]`, newest first. Lessons are created from completed Acuity appointments; notes and videos are attached by the agents (see AGENTS.md). |

`Lesson`: `{ id, date, title, location, focusAreas[], note?: { summary, keyTakeaways[], homework[], source, transcriptURL? }, videos[]: { id, title, angle, url, thumbnailURL?, capturedAt, source } }`

Video `url`s should be short-lived signed URLs (S3/GCS) minted per request.

## Chat

| Endpoint | Behavior |
|---|---|
| `GET chat/{coach\|caddie}/messages` | `ChatMessage[]` for that thread. |
| `POST chat/coach/messages` `{ text }` | Store + push-notify the coach (coach replies from an admin surface). Returns updated thread. |
| `POST chat/caddie/messages` `{ text }` | Run the LLM (Claude API recommended) with a system prompt assembled from: the student's `GameMemoryFact[]`, recent lesson notes, and recent rounds. After replying, extract any new durable facts and upsert them into memory. Returns updated thread including the AI reply. |
| `GET ai/memory` | `GameMemoryFact[]` — the caddie's persistent knowledge of the student's game, shown to the student for transparency. |

## Drills

| Endpoint | Behavior |
|---|---|
| `GET drills` | `Drill[]` from a CMS table the coach edits (adding a row publishes to all students instantly — no app release). |

## Game tracking

| Endpoint | Behavior |
|---|---|
| `PUT game/ghin` `{ ghinNumber }` | Save on client, trigger a GHIN sync → updated `Client`. |
| `GET game/handicap-history` | `HandicapEntry[]` (date, index, source). |
| `GET game/rounds` | `RoundSummary[]` merged from all connected sources, deduped by date+course. |
| `GET game/integrations` | `IntegrationConnection[]` for GHIN, Arccos, UpGame, TheGrint. |
| `PUT game/integrations/{provider}` `{ connected }` | Connect/disconnect. For providers needing OAuth, respond with an auth URL for the app to open; store tokens server-side. |

## Referrals

| Endpoint | Behavior |
|---|---|
| `GET referrals` | `ReferralStatus`: `{ code, invitesSent, lessonsBooked, rewardsEarned, pending[] }`. Attribution: new Acuity bookings carry the code via a custom intake form field; a nightly job matches codes → credits the referrer. |

## Errors

Non-2xx responses use `{ "error": { "code", "message" } }`. The app currently treats any non-2xx as a generic failure, so no specific codes are required to launch.
