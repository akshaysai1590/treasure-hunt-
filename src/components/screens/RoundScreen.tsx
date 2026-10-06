import { useState, useCallback, useEffect, useRef } from "react";
import { useGame, GameState } from "@/context/GameContext";
import GameHeader from "@/components/GameHeader";
import QuestionCard from "@/components/QuestionCard";
import Timer from "@/components/Timer";
import HintScreen from "@/components/HintScreen";
import { useSound } from "@/context/SoundContext";
import { toast } from "sonner";
import RoundIntroPopup from "@/components/RoundIntroPopup";
import { callRpc } from "@/lib/api";

const roundTitles = ["Logic & Aptitude", "Tech & Riddles", "Rapid Fire", "Brain Teasers"];

interface QuestionItem {
  id: number;
  question: string;
  options: string[];
  points?: number;
  image?: string;
}

interface QuestionResponse {
  success: boolean;
  question?: QuestionItem;
  time_limit?: number;
  error?: string;
}

interface SubmitResponse {
  success: boolean;
  correct?: boolean;
  score?: number;
  lifelines?: number;
  lives?: number;
  round_complete?: boolean;
  finished?: boolean;
  winner?: boolean;
  stage?: GameState;
  next_stage?: GameState;
  game_over?: boolean;
  error?: string;
}

interface StateResponse {
  success: boolean;
  hint?: string;
  participant?: {
    username?: string;
    current_round?: number;
    lifelines?: number;
    gameState?: GameState;
    score?: number;
    q_index?: number;
    completion_time?: number | null;
  };
}

interface NextRoundResponse {
  success: boolean;
  error?: string;
}

interface LifelineResponse {
  success: boolean;
  lifelines?: number;
  lives?: number;
  stage?: GameState;
  next_stage?: GameState;
}

