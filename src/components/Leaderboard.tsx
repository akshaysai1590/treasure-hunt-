import { LeaderboardEntry, rankLeaderboard, formatTime } from "@/data/leaderboard";
import { Trophy } from "lucide-react";

const medalIcons = ["🥇", "🥈", "🥉"];

interface LeaderboardProps {
  entries: LeaderboardEntry[];
}

const Leaderboard = ({ entries }: LeaderboardProps) => {
  const ranked = rankLeaderboard(entries);

  return (
    <div className="w-full max-w-lg mx-auto">
      <div className="flex items-center gap-2 mb-4">
        <Trophy className="w-5 h-5 text-accent" />
        <h2 className="font-display text-sm gold-text tracking-wider">LEADERBOARD</h2>
      </div>
      <div className="glass-card rounded-lg neon-border overflow-hidden">
        <div className="grid grid-cols-[3rem_1fr_4rem_4rem] gap-1 px-4 py-2.5 border-b border-border text-xs text-muted-foreground font-display tracking-wider">
          <span>#</span>
          <span>Player</span>
          <span className="text-right">Score</span>
          <span className="text-right">Time</span>
        </div>
        {ranked.map((entry, i) => (
          <div
            key={entry.username}
            className={`grid grid-cols-[3rem_1fr_4rem_4rem] gap-1 px-4 py-3 text-sm transition-all duration-500 ${
              entry.isCurrentUser
                ? "bg-primary/10 border-l-2 border-l-primary"
                : "border-l-2 border-l-transparent"
            } ${i < ranked.length - 1 ? "border-b border-border/50" : ""}`}
            style={{ animationDelay: `${i * 100}ms` }}
          >
            <span className="font-display text-xs flex items-center">
              {entry.rank <= 3 ? (
                <span className="text-lg">{medalIcons[entry.rank - 1]}</span>
              ) : (
                <span className="text-muted-foreground">{entry.rank}</span>
              )}
            </span>
            <span className={`font-medium truncate ${entry.isCurrentUser ? "text-primary" : "text-foreground"}`}>
              {entry.username}
              {entry.isCurrentUser && (
                <span className="ml-1.5 text-[10px] bg-primary/20 text-primary px-1.5 py-0.5 rounded-full font-display">
                  YOU
                </span>
              )}
            </span>
            <span className={`text-right tabular-nums font-semibold ${entry.isCurrentUser ? "text-primary" : "text-foreground"}`}>
              {entry.score}
            </span>
            <span className="text-right tabular-nums text-muted-foreground">
              {formatTime(entry.timeSeconds)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default Leaderboard;
