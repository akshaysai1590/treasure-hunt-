import { Heart } from "lucide-react";

interface LifelineBarProps {
  lifelines: number;
  total?: number;
}

const LifelineBar = ({ lifelines, total = 4 }: LifelineBarProps) => {
  return (
    <div className="flex items-center gap-1.5">
      {Array.from({ length: total }).map((_, i) => (
        <Heart
          key={i}
          className={`w-6 h-6 transition-all duration-300 ${
            i < lifelines
              ? "text-destructive fill-destructive drop-shadow-[0_0_6px_hsl(var(--destructive)/0.6)]"
              : "text-muted-foreground/30"
          } ${i >= lifelines ? "scale-75" : "animate-pop-in"}`}
          style={{ animationDelay: `${i * 0.05}s` }}
        />
      ))}
    </div>
  );
};

export default LifelineBar;
