# 🏴‍☠️ Treasure Hunt — Technical Event Platform

A secure, mobile-first, QR-based treasure hunt game designed for college technical competitions. Players scan physical QR codes at checkpoints, solve timed technical challenges, and compete on a live server-authoritative leaderboard.

**Tech Stack:**
- **Frontend:** React 18 + Vite 5 + TypeScript + Tailwind CSS + shadcn/ui
- **Backend & Database:** Supabase (PostgreSQL with server-side RPC functions & Realtime subscriptions)
- **Deployment:** Vercel

---

## ⚡ Quick Start

### 1. Installation
```sh
npm install
```

### 2. Environment Variables
Create `.env` in the project root (see `.env.example`):
```env
VITE_SUPABASE_URL=https://your-supabase-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
```

### 3. Local Development
```sh
npm run dev
```
Open `http://localhost:8080` (or the port specified in terminal).

### 4. Running Checks & Tests
```sh
# Type check
npx tsc --noEmit

# Linting
npm run lint

# Unit tests
npm run test

# Production build
npm run build
```

---

## 🔐 Credentials & Default Access

The database is seeded with the following default configuration:

| Interface | URL Path | Credential | Value |
|---|---|---|---|
| **Player Login** | `/` | Game Password | `player` |
| **Player Login** | `/` | Username | Unique per player |
| **Admin Console** | `/admin` | Admin Password | `admin` |
| **Round 1 QR** | Checkpoint 1 | QR Code | `r1` |
| **Round 2 QR** | Checkpoint 2 | QR Code | `r2` |
| **Round 3 QR** | Checkpoint 3 | QR Code | `r3` |
| **Round 4 QR** | Checkpoint 4 | QR Code | `r4` |

---

## 🎮 Game Architecture & Anti-Cheat

1. **Server-Authoritative Validation:**
   - Question fetching, answer scoring, and time tracking are enforced via PostgreSQL stored procedures (`submit_answer`, `verify_qr`, `report_timeout`).
   - Answers and hints are never exposed in client bundles.
2. **Anti-Cheat Focus Detection:**
   - Detects when players switch tabs or minimize the browser window.
   - Triggers server-side lifeline deductions for unauthorized app switching.
3. **Double-Submit & Race Condition Protection:**
   - UI locks submissions and uses idempotent submission keys to prevent rapid double-clicks.
   - Camera scanner implements debounce locks to prevent multiple duplicate scans.
4. **Realtime God Mode (Admin):**
   - Live Pause / Resume game for all players via Supabase Realtime channels.
   - Live Broadcast announcements displayed across all active client screens.
   - Manual score adjustments and game reset options.

---

## 🚢 Deployment to Vercel

1. Push your repository to GitHub.
2. Import the repository in [vercel.com/new](https://vercel.com/new).
3. Set the Environment Variables in Vercel Project Settings:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
4. Deploy!

The application includes `vercel.json` configured for SPA routing (`rewrites: [ { "source": "/(.*)", "destination": "/index.html" } ]`).
