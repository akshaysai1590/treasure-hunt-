import { useGame } from "@/context/GameContext";
import { Button } from "@/components/ui/button";
import { Trophy, RotateCcw, Star, Clock, Award } from "lucide-react";
import Leaderboard from "@/components/Leaderboard";
import { formatTime } from "@/data/leaderboard";
import { useMemo, useState, useEffect } from "react";
import { supabase } from "@/lib/supabase";
import MatrixRain from "@/components/MatrixRain";

interface DbParticipant {
  id: string;
  username: string;
  score: number;
  completion_time: number;
}

const WinnerScreen = () => {
  const { username, resetGame, finalScore, finalTime, participantId } = useGame();
  const [entries, setEntries] = useState<{ username: string; score: number; timeSeconds: number; isCurrentUser?: boolean }[]>([]);

  useEffect(() => {
    const fetchLeaderboard = async () => {
      const { data, error } = await supabase
        .from("participants")
        .select("id, username, score, completion_time")
        .eq("completed", true)
        .order("score", { ascending: false })
        .order("completion_time", { ascending: true });

      if (error) {
        console.error("Error fetching leaderboard:", error);
        return;
      }

      const mapped = (data as DbParticipant[]).map((p) => ({
        username: p.username,
        score: p.score,
        timeSeconds: p.completion_time,
        isCurrentUser: p.id === participantId,
      }));
      setEntries(mapped);
    };

    fetchLeaderboard();
  }, [participantId]);

  const userRank = useMemo(() => {
    const idx = entries.findIndex(e => e.isCurrentUser);
    return idx >= 0 ? idx + 1 : entries.length + 1;
  }, [entries]);

  return (
    <div className="relative flex flex-col items-center min-h-screen px-6 py-10 gap-6 overflow-hidden">
      <MatrixRain />

      <div className="relative z-10 w-20 h-20 rounded-full bg-accent/10 flex items-center justify-center animate-float backdrop-blur-sm"
        style={{ boxShadow: "0 0 30px hsl(var(--gold) / 0.3)" }}>
        <Trophy className="w-10 h-10 text-accent" />
      </div>

      <h1 className="relative z-10 font-display text-2xl gold-text animate-pop-in">CONGRATULATIONS!</h1>
      <p className="relative z-10 text-foreground text-base">
        <span className="text-primary font-semibold">{username}</span>, you completed the treasure hunt! 🎉
      </p>

      <div className="relative z-10 grid grid-cols-3 gap-3 w-full max-w-sm animate-pop-in">
        <div className="glass-card rounded-lg p-3 text-center neon-border bg-card/50 backdrop-blur-md">
          <Star className="w-5 h-5 text-accent mx-auto mb-1" />
          <p className="font-display text-lg text-foreground">{finalScore ?? 0}</p>
          <p className="text-[10px] text-muted-foreground font-display tracking-wider">SCORE</p>
        </div>
        <div className="glass-card rounded-lg p-3 text-center neon-border bg-card/50 backdrop-blur-md">
          <Clock className="w-5 h-5 text-primary mx-auto mb-1" />
          <p className="font-display text-lg text-foreground">{formatTime(finalTime ?? 0)}</p>
          <p className="text-[10px] text-muted-foreground font-display tracking-wider">TIME</p>
        </div>
        <div className="glass-card rounded-lg p-3 text-center neon-border bg-card/50 backdrop-blur-md">
          <Award className="w-5 h-5 text-accent mx-auto mb-1" />
          <p className="font-display text-lg text-foreground">#{userRank}</p>
          <p className="text-[10px] text-muted-foreground font-display tracking-wider">RANK</p>
        </div>
      </div>

      <div className="relative z-10 w-full max-w-lg animate-pop-in" style={{ animationDelay: "0.2s" }}>
        <Leaderboard entries={entries} />
      </div>

      <Button onClick={resetGame} variant="outline" className="relative z-10 neon-border gap-2 mt-2">
        <RotateCcw className="w-4 h-4" /> Play Again
      </Button>
    </div>
  );
};

export default WinnerScreen;
