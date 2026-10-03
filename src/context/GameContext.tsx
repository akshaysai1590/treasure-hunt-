import React, { createContext, useContext, useState, useCallback, useRef, useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { callRpc } from "@/lib/api";
import { toast } from "sonner";

export type GameState = "login" | "qr-scan" | "round" | "hint" | "winner" | "eliminated";

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

  const [isPaused, setIsPaused] = useState(false);
  const [broadcastMessage, setBroadcastMessage] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem("session_token");
    if (token) {
      rehydrateState(token);
    }
  }, []);

  const rehydrateState = async (token: string) => {
    try {
      const res = await callRpc<any>("get_state", { p_session: token });
      if (res.success) {
        setParticipantId(token);
        setUsername(res.participant.username);
        setCurrentRound(res.participant.current_round);
        setLifelines(res.participant.lifelines);
        setGameState(res.participant.gameState);
        setScore(res.participant.score);
        
        if (res.participant.gameState === "winner") {
          setFinalScore(res.participant.score);
          setFinalTime(res.participant.completion_time);
        }
      } else {
        localStorage.removeItem("session_token");
        setParticipantId(null);
        setGameState("login");
      }
    } catch (e) {
      console.error("Rehydration error", e);
    }
  };

  const registerParticipant = useCallback(async (name: string): Promise<boolean> => {
    try {
      // name is passed as "username|password" hack since we can't change the signature.
      // Wait! The user said: "The useGame() hook keeps its existing exported names and signatures".
      // Let's split by "|_|" if present.
      const parts = name.split("|_|");
      const actualName = parts[0];
      const gamePass = parts[1] || "";
      
      const trimmedName = actualName.trim();
      if (!trimmedName) return false;

      const res = await callRpc<any>("register_participant", { 
        p_username: trimmedName, 
        p_entry_password: gamePass 
      });

      if (res.success) {
        setParticipantId(res.session_token);
        localStorage.setItem("session_token", res.session_token);
        setUsername(res.state.username);
        setGameState(res.state.stage);
        return true;
      } else {
        toast.error(res.error || "Failed to join game.");
        return false;
      }
    } catch (e: any) {
      console.error("Error registering:", e);
      toast.error(e.message || "Network error. Please try again.");
      return false;
    }
  }, []);

  const addScore = useCallback((points: number) => {
    // UI only
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
    // Reconciled entirely from server later, this is just optimistic UI
  }, [stopGlobalTimer]);

  const loseLifeline = useCallback(() => {
    // Optimistic UI, server handles actual loss
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
  }, []);

  // Sync Pause/Broadcast via Realtime
  useEffect(() => {
    const fetchInitial = async () => {
      const { data } = await supabase.from("game_state").select("is_paused, broadcast_message").eq("id", 1).single();
      if (data) {
        setIsPaused(data.is_paused);
        setBroadcastMessage(data.broadcast_message);
      }
    };
    
    fetchInitial();

    const channel = supabase.channel("game_state_changes")
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "game_state" }, (payload) => {
        setIsPaused(payload.new.is_paused);
        setBroadcastMessage(payload.new.broadcast_message);
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  useEffect(() => {
    if (isPaused) {
      stopGlobalTimer();
    } else {
      if (participantId && gameState !== "login" && gameState !== "winner" && gameState !== "eliminated") {
        startGlobalTimer();
      }
    }
  }, [isPaused, participantId, gameState, startGlobalTimer, stopGlobalTimer]);

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
    localStorage.removeItem("session_token");
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
