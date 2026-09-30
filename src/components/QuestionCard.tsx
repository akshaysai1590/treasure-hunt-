import { useState } from "react";
import { Button } from "@/components/ui/button";
import { CheckCircle, XCircle } from "lucide-react";

interface QuestionCardProps {
  question: string;
  options: string[];
  correctIndex: number;
  onCorrect: () => void;
  onWrong: () => void;
  onAnswered?: () => void;
  image?: string;
}

const QuestionCard = ({ question, options, correctIndex, onCorrect, onWrong, onAnswered, image }: QuestionCardProps) => {
  const [selected, setSelected] = useState<number | null>(null);
  const [answered, setAnswered] = useState(false);

  const handleSelect = (idx: number) => {
    if (answered) return;
    setSelected(idx);
    setAnswered(true);
    // Lock the question immediately so the per-question timer cannot also expire
    // while the answer feedback is being shown.
    onAnswered?.();

    if (idx === correctIndex) {
      onCorrect();
    } else {
      onWrong();
    }
  };

  return (
    <div className="glass-card rounded-lg p-6 neon-border animate-pop-in max-w-lg w-full mx-auto">
      {image && (
        <div className="mb-4 rounded-md overflow-hidden border border-border">
          <img src={image} alt="Question visual" className="w-full object-cover max-h-48" />
        </div>
      )}
      <h3 className="text-lg font-medium mb-5 text-foreground leading-relaxed">{question}</h3>
      <div className="flex flex-col gap-3">
        {options.map((opt, i) => {
          const isCorrect = answered && i === correctIndex;
          const isWrong = answered && i === selected && i !== correctIndex;

          return (
            <button
              key={i}
              onClick={() => handleSelect(i)}
              disabled={answered}
              className={`relative w-full text-left px-4 py-3 rounded-md border transition-all duration-300 font-medium text-sm
                ${answered
                  ? isCorrect
                    ? "border-primary bg-primary/10 text-primary"
                    : isWrong
                      ? "border-destructive bg-destructive/10 text-destructive animate-shake"
                      : "border-border text-muted-foreground opacity-50"
                  : "border-border hover:border-primary/50 hover:bg-secondary text-foreground cursor-pointer"
                }`}
            >
              <span className="mr-2 text-muted-foreground">{String.fromCharCode(65 + i)}.</span>
              {opt}
              {isCorrect && <CheckCircle className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-primary" />}
              {isWrong && <XCircle className="absolute right-3 top-1/2 -translate-y-1/2 w-5 h-5 text-destructive" />}
            </button>
          );
        })}
      </div>
    </div>
  );
};

export default QuestionCard;
