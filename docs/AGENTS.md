# Automation Agents

How lesson notes and swing videos get into each student's app **with zero manual uploads**, plus the recurring sync jobs. These run server-side alongside the API in BACKEND_API.md.

## 1. Plaud → lesson notes

Goal: the coach records the lesson on a Plaud device; a polished note appears in the student's lesson history automatically.

Pipeline (runs on a webhook or a 15-minute poll of the Plaud/cloud export):

1. **Ingest** — new Plaud recording lands (Plaud app auto-sync to cloud folder, or Plaud API/Zapier export). Capture audio + Plaud's transcript if present.
2. **Match to lesson** — find the Acuity appointment whose time window overlaps the recording's start time. That appointment identifies the student and creates the `Lesson` row if it doesn't exist.
3. **Summarize** — send the transcript to the LLM with a fixed prompt: produce `summary` (2–4 sentences, student-facing tone), `keyTakeaways[]`, `homework[]`, and suggested `focusAreas[]`.
4. **Review gate (recommended)** — post the draft note to the coach (email/Slack/admin page) with one-tap approve; auto-publish after 24h if untouched. Skippable once trust is established.
5. **Publish** — attach `LessonNote` to the lesson, feed the takeaways into the student's `GameMemoryFact` store, and send the student a push/email: "Your notes from Tuesday's lesson are ready."

## 2. Swing Catalyst → lesson videos

Goal: videos captured during the session show up under that lesson.

1. **Ingest** — Swing Catalyst Cloud: poll the studio account's recent activities per student (or use its export/share integration) for new videos.
2. **Match** — Swing Catalyst student profile ↔ app client (match once by email/name, store the mapping). Assign each video to the lesson whose date matches its capture date.
3. **Store** — copy to your own bucket (S3/GCS) so app playback uses your signed URLs and survives changes to the Swing Catalyst account; keep `angle` ("Face On" / "Down the Line") from the capture metadata or filename convention.
4. **Publish** — append `SwingVideo` rows to the lesson. Same notification as notes (batch them if both land together).

## 3. Integration syncs (nightly + on-connect)

| Provider | Method | Data pulled |
|---|---|---|
| GHIN | GHIN API (USGA admin/club access) or scheduled scrape of the public lookup by GHIN number | Handicap index history, score postings |
| Arccos | Arccos API (coach/partner program) | Rounds, strokes-gained summaries |
| UpGame | Coach account export/API | Practice + performance stats |
| TheGrint | User-authorized access | Rounds, stats |

Each sync writes `HandicapEntry` / `RoundSummary` rows (deduped by source ID) and appends notable changes to `GameMemoryFact` (e.g. "Index dropped to 7.2 on Jul 18") so the AI caddie stays current.

## 4. Referral attribution (nightly)

Scan new Acuity appointments for a referral code in the intake form field → mark the invite converted, increment the referrer's reward, notify the coach when a reward threshold is hit.

## Build notes

- All agents are idempotent (keyed on source IDs) so re-runs are safe.
- A single scheduled worker (Cloud Run job / cron on the API server) covering steps 1–4 is enough at this scale; no queue infrastructure needed to start.
- Keep every third-party credential server-side; the iOS app only ever sees finished `Lesson`, `Round`, and memory data.
