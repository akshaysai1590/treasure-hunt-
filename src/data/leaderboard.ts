export interface LeaderboardEntry {
  username: string;
  score: number;
  timeSeconds: number;
  isCurrentUser?: boolean;
}

export const sampleLeaderboard: LeaderboardEntry[] = [
  { username: "Rahul", score: 120, timeSeconds: 475 },
  { username: "Sneha", score: 110, timeSeconds: 500 },
  { username: "Arjun", score: 95, timeSeconds: 550 },
  { username: "Priya", score: 85, timeSeconds: 420 },
  { username: "Kiran", score: 80, timeSeconds: 610 },
];

export function rankLeaderboard(entries: LeaderboardEntry[]): (LeaderboardEntry & { rank: number })[] {
  const sorted = [...entries].sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.timeSeconds - b.timeSeconds;
  });
  return sorted.map((entry, i) => ({ ...entry, rank: i + 1 }));
}

export function formatTime(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}
