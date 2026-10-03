import { CheckCircle, XCircle } from "lucide-react";

interface QuestionCardProps {
  question: string;
  options: string[];
  onSelect: (idx: number) => void;
  image?: string;
  selectedIndex?: number | null;
  selectedStatus?: 'correct' | 'wrong' | null;
  disabled?: boolean;
}

const QuestionCard = ({ question, options, onSelect, image, selectedIndex, selectedStatus, disabled }: QuestionCardProps) => {

  const handleSelect = (idx: number) => {
    if (disabled) return;
    onSelect(idx);
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
          const isSelected = i === selectedIndex;
          const isCorrect = isSelected && selectedStatus === 'correct';
          const isWrong = isSelected && selectedStatus === 'wrong';

          return (
            <button
              key={i}
              onClick={() => handleSelect(i)}
              disabled={disabled}
              className={`relative w-full text-left px-4 py-3 rounded-md border transition-all duration-300 font-medium text-sm
                ${disabled
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