const RoundScreen = () => {
  const { 
    currentRound, 
    setCurrentRound, 
    setGameState, 
    setRoundComplete, 
    gameState, 
    addScore, 
    setScore,
    setLifelines,
    startGlobalTimer, 
    finishGame, 
    lifelines, 
    isPaused,
    restoredQIndex,
    restoredRemainingTime,
  } = useGame();
  const { playSound } = useSound();
  const [currentQ, setCurrentQ] = useState<QuestionItem | null>(null);
  const [timeLimit, setTimeLimit] = useState(60);
  const [hintText, setHintText] = useState("");
  const [qIndex, setQIndex] = useState(restoredQIndex);
  const [timerKey, setTimerKey] = useState(0);
  const [timerStarted, setTimerStarted] = useState(false);
  const [questionAnswered, setQuestionAnswered] = useState(false);
  // Skip intro if player is resuming mid-round (restoredQIndex > 0) or resuming from rehydration
  const [showIntro, setShowIntro] = useState(restoredQIndex === 0);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [selectedStatus, setSelectedStatus] = useState<'correct' | 'wrong' | null>(null);
  const isSubmittingRef = useRef(false);
  // Track if this is first load (to use restoredRemainingTime)
  const isFirstLoadRef = useRef(true);

  // Anti-Cheat: Focus & Overlay Detection (Catches tab switches, Circle to Search, Google Lens overlay)
  useEffect(() => {
    let awayStartTime = 0;
    let isAway = false;

    const handleAway = () => {
      if (!isAway && gameState === "round" && !isPaused) {
        isAway = true;
        awayStartTime = Date.now();
      }
    };

    const handleReturn = () => {
      if (isAway && gameState === "round" && !isPaused) {
        isAway = false;
        const awayMs = Date.now() - awayStartTime;
        if (awayMs > 2500) {
          playSound("wrong");
          toast.error("⚠️ SYSTEM BREACH DETECTED: You left the secure terminal! Lifeline Lost.", {
            duration: 5000,
            style: { border: "2px solid red", color: "red", background: "#220000" }
          });
          const token = localStorage.getItem("session_token");
          callRpc<LifelineResponse>("lose_lifeline", { p_session: token, p_reason: "tab_switch", p_idempotency_key: `away_${Date.now()}` })
            .then((res) => {
               if (res.stage === "eliminated") setGameState("eliminated");
               if (typeof res.lifelines === "number") setLifelines(res.lifelines);
            })
            .catch(() => {
              // Ignore failure on lifeline check
            });
        }
      }
    };

    const handleVisibility = () => {
      if (document.hidden) {
        handleAway();
      } else {
        handleReturn();
      }
    };

    document.addEventListener("visibilitychange", handleVisibility);
    window.addEventListener("blur", handleAway);
    window.addEventListener("focus", handleReturn);

    return () => {
      document.removeEventListener("visibilitychange", handleVisibility);
      window.removeEventListener("blur", handleAway);
      window.removeEventListener("focus", handleReturn);
    };
  }, [gameState, isPaused, playSound, setGameState, setLifelines]);

  useEffect(() => {
    if (currentRound === 1 && !timerStarted) {
      startGlobalTimer();
      setTimerStarted(true);
    }
  }, [currentRound, timerStarted, startGlobalTimer]);

  // Also start global timer on rehydration (any round)
  useEffect(() => {
    if (!timerStarted && restoredQIndex > 0) {
      startGlobalTimer();
      setTimerStarted(true);
    }
  }, [timerStarted, restoredQIndex, startGlobalTimer]);

  const loadData = useCallback(async () => {
    try {
      setLoading(true);
      setLoadError(null);
      const token = localStorage.getItem("session_token");
      if (gameState === "hint") {
        const res = await callRpc<StateResponse>("get_state", { p_session: token });
        if (res.success && res.hint) {
          setHintText(res.hint);
        }
      } else if (gameState === "round") {
        const res = await callRpc<QuestionResponse>("get_question", { p_session: token });
        if (res.success && res.question) {
          setCurrentQ(res.question);
          setLoadError(null);
          // On first load after rehydration, use remaining time from server if available
          if (isFirstLoadRef.current && restoredRemainingTime !== null && restoredRemainingTime > 0) {
            setTimeLimit(restoredRemainingTime);
            isFirstLoadRef.current = false;
          } else {
            setTimeLimit(res.time_limit || 60);
            isFirstLoadRef.current = false;
          }
          setTimerKey(prev => prev + 1);
          setQuestionAnswered(false);
          isSubmittingRef.current = false;
          setSelectedIndex(null);
          setSelectedStatus(null);
        } else {
          // If get_question failed, verify with get_state in case user already completed the round
          const stateRes = await callRpc<StateResponse>("get_state", { p_session: token });
          if (stateRes.success && stateRes.participant) {
            const serverStage = stateRes.participant.gameState;
            if (serverStage && serverStage !== "round") {
              setGameState(serverStage);
              return;
            }
          }
          setLoadError(res.error || "No questions available for this round or terminal sync error.");
          setQuestionAnswered(false);
          isSubmittingRef.current = false;
        }
      }
    } catch (e) {
      console.error(e);
      setLoadError("Network error connecting to game server.");
      toast.error("Network error. Retrying...");
    } finally {
      setLoading(false);
    }
  }, [gameState, restoredRemainingTime, setGameState]);

  useEffect(() => {
    if (!showIntro) {
      loadData();
    }
  }, [showIntro, gameState, loadData]);

  const handleCorrect = useCallback(() => {
    if (currentQ?.points) addScore(currentQ.points);
  }, [addScore, currentQ]);

  const handleWrong = useCallback(() => {
    if (currentQ?.points) addScore(-Math.floor(currentQ.points / 2));
  }, [addScore, currentQ]);

  const submitAnswer = useCallback(async (idx: number) => {
    if (isSubmittingRef.current || !currentQ) return;
    isSubmittingRef.current = true;
    setQuestionAnswered(true);
    setSelectedIndex(idx);

    const token = localStorage.getItem("session_token");
    const key = `q_${currentQ.id}_${Date.now()}`;
    
    try {
      let res: SubmitResponse;
      if (idx === -1) {
         res = await callRpc<SubmitResponse>("report_timeout", { p_session: token, p_idempotency_key: key });
      } else {
         res = await callRpc<SubmitResponse>("submit_answer", { p_session: token, p_selected_index: idx, p_idempotency_key: key });
      }
      
      if (res.success) {
         setSelectedStatus(res.correct ? 'correct' : 'wrong');
         if (res.correct) handleCorrect();
         else handleWrong();

         if (typeof res.score === "number") setScore(res.score);
         const remainingLives = typeof res.lifelines === "number" ? res.lifelines : res.lives;
         if (typeof remainingLives === "number") setLifelines(remainingLives);

         const nextStage = res.stage || res.next_stage;
         const isWinner = Boolean(res.finished || res.winner || nextStage === "winner");
         const isEliminated = Boolean(nextStage === "eliminated" || res.game_over || (typeof remainingLives === "number" && remainingLives <= 0));
         const isRoundComplete = Boolean(res.round_complete || nextStage === "hint");
         
         setTimeout(() => {
           if (isEliminated) {
             setGameState("eliminated");
           } else if (isWinner) {
             setRoundComplete(currentRound);
             finishGame();
             setGameState("winner");
           } else if (isRoundComplete) {
             setRoundComplete(currentRound);
             setGameState("hint");
           } else {
             setQIndex(prev => prev + 1);
             loadData();
           }
         }, 600);
      } else {
        toast.error(res.error || "Failed to submit answer. Please try again.");
        setQuestionAnswered(false);
        isSubmittingRef.current = false;
      }
    } catch {
      toast.error("Failed to submit. Check connection.");
      setQuestionAnswered(false);
      isSubmittingRef.current = false;
    }
  }, [currentQ, currentRound, finishGame, handleCorrect, handleWrong, loadData, setGameState, setLifelines, setRoundComplete, setScore]);

  const handleTimeout = useCallback(() => {
    submitAnswer(-1);
  }, [submitAnswer]);

  const handleNextRound = useCallback(async () => {
    const token = localStorage.getItem("session_token");
    const res = await callRpc<NextRoundResponse>("next_round", { p_session: token });
    if (res.success) {
      const next = currentRound + 1;
      setCurrentRound(next);
      setQIndex(0);
      setTimerKey(0);
      setQuestionAnswered(false);
      isSubmittingRef.current = false;
      setShowIntro(true);
      setGameState("qr-scan");
    }
  }, [currentRound, setCurrentRound, setGameState]);

  if (gameState === "eliminated") return null;

  if (showIntro && gameState === "round") {
    return (
      <div className="flex flex-col min-h-screen">
        <GameHeader />
        <RoundIntroPopup
          round={currentRound}
          lifelines={lifelines}
          onStart={() => setShowIntro(false)}
        />
      </div>
    );
  }

  if (gameState === "hint") {
    return (
      <div className="flex flex-col min-h-screen">
        <GameHeader />
        {loading ? <div className="m-auto text-primary">Loading...</div> : (
          <HintScreen
            hint={hintText}
            onContinue={handleNextRound}
            roundCompleted={currentRound}
          />
        )}
      </div>
    );
  }

  if (loadError && !currentQ) {
    return (
      <div className="flex flex-col min-h-screen">
        <GameHeader />
        <div className="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <div className="glass-card max-w-sm w-full p-6 rounded-2xl border border-destructive/40 shadow-2xl animate-pop-in space-y-4">
            <div className="w-12 h-12 mx-auto rounded-full bg-destructive/10 flex items-center justify-center text-destructive text-2xl">
              ⚠️
            </div>
            <h3 className="font-display text-base font-bold text-destructive">TERMINAL SYNC ERROR</h3>
            <p className="text-xs text-muted-foreground leading-relaxed">{loadError}</p>
            <Button
              onClick={() => {
                setLoadError(null);
                loadData();
              }}
              className="w-full h-11 font-display tracking-wider text-xs"
            >
              RETRY CONNECTION 🔄
            </Button>
          </div>
        </div>
      </div>
    );
  }

  if (loading || !currentQ) {
    return (
      <div className="flex flex-col min-h-screen items-center justify-center gap-3 text-primary">
        <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        <span className="font-mono text-xs tracking-widest animate-pulse">CONNECTING TO SECURE TERMINAL...</span>
      </div>
    );
  }

  return (
    <div className="flex flex-col min-h-screen">
      <GameHeader />
      <div className="flex-1 flex flex-col items-center px-4 py-6 gap-5">
        <div className="flex items-center justify-between w-full max-w-lg">
          <div>
            <h2 className="font-display text-sm neon-text tracking-wider">
              ROUND {currentRound}
            </h2>
            <p className="text-xs text-red-500 animate-pulse font-mono mt-1">
              ⚠ SECURE TERMINAL: FOCUS REQUIRED
            </p>
            <p className="text-xs text-muted-foreground">{roundTitles[currentRound - 1]}</p>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-xs text-muted-foreground">
              Q{qIndex + 1}
            </span>
            <Timer
              key={timerKey}
              seconds={timeLimit}
              onTimeout={handleTimeout}
              isRunning={!questionAnswered && !isPaused}
            />
          </div>
        </div>

        <QuestionCard
          key={`${currentRound}-${qIndex}`}
          question={currentQ.question}
          options={currentQ.options}
          onSelect={(idx: number) => submitAnswer(idx)}
          image={currentQ.image}
          selectedIndex={selectedIndex}
          selectedStatus={selectedStatus}
          disabled={questionAnswered}
        />
      </div>
    </div>
  );
};

export default RoundScreen;
