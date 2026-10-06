import { useGame } from "@/context/GameContext";
import { Trophy, CheckCircle2 } from "lucide-react";
import MatrixRain from "@/components/MatrixRain";

const WinnerScreen = () => {
  const { username } = useGame();

  return (
    <div className="relative flex flex-col items-center justify-center min-h-screen px-6 py-10 gap-6 overflow-hidden text-center">
      <MatrixRain />

      <div
        className="relative z-10 w-24 h-24 rounded-full bg-accent/10 flex items-center justify-center animate-float backdrop-blur-sm"
        style={{ boxShadow: "0 0 35px hsl(var(--gold) / 0.35)" }}
      >
        <Trophy className="w-12 h-12 text-accent" />
      </div>

      <div className="relative z-10 space-y-3 max-w-md animate-pop-in">
        <h1 className="font-display text-3xl gold-text tracking-wider">
          CONGRATULATIONS!
        </h1>
        <p className="text-foreground text-lg font-medium">
          {username ? (
            <>
              <span className="text-primary font-bold">{username}</span>, you have completed the Treasure Hunt! 🎉
            </>
          ) : (
            "You have completed the Treasure Hunt! 🎉"
          )}
        </p>
      </div>

      <div className="relative z-10 w-full max-w-sm glass-card rounded-xl p-6 text-center neon-border bg-card/60 backdrop-blur-md animate-pop-in space-y-4">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 border border-primary/30 text-primary text-xs font-mono">
          <CheckCircle2 className="w-4 h-4 text-primary" /> ALL ROUNDS COMPLETED
        </div>

        <div className="p-4 rounded-lg bg-accent/10 border border-accent/30 text-accent font-display text-base font-semibold tracking-wide">
          📢 Score will be revealed by admins
        </div>

        <p className="text-xs text-muted-foreground leading-relaxed">
          Your final responses and completion time have been recorded on the server. Please wait for the official announcement by event coordinators.
        </p>
      </div>
    </div>
  );
};

export default WinnerScreen;
