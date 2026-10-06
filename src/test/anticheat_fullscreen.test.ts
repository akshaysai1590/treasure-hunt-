import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  requestFullscreen,
  isFullscreenActive,
  isFullscreenSupported,
  onFullscreenChange,
} from "@/lib/fullscreen";

describe("Fullscreen & Anti-Cheat Utilities", () => {
  const originalDoc = { ...document };

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe("isFullscreenSupported", () => {
    it("returns true when requestFullscreen exists on documentElement", () => {
      const mockElem = { requestFullscreen: vi.fn() };
      vi.spyOn(document, "documentElement", "get").mockReturnValue(mockElem as any);
      expect(isFullscreenSupported()).toBe(true);
    });

    it("returns true when webkitRequestFullscreen exists (mobile Chrome/Safari)", () => {
      const mockElem = { webkitRequestFullscreen: vi.fn() };
      vi.spyOn(document, "documentElement", "get").mockReturnValue(mockElem as any);
      expect(isFullscreenSupported()).toBe(true);
    });

    it("returns false when no fullscreen methods are supported", () => {
      vi.spyOn(document, "documentElement", "get").mockReturnValue({} as any);
      expect(isFullscreenSupported()).toBe(false);
    });
  });

  describe("isFullscreenActive", () => {
    it("returns false when no fullscreen element is present", () => {
      Object.defineProperty(document, "fullscreenElement", {
        value: null,
        configurable: true,
      });
      expect(isFullscreenActive()).toBe(false);
    });

    it("returns true when standard fullscreenElement is set", () => {
      const div = document.createElement("div");
      Object.defineProperty(document, "fullscreenElement", {
        value: div,
        configurable: true,
      });
      expect(isFullscreenActive()).toBe(true);
    });

    it("returns true when webkitFullscreenElement is set (WebKit mobile)", () => {
      const div = document.createElement("div");
      Object.defineProperty(document, "fullscreenElement", {
        value: null,
        configurable: true,
      });
      Object.defineProperty(document, "webkitFullscreenElement", {
        value: div,
        configurable: true,
      });
      expect(isFullscreenActive()).toBe(true);
      delete (document as any).webkitFullscreenElement;
    });
  });

  describe("requestFullscreen", () => {
    it("invokes requestFullscreen on documentElement when available", () => {
      const requestMock = vi.fn().mockReturnValue(Promise.resolve());
      const mockElem = { requestFullscreen: requestMock };
      vi.spyOn(document, "documentElement", "get").mockReturnValue(mockElem as any);

      requestFullscreen();
      expect(requestMock).toHaveBeenCalled();
    });

    it("falls back to webkitRequestFullscreen on mobile WebKit", () => {
      const webkitMock = vi.fn();
      const mockElem = { webkitRequestFullscreen: webkitMock };
      vi.spyOn(document, "documentElement", "get").mockReturnValue(mockElem as any);

      requestFullscreen();
      expect(webkitMock).toHaveBeenCalled();
    });
  });

  describe("onFullscreenChange", () => {
    it("adds and cleans up event listeners", () => {
      const addSpy = vi.spyOn(document, "addEventListener");
      const removeSpy = vi.spyOn(document, "removeEventListener");
      const callback = vi.fn();

      const unsubscribe = onFullscreenChange(callback);
      expect(addSpy).toHaveBeenCalledWith("fullscreenchange", callback);
      expect(addSpy).toHaveBeenCalledWith("webkitfullscreenchange", callback);

      unsubscribe();
      expect(removeSpy).toHaveBeenCalledWith("fullscreenchange", callback);
      expect(removeSpy).toHaveBeenCalledWith("webkitfullscreenchange", callback);
    });
  });
});
