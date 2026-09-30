import LifelineBar from "./LifelineBar";
import ProgressIndicator from "./ProgressIndicator";
import GlobalTimer from "./GlobalTimer";
import { useGame } from "@/context/GameContext";
import { Star } from "lucide-react";

const GameHeader = () => {
  const { currentRound, lifelines, roundScores, username, score } = useGame();

  return (
    <div className="w-full px-4 py-3 flex flex-col gap-3 border-b border-border bg-card/50 backdrop-blur-sm sticky top-0 z-50">
      <div className="flex items-center justify-between max-w-lg mx-auto w-full">
        <span className="text-xs text-muted-foreground font-medium">
          Player: <span className="text-primary">{username}</span>
        </span>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1 text-xs text-accent">
            <Star className="w-3.5 h-3.5" />
            <span className="font-display tabular-nums">{score}</span>
          </div>
          <GlobalTimer />
          <LifelineBar lifelines={lifelines} />
        </div>
      </div>
      <div className="max-w-lg mx-auto w-full">
        <ProgressIndicator currentRound={currentRound} roundScores={roundScores} />
      </div>
    </div>
  );
};

export default GameHeader;
