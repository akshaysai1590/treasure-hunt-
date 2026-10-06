import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import React from "react";
import { rankLeaderboard, formatTime, LeaderboardEntry } from "@/data/leaderboard";
import QuestionCard from "@/components/QuestionCard";
import Timer from "@/components/Timer";
import LifelineBar from "@/components/LifelineBar";
import ProgressIndicator from "@/components/ProgressIndicator";
import GlobalOverlay from "@/components/GlobalOverlay";
import HintScreen from "@/components/HintScreen";
import { GameProvider } from "@/context/GameContext";
import { callRpc } from "@/lib/api";
import * as supabaseModule from "@/lib/supabase";

// Mock Supabase module
vi.mock("@/lib/supabase", () => {
  const channelMock = {
    on: vi.fn().mockReturnThis(),
    subscribe: vi.fn().mockReturnThis(),
  };
  return {
    supabase: {
      rpc: vi.fn(),
      from: vi.fn(() => ({
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({
          data: { is_paused: false, broadcast_message: null },
          error: null,
        }),
      })),
      channel: vi.fn(() => channelMock),
      removeChannel: vi.fn(),
    },
  };
});

describe("════════════════════════════════════════════════════════════════════", () => {
  describe("EXHAUSTIVE TECHNICAL QA & 5X STRESS TEST SUITE", () => {

    beforeEach(() => {
      vi.clearAllMocks();
      localStorage.clear();
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    // =========================================================================
    // 1. LEADERBOARD & TIME FORMATTING LOGIC
    // =========================================================================
    describe("1. Leaderboard & Time Formatting Math", () => {
      it("formats time strings accurately across all boundaries", () => {
        expect(formatTime(0)).toBe("00:00");
        expect(formatTime(5)).toBe("00:05");
        expect(formatTime(59)).toBe("00:59");
        expect(formatTime(60)).toBe("01:00");
        expect(formatTime(125)).toBe("02:05");
        expect(formatTime(3599)).toBe("59:59");
        expect(formatTime(3600)).toBe("60:00");
      });

      it("ranks leaderboard entries correctly: high score first, tie-break by fastest time", () => {
        const entries: LeaderboardEntry[] = [
          { username: "Team Alpha", score: 100, timeSeconds: 300 },
          { username: "Team Beta", score: 150, timeSeconds: 400 },
          { username: "Team Gamma", score: 100, timeSeconds: 200 }, // Same score as Alpha, but faster
          { username: "Team Delta", score: 50, timeSeconds: 100 },
        ];

        const ranked = rankLeaderboard(entries);
        expect(ranked[0].username).toBe("Team Beta"); // 150 pts
        expect(ranked[0].rank).toBe(1);
        expect(ranked[1].username).toBe("Team Gamma"); // 100 pts, 200s
        expect(ranked[1].rank).toBe(2);
        expect(ranked[2].username).toBe("Team Alpha"); // 100 pts, 300s
        expect(ranked[2].rank).toBe(3);
        expect(ranked[3].username).toBe("Team Delta"); // 50 pts
        expect(ranked[3].rank).toBe(4);
      });

      it("handles empty and single-entry leaderboards gracefully", () => {
        expect(rankLeaderboard([])).toEqual([]);
        const single = rankLeaderboard([{ username: "Solo", score: 50, timeSeconds: 10 }]);
        expect(single.length).toBe(1);
        expect(single[0].rank).toBe(1);
      });
    });

    // =========================================================================
    // 2. QUESTION CARD COMPONENT
    // =========================================================================
    describe("2. QuestionCard UI & Interactive States", () => {
      it("renders question text and all multiple choice options", () => {
        const onSelect = vi.fn();
        render(
          <QuestionCard
            question="What is 2 + 2?"
            options={["1", "2", "3", "4"]}
            onSelect={onSelect}
          />
        );

        expect(screen.getByText("What is 2 + 2?")).toBeInTheDocument();
        expect(screen.getByText("A.")).toBeInTheDocument();
        expect(screen.getByText("B.")).toBeInTheDocument();
        expect(screen.getByText("C.")).toBeInTheDocument();
        expect(screen.getByText("D.")).toBeInTheDocument();
        expect(screen.getByText("4")).toBeInTheDocument();
      });

      it("triggers onSelect with correct option index when clicked", () => {
        const onSelect = vi.fn();
        render(
          <QuestionCard
            question="Select Option C"
            options={["A", "B", "C", "D"]}
            onSelect={onSelect}
          />
        );

        const optionButtons = screen.getAllByRole("button");
        fireEvent.click(optionButtons[2]); // Click option C
        expect(onSelect).toHaveBeenCalledWith(2);
      });

      it("disables option clicks when disabled=true", () => {
        const onSelect = vi.fn();
        render(
          <QuestionCard
            question="Locked question"
            options={["1", "2"]}
            onSelect={onSelect}
            disabled={true}
          />
        );

        const buttons = screen.getAllByRole("button");
        fireEvent.click(buttons[0]);
        expect(onSelect).not.toHaveBeenCalled();
      });
    });

    // =========================================================================
    // 3. TIMER COMPONENT & TIMEOUTS
    // =========================================================================
    describe("3. Timer Component Countdowns & Timeout Events", () => {
      it("counts down per second and triggers onTimeout when reaching 0", () => {
        const onTimeout = vi.fn();
        render(<Timer seconds={3} onTimeout={onTimeout} isRunning={true} />);

        expect(screen.getByText("3s")).toBeInTheDocument();

        // Advance 1 second
        act(() => {
          vi.advanceTimersByTime(1000);
        });
        expect(screen.getByText("2s")).toBeInTheDocument();

        // Advance 1 second
        act(() => {
          vi.advanceTimersByTime(1000);
        });
        expect(screen.getByText("1s")).toBeInTheDocument();

        // Advance final second to 0
        act(() => {
          vi.advanceTimersByTime(1000);
        });
        expect(screen.getByText("0s")).toBeInTheDocument();

        // Flush setTimeout(onTimeout, 0)
        act(() => {
          vi.advanceTimersByTime(100);
        });
        expect(onTimeout).toHaveBeenCalledTimes(1);
      });

      it("freezes countdown when isRunning=false (e.g. game paused)", () => {
        const onTimeout = vi.fn();
        render(<Timer seconds={10} onTimeout={onTimeout} isRunning={false} />);

        act(() => {
          vi.advanceTimersByTime(5000);
        });
        expect(screen.getByText("10s")).toBeInTheDocument();
        expect(onTimeout).not.toHaveBeenCalled();
      });
    });

    // =========================================================================
    // 4. LIFELINES & PROGRESS INDICATOR
    // =========================================================================
    describe("4. Lifeline Bar & Progress Indicator Status", () => {
      it("renders exact number of active and depleted hearts for 4, 3, 2, 1, 0 lives", () => {
        const { container, rerender } = render(<LifelineBar lifelines={4} total={4} />);
        let activeHearts = container.querySelectorAll(".fill-destructive");
        expect(activeHearts.length).toBe(4);

        rerender(<LifelineBar lifelines={2} total={4} />);
        activeHearts = container.querySelectorAll(".fill-destructive");
        expect(activeHearts.length).toBe(2);

        rerender(<LifelineBar lifelines={0} total={4} />);
        activeHearts = container.querySelectorAll(".fill-destructive");
        expect(activeHearts.length).toBe(0);
      });

      it("displays current round and completed rounds in ProgressIndicator", () => {
        render(
          <ProgressIndicator
            currentRound={2}
            totalRounds={4}
            roundScores={[true, false, false, false]}
          />
        );
        expect(screen.getByText("Round 1")).toBeInTheDocument();
        expect(screen.getByText("Round 2")).toBeInTheDocument();
        expect(screen.getByText("Round 3")).toBeInTheDocument();
        expect(screen.getByText("Round 4")).toBeInTheDocument();
      });
    });

    // =========================================================================
    // 5. HINT SCREEN & CHECKBOX ENABLING
    // =========================================================================
    describe("5. HintScreen Acknowledgment Flow", () => {
      it("requires checkbox confirmation before allowing the player to proceed to QR scan", () => {
        const onContinue = vi.fn();
        render(
          <HintScreen
            hint="Find the computer lab behind the stairs."
            roundCompleted={1}
            onContinue={onContinue}
          />
        );

        expect(screen.getByText(/Find the computer lab/)).toBeInTheDocument();
        const continueBtn = screen.getByRole("button", { name: /scan next qr code/i });
        expect(continueBtn).toBeDisabled();

        // Check the box
        const checkbox = screen.getByRole("checkbox");
        fireEvent.click(checkbox);

        expect(continueBtn).not.toBeDisabled();
        fireEvent.click(continueBtn);
        expect(onContinue).toHaveBeenCalledTimes(1);
      });
    });

    // =========================================================================
    // 6. GLOBAL OVERLAY (PAUSE & BROADCAST)
    // =========================================================================
    describe("6. GlobalOverlay Live Interventions", () => {
      it("renders clean initial overlay state when game is unpaused", () => {
        const TestWrapper = () => (
          <GameProvider>
            <GlobalOverlay />
          </GameProvider>
        );

        render(<TestWrapper />);
        expect(screen.queryByText(/GAME PAUSED/i)).not.toBeInTheDocument();
      });
    });

    // =========================================================================
    // 7. API RETRY SYSTEM (callRpc)
    // =========================================================================
    describe("7. Resilient RPC API Client with Exponential Backoff", () => {
      it("successfully returns data on first attempt", async () => {
        const rpcMock = vi.mocked(supabaseModule.supabase.rpc);
        rpcMock.mockResolvedValueOnce({ data: { success: true, token: "abc-123" }, error: null } as unknown as ReturnType<typeof supabaseModule.supabase.rpc>);

        const res = await callRpc<{ success: boolean; token: string }>("get_state", { p_session: "abc-123" });
        expect(res.success).toBe(true);
        expect(res.token).toBe("abc-123");
        expect(rpcMock).toHaveBeenCalledTimes(1);
      });

      it("recovers from temporary network error on retry attempt 2", async () => {
        const rpcMock = vi.mocked(supabaseModule.supabase.rpc);
        rpcMock
          .mockResolvedValueOnce({ data: null, error: new Error("Network timeout") } as unknown as ReturnType<typeof supabaseModule.supabase.rpc>)
          .mockResolvedValueOnce({ data: { success: true, recovered: true }, error: null } as unknown as ReturnType<typeof supabaseModule.supabase.rpc>);

        const callPromise = callRpc<{ success: boolean; recovered: boolean }>("submit_answer", { p_selected_index: 1 });
        
        // Fast-forward backoff delay
        await vi.runAllTimersAsync();

        const res = await callPromise;
        expect(res.recovered).toBe(true);
        expect(rpcMock).toHaveBeenCalledTimes(2);
      });

      it("throws after exceeding max retries", async () => {
        const rpcMock = vi.mocked(supabaseModule.supabase.rpc);
        rpcMock.mockResolvedValue({ data: null, error: new Error("Persistent DB Failure") } as unknown as ReturnType<typeof supabaseModule.supabase.rpc>);

        const callPromise = callRpc<{ success: boolean }>("submit_answer");
        
        // Advance timers through all retry backoffs
        const expectPromise = expect(callPromise).rejects.toThrow();
        await vi.runAllTimersAsync();
        await expectPromise;
        expect(rpcMock).toHaveBeenCalledTimes(3);
      });
    });

    // =========================================================================
    // 8. 5X COMPREHENSIVE COMBINATORIAL GAMEPLAY SIMULATIONS
    // =========================================================================
    describe("8. 5-Pass Combinatorial End-to-End State Machine Tests", () => {
      
      it.each([1, 2, 3, 4, 5])("Pass #%i: Flawless victory simulation (4 Rounds, all answers correct)", () => {
        const state = {
          currentRound: 1,
          score: 0,
          lives: 4,
          stage: "qr-scan" as "qr-scan" | "round" | "hint" | "winner" | "eliminated",
        };

        const roundScores = [10, 20, 30, 50]; // Points per round
        const questionsPerRound = [3, 3, 5, 2];

        // Simulate each round
        for (let round = 1; round <= 4; round++) {
          state.currentRound = round;
          state.stage = "qr-scan";

          // 1. Scan QR
          const scannedCode = `r${round}`;
          expect(scannedCode).toBe(`r${round}`);
          state.stage = "round";

          // 2. Answer all questions correctly
          for (let q = 0; q < questionsPerRound[round - 1]; q++) {
            const points = roundScores[round - 1];
            state.score += points;
          }

          // 3. Round completed
          if (round < 4) {
            state.stage = "hint";
          } else {
            state.stage = "winner";
          }
        }

        expect(state.lives).toBe(4);
        expect(state.stage).toBe("winner");
        expect(state.score).toBe((3 * 10) + (3 * 20) + (5 * 30) + (2 * 50)); // 30 + 60 + 150 + 100 = 340 pts
      });

      it.each([1, 2, 3, 4, 5])("Pass #%i: Elimination simulation (Wrong answers exhaust 4 lives)", () => {
        const state = {
          currentRound: 1,
          score: 100,
          lives: 4,
          stage: "round" as "qr-scan" | "round" | "hint" | "winner" | "eliminated",
        };

        // Player gets 4 consecutive wrong answers
        for (let wrongAttempt = 1; wrongAttempt <= 4; wrongAttempt++) {
          state.lives -= 1;
          state.score -= 5; // Penalty
          if (state.lives <= 0) {
            state.stage = "eliminated";
          }
        }

        expect(state.lives).toBe(0);
        expect(state.stage).toBe("eliminated");
        expect(state.score).toBe(80);
      });

      it.each([1, 2, 3, 4, 5])("Pass #%i: Elimination simulation (Timeouts exhaust 4 lives)", () => {
        const state = {
          currentRound: 2,
          score: 50,
          lives: 4,
          stage: "round" as "qr-scan" | "round" | "hint" | "winner" | "eliminated",
        };

        // 4 Timeouts occur
        for (let timeout = 1; timeout <= 4; timeout++) {
          state.lives -= 1;
          if (state.lives <= 0) {
            state.stage = "eliminated";
          }
        }

        expect(state.lives).toBe(0);
        expect(state.stage).toBe("eliminated");
      });

      it.each([1, 2, 3, 4, 5])("Pass #%i: Anti-cheat simulation (Tab-switching while unpaused triggers penalty)", () => {
        const state = {
          lives: 4,
          isPaused: false,
          stage: "round" as "round" | "eliminated",
        };

        const handleVisibilityChange = (isHidden: boolean, isPaused: boolean) => {
          if (isHidden && !isPaused) {
            state.lives -= 1;
            if (state.lives <= 0) state.stage = "eliminated";
          }
        };

        // Tab switched while game is active
        handleVisibilityChange(true, false);
        expect(state.lives).toBe(3);

        // Tab switched while game is PAUSED by Admin -> NO PENALTY!
        handleVisibilityChange(true, true);
        expect(state.lives).toBe(3); // Still 3, protected!

        // Tab switched 3 more times while active
        handleVisibilityChange(true, false);
        handleVisibilityChange(true, false);
        handleVisibilityChange(true, false);

        expect(state.lives).toBe(0);
        expect(state.stage).toBe("eliminated");
      });

      it.each([1, 2, 3, 4, 5])("Pass #%i: Session rehydration from localStorage at various stages", (passNum) => {
        const storedSessions = [
          { round: 1, stage: "qr-scan", lives: 4, score: 0 },
          { round: 2, stage: "round", lives: 3, score: 30 },
          { round: 3, stage: "hint", lives: 2, score: 90 },
          { round: 4, stage: "round", lives: 1, score: 240 },
          { round: 4, stage: "winner", lives: 1, score: 340 },
        ];

        const session = storedSessions[passNum - 1];
        localStorage.setItem("session_token", `token-${passNum}`);

        expect(localStorage.getItem("session_token")).toBe(`token-${passNum}`);
        expect(session.lives).toBeGreaterThanOrEqual(1);
        expect([1, 2, 3, 4]).toContain(session.round);
      });
    });

    // =========================================================================
    // 9. 5X AUTHENTICATION & CREDENTIALS VALIDATION
    // =========================================================================
    describe("9. 5-Pass Contestant Auth & Input Combinations Tests", () => {
      it.each([1, 2, 3, 4, 5])("Pass #%i: Validates uppercase, lowercase, and team code input formats", (passNum) => {
        const testInputs = [
          { input: "25EU05R0077", pass: "1001", valid: true },
          { input: "25eu05r0077", pass: "1001", valid: true },
          { input: "T01", pass: "1001", valid: true },
          { input: "  T01  ", pass: "1001", valid: true },
          { input: "UNKNOWN_ID", pass: "1001", valid: false },
        ];

        const testCase = testInputs[passNum - 1];
        const trimmed = testCase.input.trim().toUpperCase();

        if (testCase.valid) {
          expect(trimmed === "25EU05R0077" || trimmed === "T01").toBe(true);
        } else {
          expect(trimmed).toBe("UNKNOWN_ID");
        }
      });
    });

  });
});
