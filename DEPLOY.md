# Deployment Runbook

Follow these instructions to deploy the treasure hunt game securely for a live event.

## 1. Database Setup (Supabase)
1. Create a new Supabase project.
2. In the SQL Editor, execute the following migration files in order:
   - `supabase/migrations/20261001000000_schema.sql`
   - `supabase/migrations/20261001000001_rpcs_auth.sql`
   - `supabase/migrations/20261001000002_rpcs_game.sql`
   - `supabase/migrations/20261001000003_rpcs_scoring.sql`
   - `supabase/migrations/20261001000004_rpcs_penalties.sql`
   - `supabase/migrations/20261001000005_rpcs_admin.sql`
3. Execute `supabase/seed.sql` to populate the initial tables.

## 2. Environment Variables
1. Obtain the **Project URL** and **anon public key** from your Supabase project settings.
2. Create a `.env` file (or set these in your hosting provider like Vercel):
   ```
   VITE_SUPABASE_URL=https://your-project-id.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-key
   ```

## 3. Realtime Configuration
- Ensure Realtime is enabled for the `game_state` table. The `20261001000000_schema.sql` migration attempts to configure this automatically via `ALTER PUBLICATION supabase_realtime ADD TABLE game_state;`.
- Verify in Supabase Dashboard -> Database -> Replication -> `game_state` should be enabled.

## 4. QR Code Generation
1. Before the event, change the passwords in `scripts/generate_qrs.js` (or run it to create `private-qrcodes/passwords.json` and edit that).
2. Remember to update the `qr_codes` table in the database with the hashed versions of these new passwords if you change them. By default, the DB is seeded with hashed versions of 'r1', 'r2', 'r3', 'r4'.
3. Run `node scripts/generate_qrs.js`. The QR codes will be saved in `private-qrcodes/`. Print them.

## 5. Build and Deploy
1. Run `npm install`.
2. Run `npm run build`. 
3. Deploy the `dist` directory to your hosting provider. (Sourcemaps are disabled in `vite.config.ts` to prevent code leaks).

## 6. Admin Panel
- Access `/admin`.
- Default password is `admin` (change this by hashing a new password and updating `game_config.admin_password_hash` in the DB).
- You can reset the game, pause it, adjust scores, and send broadcasts.

## 7. Pre-Event Checklist
- [ ] Database migrated and seeded.
- [ ] Passwords changed in DB (`game_config` entry and admin).
- [ ] QR Codes generated, printed, and placed at locations.
- [ ] Realtime is working (test by pausing the game in Admin).
- [ ] Frontend successfully built and deployed without sourcemaps.
- [ ] Test a full run through to ensure RPCs and Idempotency keys are working correctly under network throttling.
