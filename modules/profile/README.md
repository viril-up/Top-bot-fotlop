# Viril — Profile module

This folder contains the profile screen's presentation and isolated UI behavior.

## Files
- `profile.css` — profile cover, profile cards, FAQ and contact-row styles.
- `profile.js` — FAQ open/close behavior and keyboard accessibility.
- `splash.css` / `splash.js` — app launch screen only.

## Profile features currently present in the app
1. Edit profile (nickname and avatar).
2. Sign out / switch user.
3. Settings.
4. FAQ (starter questions; extend the existing `details` entries).
5. Support email: VirilSupport@gmail.com.
6. Telegram manager: https://t.me/virilgo.
7. Existing league, progress, reset-progress and account-delete entries are preserved.

## Safety of future changes
The main application currently owns authentication, Supabase calls, user state,
profile saving, settings modal, progress reset and account deletion. Those
handlers stay in the main app because they depend on shared state and auth.
Do not duplicate them here or remove their existing element IDs. This keeps
the module isolated without changing the app's existing data/auth flow.
