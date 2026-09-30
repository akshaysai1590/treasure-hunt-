import { MapPin, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";

interface HintScreenProps {
  hint: string;
  onContinue: () => void;
  roundCompleted: number;
}

const HintScreen = ({ hint, onContinue, roundCompleted }: HintScreenProps) => {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] gap-6 px-4 animate-pop-in">
      <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center neon-border animate-float">
        <MapPin className="w-8 h-8 text-primary" />
      </div>
      <h2 className="font-display text-xl neon-text text-center">
        Round {roundCompleted} Complete!
      </h2>
      <p className="text-muted-foreground text-center max-w-sm">
        Great job! Head to the next location:
      </p>
      <div className="glass-card rounded-lg p-5 neon-border max-w-sm w-full text-center">
        <p className="text-foreground font-medium text-lg leading-relaxed whitespace-pre-line italic">{hint}</p>
      </div>
      <Button onClick={onContinue} className="gap-2 mt-2">
        Scan Next QR Code <ArrowRight className="w-4 h-4" />
      </Button>
    </div>
  );
};

export default HintScreen;
