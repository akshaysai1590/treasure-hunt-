import { useGame } from "@/context/GameContext";
import { Button } from "@/components/ui/button";
import { Skull, RotateCcw } from "lucide-react";

const EliminatedScreen = () => {
  const { username, resetGame, currentRound } = useGame();

  return (
    <div className="flex flex-col items-center justify-center min-h-screen px-6 gap-6 text-center">
      <div className="w-24 h-24 rounded-full bg-destructive/10 flex items-center justify-center animate-pop-in"
        style={{ boxShadow: "0 0 30px hsl(var(--danger) / 0.3)" }}>
        <Skull className="w-12 h-12 text-destructive" />
      </div>
      <h1 className="font-display text-3xl danger-text animate-pop-in">
        ELIMINATED
      </h1>
      <p className="text-foreground text-lg max-w-sm">
        Sorry <span className="text-primary font-semibold">{username}</span>, you ran out of lifelines in Round {currentRound}.
      </p>
      <p className="text-muted-foreground text-sm max-w-xs">
        Better luck next time! Every treasure hunter faces setbacks.
      </p>
      <Button onClick={resetGame} variant="outline" className="border-destructive text-destructive hover:bg-destructive/10 gap-2 mt-4">
        <RotateCcw className="w-4 h-4" /> Try Again
      </Button>
    </div>
  );
};

export default EliminatedScreen;
