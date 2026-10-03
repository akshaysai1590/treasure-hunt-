import React, { useState, useCallback, useEffect } from "react";
import { useGame } from "@/context/GameContext";
import GameHeader from "@/components/GameHeader";
import QuestionCard from "@/components/QuestionCard";
import Timer from "@/components/Timer";
import HintScreen from "@/components/HintScreen";
import { useSound } from "@/context/SoundContext";
import { toast } from "sonner";
import RoundIntroPopup from "@/components/RoundIntroPopup";
import { callRpc } from "@/lib/api";

const roundTitles = ["Logic & Aptitude", "Tech Riddles", "Rapid Fire", "Final DSA Challenge"];
const roundTimers = [120, 150, 45, 180];

const RoundScreen = () => {
  const { currentRound, setCurrentRound, setGameState, setRoundComplete, gameState, addScore, startGlobalTimer, finishGame, lifelines, isPaused } = useGame();
  const { playSound } = useSound();
  const [currentQ, setCurrentQ] = useState<any>(null);
  const [timeLimit, setTimeLimit] = useState(60);
  const [hintText, setHintText] = useState("");
  const [qIndex, setQIndex] = useState(0); // local cosmetic tracker
  const [timerKey, setTimerKey] = useState(0);
  const [timerStarted, setTimerStarted] = useState(false);
  const [questionAnswered, setQuestionAnswered] = useState(false);
  const [showIntro, setShowIntro] = useState(true);
  const [loading, setLoading] = useState(true);
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [selectedStatus, setSelectedStatus] = useState<'correct' | 'wrong' | null>(null);

  // Anti-Cheat: Focus Mode Detection
  useEffect(() => {
    let hideTime = 0;
    const handleVisibilityChange = () => {
      if (document.hidden && gameState === "round" && !isPaused) {
        hideTime = Date.now();
      }
      else if (!document.hidden && gameState === "round" && !isPaused) {
        const awayMs = Date.now() - hideTime;
        if (awayMs > 3000) {
          playSound("wrong");
          toast.error("⚠️ SYSTEM BREACH DETECTED: You left the secure terminal! Lifeline Lost.", {
            duration: 5000,
            style: { border: "2px solid red", color: "red", background: "#220000" }
          });
          const token = localStorage.getItem("session_token");
          callRpc("lose_lifeline", { p_session: token, p_reason: "tab_switch", p_idempotency_key: `tab_${Date.now()}` })
            .then((res: any) => {
               if (res.stage === "eliminated") setGameState("eliminated");
            });
        }
      }
    };

    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () => document.removeEventListener("visibilitychange", handleVisibilityChange);
  }, [gameState, isPaused, playSound, setGameState]);

  useEffect(() => {
    if (currentRound === 1 && !timerStarted) {
      startGlobalTimer();
      setTimerStarted(true);
    }
  }, [currentRound, timerStarted, startGlobalTimer]);

  const loadData = useCallback(async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem("session_token");
      if (gameState === "hint") {
        const res = await callRpc<any>("get_state", { p_session: token });
        if (res.success && res.hint) {
          setHintText(res.hint);
        }
      } else if (gameState === "round") {
        const res = await callRpc<any>("get_question", { p_session: token });
        if (res.success) {
          setCurrentQ(res.question);
          setTimeLimit(res.time_limit);
          setTimerKey(prev => prev + 1);
          setQuestionAnswered(false);
          setSelectedIndex(null);
          setSelectedStatus(null);
        }
      }
    } catch (e) {
      console.error(e);
      toast.error("Network error. Retrying...");
    } finally {
      setLoading(false);
    }
  }, [gameState]);

  useEffect(() => {
    if (!showIntro) {
      loadData();
    }
  }, [showIntro, gameState, loadData]);

  const handleCorrect = useCallback(() => {
    if (currentQ?.points) addScore(currentQ.points);
    setTimeout(() => {
      // Data is refreshed via RPC, handled in submit
    }, 600);
  }, [addScore, currentQ]);

  const handleWrong = useCallback(() => {
    if (currentQ?.points) addScore(-Math.floor(currentQ.points / 2));
    setTimeout(() => {
      // Data is refreshed via RPC
    }, 600);
  }, [addScore, currentQ]);

  const submitAnswer = async (idx: number) => {
    if (questionAnswered) return;
    const token = localStorage.getItem("session_token");
    const key = `q_${currentQ.id}_${Date.now()}`;
    setQuestionAnswered(true);
    setSelectedIndex(idx);
    
    try {
      let res;
      if (idx === -1) {
         res = await callRpc<any>("report_timeout", { p_session: token, p_idempotency_key: key });
      } else {
         res = await callRpc<any>("submit_answer", { p_session: token, p_selected_index: idx, p_idempotency_key: key });
      }
      
      if (res.success) {
         setSelectedStatus(res.correct ? 'correct' : 'wrong');
         if (res.correct) handleCorrect();
         else handleWrong();
         
         setTimeout(() => {
           if (res.stage === "eliminated") {
             setGameState("eliminated");
           } else if (res.finished) {
             setRoundComplete(currentRound);
             finishGame();
             setGameState("winner");
           } else if (res.round_complete) {
             setRoundComplete(currentRound);
             setGameState("hint");
           } else {
             setQIndex(prev => prev + 1);
             loadData(); // load next
           }
         }, 600);
      }
    } catch (e) {
      toast.error("Failed to submit. Check connection.");
      setQuestionAnswered(false);
    }
  };

  const handleTimeout = useCallback(() => {
    submitAnswer(-1);
  }, [currentQ]);

  const handleNextRound = useCallback(async () => {
    const token = localStorage.getItem("session_token");
    const res = await callRpc<any>("next_round", { p_session: token });
    if (res.success) {
      const next = currentRound + 1;
      setCurrentRound(next);
      setQIndex(0);
      setTimerKey(0);
      setQuestionAnswered(false);
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

  if (loading || !currentQ) {
    return <div className="flex flex-col min-h-screen items-center justify-center text-primary">Loading terminal...</div>;
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
