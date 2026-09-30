import React, { useState, useCallback, useEffect } from "react";
import { useGame } from "@/context/GameContext";
import GameHeader from "@/components/GameHeader";
import QuestionCard from "@/components/QuestionCard";
import Timer from "@/components/Timer";
import { round1Questions, getRound1Questions, getRound2Questions, getRound3Questions, getRound4Questions, round2Questions, round3Questions, round4Questions, locationHints, Question } from "@/data/questions";
import HintScreen from "@/components/HintScreen";
import { useSound } from "@/context/SoundContext";
import { toast } from "sonner";
import RoundIntroPopup from "@/components/RoundIntroPopup";

const roundTitles = ["Logic & Aptitude", "Tech Riddles", "Rapid Fire", "Final DSA Challenge"];
const roundTimers = [120, 150, 45, 180];
const roundPointsPerQ = [10, 15, 8, 0]; // R4 uses per-question points

const getRoundQuestions = (round: number, username: string): Question[] => {
  switch (round) {
    case 1: return getRound1Questions(username);
    case 2: return getRound2Questions(username);
    case 3: return getRound3Questions(username);
    case 4: return getRound4Questions(username);
    default: return [];
  }
};

const RoundScreen = () => {
  const { currentRound, setCurrentRound, loseLifeline, setGameState, setRoundComplete, gameState, addScore, startGlobalTimer, finishGame, lifelines, username, isPaused } = useGame();
  const { playSound } = useSound();
  const [qIndex, setQIndex] = useState(0);
  const [showHint, setShowHint] = useState(false);
  const [timerKey, setTimerKey] = useState(0);
  const [timerStarted, setTimerStarted] = useState(false);
  const [questionAnswered, setQuestionAnswered] = useState(false);
  const [showIntro, setShowIntro] = useState(true);

  // Anti-Cheat: Focus Mode Detection
  useEffect(() => {
    const handleVisibilityChange = () => {
      // If the document becomes hidden (user switches tabs/apps)
      if (document.hidden && gameState === "round" && !showHint && !isPaused) {
        playSound("wrong");
        loseLifeline();
      }
      // If the document becomes visible again (user returns)
      else if (!document.hidden && gameState === "round" && !showHint && !isPaused) {
        toast.error("⚠️ SYSTEM BREACH DETECTED: You left the secure terminal! Lifeline Lost.", {
          duration: 5000,
          style: { border: "2px solid red", color: "red", background: "#220000" }
        });
      }
    };

    document.addEventListener("visibilitychange", handleVisibilityChange);
    return () => document.removeEventListener("visibilitychange", handleVisibilityChange);
  }, [gameState, showHint, isPaused, loseLifeline, playSound]);

  // Start global timer on first render of round 1
  useEffect(() => {
    if (currentRound === 1 && !timerStarted) {
      startGlobalTimer();
      setTimerStarted(true);
    }
  }, [currentRound, timerStarted, startGlobalTimer]);

  // Memoize questions to prevent shuffling on re-renders
  const questions = React.useMemo(() => getRoundQuestions(currentRound, username), [currentRound, username]);
  const currentQ = questions[qIndex];

  useEffect(() => {
    setQuestionAnswered(false);
  }, [currentRound, qIndex]);

  const advanceQuestion = useCallback(() => {
    if (qIndex + 1 < questions.length) {
      setQIndex(prev => prev + 1);
      setTimerKey(prev => prev + 1);
      setQuestionAnswered(false);
    } else {
      // Round complete
      setRoundComplete(currentRound);
      if (currentRound >= 4) {
        finishGame();
      } else {
        setShowHint(true);
      }
    }
  }, [qIndex, questions.length, currentRound, setRoundComplete, finishGame]);

  const getQuestionPoints = useCallback(() => {
    // R4 has per-question points, others use flat rate
    if (currentRound === 4 && currentQ?.points) return currentQ.points;
    return roundPointsPerQ[currentRound - 1];
  }, [currentRound, currentQ]);

  const handleCorrect = useCallback(() => {
    const pts = currentRound === 4 && currentQ?.points ? currentQ.points : roundPointsPerQ[currentRound - 1];
    addScore(pts);
    setTimeout(() => advanceQuestion(), 600);
  }, [advanceQuestion, addScore, currentRound, currentQ]);

  const handleWrong = useCallback(() => {
    const pts = currentRound === 4 && currentQ?.points ? currentQ.points : roundPointsPerQ[currentRound - 1];
    addScore(-Math.floor(pts / 2)); // lose half points for wrong
    setTimeout(() => {
      const alive = loseLifeline();
      if (alive) advanceQuestion();
    }, 600);
  }, [loseLifeline, advanceQuestion, addScore, currentRound, currentQ]);

  const handleTimeout = useCallback(() => {
    const pts = currentRound === 4 && currentQ?.points ? currentQ.points : roundPointsPerQ[currentRound - 1];
    addScore(-Math.floor(pts / 2));
    const alive = loseLifeline();
    if (alive) advanceQuestion();
  }, [loseLifeline, advanceQuestion, addScore, currentRound, currentQ]);

  const handleNextRound = useCallback(() => {
    const next = currentRound + 1;
    setCurrentRound(next);
    setQIndex(0);
    setTimerKey(0);
    setQuestionAnswered(false);
    setShowHint(false);
    setShowIntro(true);
    setGameState("qr-scan");
  }, [currentRound, setCurrentRound, setGameState]);

  if (gameState === "eliminated") return null;

  // Show round intro popup
  if (showIntro) {
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

  if (showHint) {
    return (
      <div className="flex flex-col min-h-screen">
        <GameHeader />
        <HintScreen
          hint={locationHints[currentRound - 1]}
          onContinue={handleNextRound}
          roundCompleted={currentRound}
        />
      </div>
    );
  }

  if (!currentQ) return null;

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
              Q{qIndex + 1}/{questions.length}
            </span>
            <Timer
              key={timerKey}
              seconds={roundTimers[currentRound - 1]}
              onTimeout={handleTimeout}
              isRunning={!questionAnswered && !isPaused}
            />
          </div>
        </div>

        <QuestionCard
          key={`${currentRound}-${qIndex}`}
          question={currentQ.question}
          options={currentQ.options}
          correctIndex={currentQ.correctIndex}
          onCorrect={handleCorrect}
          onWrong={handleWrong}
          onAnswered={() => setQuestionAnswered(true)}
          image={currentQ.image}
        />
      </div>
    </div>
  );
};

export default RoundScreen;
