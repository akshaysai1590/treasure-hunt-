import { describe, it, expect } from "vitest";
import { formatTime, rankLeaderboard, LeaderboardEntry } from "@/data/leaderboard";

describe("formatTime", () => {
  it("formats 0 seconds properly", () => {
    expect(formatTime(0)).toBe("00:00");
  });

  it("formats seconds under a minute", () => {
    expect(formatTime(9)).toBe("00:09");
    expect(formatTime(45)).toBe("00:45");
  });

  it("formats exact minutes", () => {
    expect(formatTime(60)).toBe("01:00");
    expect(formatTime(120)).toBe("02:00");
  });

  it("formats minutes and seconds", () => {
    expect(formatTime(125)).toBe("02:05");
    expect(formatTime(475)).toBe("07:55");
  });
});

describe("rankLeaderboard", () => {
  it("ranks entries by score in descending order", () => {
    const entries: LeaderboardEntry[] = [
      { username: "Bob", score: 50, timeSeconds: 100 },
      { username: "Alice", score: 100, timeSeconds: 120 },
      { username: "Charlie", score: 75, timeSeconds: 90 },
    ];

    const ranked = rankLeaderboard(entries);

    expect(ranked[0].username).toBe("Alice");
    expect(ranked[0].rank).toBe(1);
    expect(ranked[1].username).toBe("Charlie");
    expect(ranked[1].rank).toBe(2);
    expect(ranked[2].username).toBe("Bob");
    expect(ranked[2].rank).toBe(3);
  });

  it("uses completion time as tie-breaker for identical scores", () => {
    const entries: LeaderboardEntry[] = [
      { username: "Slower", score: 100, timeSeconds: 300 },
      { username: "Faster", score: 100, timeSeconds: 180 },
    ];

    const ranked = rankLeaderboard(entries);

    expect(ranked[0].username).toBe("Faster");
    expect(ranked[0].rank).toBe(1);
    expect(ranked[1].username).toBe("Slower");
    expect(ranked[1].rank).toBe(2);
  });

  it("handles empty lists gracefully", () => {
    expect(rankLeaderboard([])).toEqual([]);
  });
});
