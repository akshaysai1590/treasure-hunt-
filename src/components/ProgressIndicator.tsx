interface ProgressIndicatorProps {
  currentRound: number;
  totalRounds?: number;
  roundScores: boolean[];
}

const roundLabels = ["Round 1", "Round 2", "Round 3", "Round 4"];
const roundColors = [
  "bg-game-round-1",
  "bg-game-round-2",
  "bg-game-round-3",
  "bg-game-round-4",
];

const ProgressIndicator = ({ currentRound, totalRounds = 4, roundScores }: ProgressIndicatorProps) => {
  return (
    <div className="flex items-center gap-1 w-full max-w-md mx-auto">
      {Array.from({ length: totalRounds }).map((_, i) => {
        const isCompleted = roundScores[i];
        const isCurrent = i + 1 === currentRound;

        return (
          <div key={i} className="flex-1 flex flex-col items-center gap-1">
            <span className={`text-[10px] font-display tracking-wider uppercase ${
              isCurrent ? "neon-text" : isCompleted ? "text-primary" : "text-muted-foreground"
            }`}>
              {roundLabels[i]}
            </span>
            <div className={`w-full h-1.5 rounded-full transition-all duration-500 ${
              isCompleted ? roundColors[i] : isCurrent ? "bg-primary/40 animate-pulse-neon" : "bg-muted"
            }`} />
          </div>
        );
      })}
    </div>
  );
};

export default ProgressIndicator;
