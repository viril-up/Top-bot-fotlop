# Viril 2.0 — Flutter migration

This directory is the isolated Flutter implementation. The existing HTML/Capacitor app at the repository root remains unchanged and is still the production fallback.

## Run locally
```bash
cd flutter_app
flutter pub get
flutter run
```

## Supabase configuration
The current web app uses Supabase Auth (anonymous sessions + Google identity linking), profile RPCs, cloud state sync, and a leaderboard. Do not hardcode secrets. The Flutter integration will use build-time values:
```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```
The public/anon key is not a service-role secret. Never place a service-role key in a mobile app.

## Migration plan
- [x] Create an isolated Flutter/Dart application shell and module boundaries.
- [ ] Port the existing XP/level/streak/goals state model and local persistence.
- [ ] Port Supabase anonymous auth, Google identity linking, profile sync, leaderboard RPCs and account deletion flow.
- [ ] Port resources and the offline FB2/PDF/EPUB reader; preserve book files and metadata.
- [ ] Port training catalog/programs and import the full exercise animation archive.
- [ ] Port diary, Pomodoro/focus, analytics, history, settings, localization and profile cover/avatar.
- [ ] Add asset migration, Android app icon/splash screen and release build validation.
- [ ] Run parity tests against the current web version before replacing any production workflow.

## Current status
This is the first migration foundation, not a feature-complete replacement yet. Several screens intentionally show migration placeholders. Keep production on the current main branch until feature parity and APK testing are complete.
