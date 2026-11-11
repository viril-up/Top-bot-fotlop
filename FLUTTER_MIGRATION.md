# Viril Flutter migration

The Flutter rewrite lives in `flutter_app/` on branch `flutter-v2`. The current production web app remains at the repository root on `main`.

The current application is not a simple static page: the legacy source contains local XP/level/streak/history state, Supabase anonymous sessions and Google identity linking, profile RPCs, a world leaderboard, a training iframe integration, a resource library, and cloud book loading. These integrations must be ported deliberately and tested against the existing Supabase schema. The migration must not reset user accounts or overwrite the production app.

See [flutter_app/README.md](flutter_app/README.md) for the staged feature-parity checklist.
