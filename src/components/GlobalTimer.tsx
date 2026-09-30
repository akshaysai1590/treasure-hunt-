import { useGame } from "@/context/GameContext";
import { Clock } from "lucide-react";
import { formatTime } from "@/data/leaderboard";

const GlobalTimer = () => {
  const { elapsedSeconds } = useGame();

  return (
    <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
      <Clock className="w-3.5 h-3.5" />
      <span className="font-display tabular-nums">{formatTime(elapsedSeconds)}</span>
    </div>
  );
};

export default GlobalTimer;
