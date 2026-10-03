import { useEffect, useState, useRef } from "react";
import { Clock } from "lucide-react";

interface TimerProps {
  seconds: number;
  onTimeout: () => void;
  isRunning: boolean;
}

const Timer = ({ seconds, onTimeout, isRunning }: TimerProps) => {
  const [timeLeft, setTimeLeft] = useState(seconds);
  const onTimeoutRef = useRef(onTimeout);
  onTimeoutRef.current = onTimeout;
  const timedOutRef = useRef(false);

  useEffect(() => {
    setTimeLeft(seconds);
    timedOutRef.current = false;
  }, [seconds]);

  useEffect(() => {
    if (!isRunning || timeLeft <= 0) return;

    const interval = setInterval(() => {
      setTimeLeft(prev => {
        if (prev <= 1) {
          clearInterval(interval);
          if (!timedOutRef.current) {
            timedOutRef.current = true;
            setTimeout(() => {
              onTimeoutRef.current();
            }, 0);
          }
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [isRunning, timeLeft]);

  const pct = (timeLeft / seconds) * 100;
  const isLow = timeLeft <= 5;

  return (
    <div className="flex items-center gap-2">
      <Clock className={`w-4 h-4 ${isLow ? "text-destructive animate-pulse-neon" : "text-primary"}`} />
      <div className="w-24 h-2 rounded-full bg-muted overflow-hidden">
        <div
          className={`h-full rounded-full transition-all duration-1000 ease-linear ${isLow ? "bg-destructive" : "bg-primary"
            }`}
          style={{ width: `${pct}%` }}
        />
      </div>
      <span className={`font-display text-sm tabular-nums ${isLow ? "danger-text" : "text-foreground"}`}>
        {timeLeft}s
      </span>
    </div>
  );
};

export default Timer;
