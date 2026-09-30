# Bug fixes applied

- Registration failures are now surfaced to the player instead of silently continuing.
- Answer selection immediately locks the question timer, preventing answer/timeout double penalties.
- Admin pause now freezes the global game timer and per-question timer.
- Anti-cheat visibility handling does not consume a lifeline while the game is paused.
- Removed the broken temporary-camera flashlight implementation, which could leak/compete with the QR scanner camera stream.

## Important remaining deployment/security issue

The current Supabase setup allows anonymous read/write access, and admin/game passwords are client-side constants. That means the admin controls and scores are not truly secure against a determined participant. A production event should move privileged operations and answer/score validation to a server-side Supabase Edge Function/RPC with appropriate RLS policies.
