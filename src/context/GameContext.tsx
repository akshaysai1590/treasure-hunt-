import React, { createContext, useContext, useState, useCallback, useRef } from "react";
import { supabase } from "@/lib/supabase";

export type GameState = "login" | "qr-scan" | "round" | "hint" | "winner" | "eliminated";

const GLOBAL_ID = "00000000-0000-0000-0000-000000000000";

export interface GameContextType {
  username: string;
  setUsername: (name: string) => void;
  currentRound: number;
  setCurrentRound: (round: number) => void;
  lifelines: number;
  loseLifeline: () => boolean;
  gameState: GameState;
  setGameState: (state: GameState) => void;
  resetGame: () => void;
  roundScores: boolean[];
  setRoundComplete: (round: number) => void;
  score: number;
  addScore: (points: number) => void;
  elapsedSeconds: number;
  startGlobalTimer: () => void;
  stopGlobalTimer: () => void;
  finalScore: number | null;
  finalTime: number | null;
  finishGame: () => void;
  participantId: string | null;
  registerParticipant: (name: string) => Promise<boolean>;
  isPaused: boolean;
  broadcastMessage: string | null;
}

const GameContext = createContext<GameContextType | null>(null);

export const useGame = () => {
  const ctx = useContext(GameContext);
  if (!ctx) throw new Error("useGame must be inside GameProvider");
  return ctx;
};

export const GameProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [username, setUsername] = useState("");
  const [currentRound, setCurrentRound] = useState(1);
  const [lifelines, setLifelines] = useState(4);
  const [gameState, setGameState] = useState<GameState>("login");
  const [roundScores, setRoundScores] = useState<boolean[]>([false, false, false, false]);
  const [score, setScore] = useState(0);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [finalScore, setFinalScore] = useState<number | null>(null);
  const [finalTime, setFinalTime] = useState<number | null>(null);
  const [participantId, setParticipantId] = useState<string | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const registerParticipant = useCallback(async (name: string): Promise<boolean> => {
    const trimmedName = name.trim();
    if (!trimmedName) return false;

    // Only use columns that exist in the DB.
    const { data, error } = await supabase
      .from("participants")
      .insert({ username: trimmedName, score: 0, completion_time: null, completed: false })
      .select("id")
      .single();

    if (error || !data?.id) {
      console.error("Error registering participant:", error);
      return false;
    }

    setParticipantId(data.id);
    setUsername(trimmedName);
    return true;
  }, []);

  const addScore = useCallback((points: number) => {
    setScore(prev => prev + points);
  }, []);

  const startGlobalTimer = useCallback(() => {
    if (timerRef.current) return;
    timerRef.current = setInterval(() => {
      setElapsedSeconds(prev => prev + 1);
    }, 1000);
  }, []);

  const stopGlobalTimer = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const finishGame = useCallback(() => {
    stopGlobalTimer();
    setElapsedSeconds(prev => {
      const lifelineBonus = lifelines * 5;
      setScore(s => {
        const total = s + lifelineBonus;
        setFinalScore(total);

        // Update Supabase with final results (only existing columns)
        setParticipantId(currentId => {
          if (currentId) {
            supabase
              .from("participants")
              .update({ score: total, completion_time: prev, completed: true })
              .eq("id", currentId)
              .then(({ error }) => {
                if (error) console.error("Error updating participant:", error);
              });
          }
          return currentId;
        });

        return total;
      });
      setFinalTime(prev);
      return prev;
    });
    setGameState("winner");
  }, [stopGlobalTimer, lifelines]);

  const loseLifeline = useCallback(() => {
    const next = lifelines - 1;
    setLifelines(next);
    if (next <= 0) {
      stopGlobalTimer();
      setGameState("eliminated");
      return false;
    }
    return true;
  }, [lifelines, stopGlobalTimer]);

  const setRoundComplete = useCallback((round: number) => {
    setRoundScores(prev => {
      const copy = [...prev];
      copy[round - 1] = true;
      return copy;
    });
    setScore(prev => prev + 10);
  }, []);

  // Sync score to DB when it changes (only use existing columns!)
  const updateParticipantScore = useCallback(async (newScore: number) => {
    if (!participantId) return;
    const { error } = await supabase
      .from("participants")
      .update({ score: newScore })
      .eq("id", participantId);
    if (error) console.error("Error updating score:", error);
  }, [participantId]);

  React.useEffect(() => {
    if (participantId && score > 0) {
      updateParticipantScore(score);
    }
  }, [score, participantId, updateParticipantScore]);

  const [isPaused, setIsPaused] = useState(false);
  const [broadcastMessage, setBroadcastMessage] = useState<string | null>(null);

  // Poll for Global State (Pause, Broadcast) — uses ONLY score + username columns
  // Freeze the global clock while the admin has paused the game.
  React.useEffect(() => {
    if (isPaused) {
      stopGlobalTimer();
      return;
    }

    if (participantId && gameState !== "login" && gameState !== "winner" && gameState !== "eliminated") {
      startGlobalTimer();
    }
  }, [isPaused, participantId, gameState, startGlobalTimer, stopGlobalTimer]);

  React.useEffect(() => {
    const pollInterval = setInterval(async () => {
      // Poll Global Settings (Pause, Broadcast)
      const { data: globalData, error } = await supabase
        .from("participants")
        .select("score, username")
        .eq("id", GLOBAL_ID)
        .maybeSingle();


      if (error) {
        return;
      }

      if (globalData) {
        const paused = globalData.score === 1;
        setIsPaused(paused);

        if (globalData.username !== "GLOBAL_SETTINGS" && globalData.username.startsWith("📢")) {

          setBroadcastMessage(globalData.username);
        } else {
          setBroadcastMessage(null);
        }

      }
    }, 3000);

    return () => clearInterval(pollInterval);
  }, []);

  const resetGame = useCallback(() => {
    stopGlobalTimer();
    setUsername("");
    setCurrentRound(1);
    setLifelines(4);
    setGameState("login");
    setRoundScores([false, false, false, false]);
    setScore(0);
    setElapsedSeconds(0);
    setFinalScore(null);
    setFinalTime(null);
    setParticipantId(null);
  }, [stopGlobalTimer]);

  return (
    <GameContext.Provider
      value={{
        username, setUsername,
        currentRound, setCurrentRound,
        lifelines, loseLifeline,
        gameState, setGameState,
        resetGame,
        roundScores, setRoundComplete,
        score, addScore,
        elapsedSeconds, startGlobalTimer, stopGlobalTimer,
        finalScore, finalTime, finishGame,
        participantId, registerParticipant,
        isPaused, broadcastMessage
      }}
    >
      {children}
    </GameContext.Provider>
  );
};
