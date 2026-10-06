// Fullscreen utility functions for cross-browser mobile and desktop support

export function requestFullscreen(): void {
  const docEl = document.documentElement as HTMLElement & {
    webkitRequestFullscreen?: () => Promise<void> | void;
    mozRequestFullScreen?: () => Promise<void> | void;
    msRequestFullscreen?: () => Promise<void> | void;
  };

  if (!docEl) return;

  try {
    if (docEl.requestFullscreen) {
      docEl.requestFullscreen().catch(() => {});
    } else if (docEl.webkitRequestFullscreen) {
      docEl.webkitRequestFullscreen();
    } else if (docEl.mozRequestFullScreen) {
      docEl.mozRequestFullScreen();
    } else if (docEl.msRequestFullscreen) {
      docEl.msRequestFullscreen();
    }
  } catch {
    // Graceful fallback on restricted webviews
  }
}

export function isFullscreenActive(): boolean {
  const doc = document as Document & {
    webkitFullscreenElement?: Element | null;
    mozFullScreenElement?: Element | null;
    msFullscreenElement?: Element | null;
  };

  return Boolean(
    doc.fullscreenElement ||
    doc.webkitFullscreenElement ||
    doc.mozFullScreenElement ||
    doc.msFullscreenElement
  );
}

export function isFullscreenSupported(): boolean {
  if (typeof document === "undefined") return false;
  const docEl = document.documentElement as HTMLElement & {
    webkitRequestFullscreen?: unknown;
    mozRequestFullScreen?: unknown;
  };
  return Boolean(
    docEl.requestFullscreen ||
    docEl.webkitRequestFullscreen ||
    docEl.mozRequestFullScreen ||
    docEl.msRequestFullscreen
  );
}

export function onFullscreenChange(callback: () => void): () => void {
  if (typeof document === "undefined") return () => {};
  const events = [
    "fullscreenchange",
    "webkitfullscreenchange",
    "mozfullscreenchange",
    "MSFullscreenChange",
  ];
  events.forEach((evt) => document.addEventListener(evt, callback));
  return () => {
    events.forEach((evt) => document.removeEventListener(evt, callback));
  };
}
