# 🏴‍☠️ Treasure Hunt — Technical Event Game

A mobile-first, QR-based treasure hunt game built for college technical events. Players scan QR codes at physical locations, answer questions across 4 rounds, and compete on a live leaderboard.

**Built with:** React + Vite + TypeScript + Tailwind CSS + shadcn/ui + Supabase

---

## 🚀 Setup Instructions

### 1. Clone & Install

```sh
git clone <YOUR_GIT_URL>
cd treasure-hunt
npm install
```

### 2. Set up Supabase (Database)

1. Create a free project at [supabase.com](https://supabase.com)
2. Go to **Project Settings → API** and copy your **Project URL** and **anon key**
3. In your Supabase dashboard, go to **SQL Editor** and run:

```sql
CREATE TABLE participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL,
  score INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT false,
  completion_time INTEGER
);

-- Enable Row Level Security
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

-- Allow anonymous read/write (needed for the game)
CREATE POLICY "Allow all" ON participants FOR ALL USING (true) WITH CHECK (true);
```

4. Create a `.env` file in the project root (copy from `.env.example`):

```
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

### 3. Customize for Your Event

Before the event, update these files:

| What to Change | File | What to Do |
|----------------|------|------------|
| **Game entry password** | `src/components/screens/LoginScreen.tsx` | Change `GAME_PASSWORD` constant |
| **Admin panel password** | `src/pages/Admin.tsx` | Change `ADMIN_PASSWORD` constant |
| **Location hints/riddles** | `src/data/questions.ts` | Update `locationHints` array with your campus-specific clues |
| **QR code passwords** | `src/data/questions.ts` | Update `roundPasswords` object |
| **QR code passwords** | `scripts/generate_qrs.js` | Update passwords (must match questions.ts!) |

### 4. Generate QR Codes

After updating the passwords, generate the QR code images:

```sh
node scripts/generate_qrs.js
```

Print the generated QR codes from `public/qrcodes/` and place them at your event locations.

### 5. Run the Game

```sh
npm run dev
```

The game will be available at `http://localhost:5173`. Players access it on their phones.

### 6. Deploy (Optional)

Deploy to Vercel for a public URL players can access:

```sh
npm run build
# Deploy the dist/ folder to Vercel, Netlify, or any static host
```

A `vercel.json` is already included for SPA routing.

---

## 🎮 How It Works

- **Login Screen** — Players enter their username + event password to join
- **QR Scan** — Players scan a physical QR code to unlock each round
- **4 Rounds** — Logic & Aptitude → Tech Riddles → Rapid Fire → DSA Challenge
- **Lifelines** — 4 lives; lose one for wrong answers or switching tabs (anti-cheat!)
- **Location Hints** — After each round, a riddle leads to the next QR code
- **Leaderboard** — Live scores synced via Supabase
- **Admin Panel** — Access at `/admin` to pause game, broadcast messages, adjust scores, and reset

---

## 📁 Project Structure

```
src/
├── components/
│   ├── screens/       # LoginScreen, QRScanScreen, RoundScreen, WinnerScreen, EliminatedScreen
│   └── ui/            # shadcn/ui components
├── context/           # GameContext (state management), SoundContext
├── data/              # Questions, location hints, passwords, leaderboard
├── hooks/             # Custom React hooks
├── lib/               # Supabase client, utilities
└── pages/             # Index, Admin, NotFound
scripts/
├── generate_qrs.js    # QR code image generator
└── generate_wallpapers.js  # SVG wallpaper generator
```

---

## 📝 Tips for Event Day

1. **Test everything** before the event — make sure QR scanning works on student phones
2. **Use the Admin panel** (`/admin`) to monitor scores, pause the game, and broadcast messages
3. **Print QR codes clearly** — make them big enough to scan from phone camera
4. **Set the game password** and share it verbally at the event start
5. **Keep the admin password** secret — only organizers should have it

Good luck with your event! 🎉
