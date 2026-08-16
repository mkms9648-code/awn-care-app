# Awn Care

Personal assistant mobile app for resident physicians — replaces Telegram bot workflows with a structured Flutter app connected to your existing Supabase + n8n backend.

## Features

- **Login** — 6-digit entry code (physician identity for all API calls)
- **Chat** — ED / Rounds threads with voice, text, and photo input; review cards before save
- **ED Board** — Live patient card board with filters and pull-to-refresh
- **Rounds Board** — Same board component, `bot_key=round` data source
- **Analytics** — Coming soon placeholder
- **Profile** — Physician details, hospital, subscription status, logout
- **Dark Mode** — Follows system theme

## Quick Start (Demo Mode)

Demo mode is enabled by default (`AppConfig.useMockData = true`). No backend required.

```bash
flutter pub get
flutter run
```

Sign in with any 6-digit code (e.g. `123456`).

### Try in Chat

- Type **"new patient"** or **"admit"** → review card before save
- Type **"vitals"** or **"bp 120/80"** → vitals review card (not recorded until confirmed)
- Tap **mic** → voice message
- Tap **attach** → camera or gallery photo

## Production Setup

1. Open `lib/config/app_config.dart` and set:

```dart
static const bool useMockData = false;
```

2. Pass credentials at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=ED_WEBHOOK_URL=https://your-n8n/webhook/ed \
  --dart-define=ROUNDS_WEBHOOK_URL=https://your-n8n/webhook/round
```

## Integration Contracts

### Reading (Supabase RPC)

All RPCs use fixed first parameters: `platform='mobile'`, `bot_key`, `chat_id=entry_code`.

| Function | Purpose |
|---|---|
| `app_resolve_staff` | Login + Profile |
| `app_encounter_list` | ED / Rounds boards (`bot_key`: `ed` or `round`) |
| `app_patient_summary` | Patient detail screen |
| `app_vitals_series` | Vital charts |

### Writing (n8n Webhook)

```json
{
  "chat_id": "physician_code",
  "bot_key": "ed or round",
  "type": "text or voice or photo",
  "text": "...",
  "audio_storage_path": "...",
  "photo_storage_path": "...",
  "caption": "..."
}
```

Voice/photo files upload to Supabase Storage bucket `attachments` first; only `storage_path` is sent to the webhook.

### Security Rules (preserved in app)

- Vitals are not shown as recorded until server confirms via review card
- New patients require explicit review card confirmation
- No direct delete/edit — corrections are new events
- UI always reflects server responses, never assumes success

## Project Structure

```
lib/
├── config/          App configuration & integration constants
├── models/          Data models matching backend contracts
├── providers/       State management (auth, chat, boards)
├── screens/         All app screens
├── services/        Supabase RPC, webhooks, auth, mock data
├── theme/           Light / dark medical theme
└── widgets/         Reusable UI components
```

## Requirements

- Flutter 3.16+ / Dart 3.2+
- iOS 12+ / Android API 21+
- Microphone and camera permissions (configured in platform manifests)
