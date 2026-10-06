import { useState, useEffect } from "react";
import { GameProvider, useGame } from "@/context/GameContext";
import LoginScreen from "@/components/screens/LoginScreen";
import QRScanScreen from "@/components/screens/QRScanScreen";
import RoundScreen from "@/components/screens/RoundScreen";
import WinnerScreen from "@/components/screens/WinnerScreen";
import EliminatedScreen from "@/components/screens/EliminatedScreen";
import GlobalOverlay from "@/components/GlobalOverlay";
import { Loader2, Maximize } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  isFullscreenActive,
  isFullscreenSupported,
  requestFullscreen,
  onFullscreenChange,
} from "@/lib/fullscreen";

const FullscreenGuard = () => {
  const { gameState } = useGame();
  const [fullscreenActive, setFullscreenActive] = useState(true);
  const supported = typeof window !== "undefined" && isFullscreenSupported();

  useEffect(() => {
    if (!supported) return;

    setFullscreenActive(isFullscreenActive());

    const cleanup = onFullscreenChange(() => {
      setFullscreenActive(isFullscreenActive());
    });

    return cleanup;
  }, [supported]);

  const isPlaying =
    gameState === "round" || gameState === "hint" || gameState === "qr-scan";

  if (!supported || fullscreenActive || !isPlaying) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/90 backdrop-blur-md px-4">
      <div className="w-full max-w-sm rounded-2xl border border-primary/40 bg-card p-6 shadow-2xl text-center animate-pop-in">
        <div className="w-14 h-14 mx-auto mb-4 rounded-full bg-primary/10 flex items-center justify-center text-primary">
          <Maximize className="w-7 h-7 animate-pulse" />
        </div>
        <h2 className="text-lg font-bold font-display neon-text mb-2">
          FULLSCREEN REQUIRED
        </h2>
        <p className="text-xs text-muted-foreground mb-6 leading-relaxed">
          The competition terminal must stay in fullscreen mode to prevent background assistance and maintain integrity.
        </p>
        <Button
          onClick={() => {
            requestFullscreen();
            setFullscreenActive(true);
          }}
          className="w-full h-11 font-display tracking-wider text-sm neon-border"
        >
          ENTER FULLSCREEN 🖥️
        </Button>
      </div>
    </div>
  );
};

const GameRouter = () => {
  const { gameState, isRehydrating } = useGame();

  if (isRehydrating) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen gap-4">
        <Loader2 className="w-10 h-10 text-primary animate-spin" />
        <p className="text-primary font-mono text-sm tracking-widest animate-pulse">
          RESTORING SESSION...
        </p>
      </div>
    );
  }

  switch (gameState) {
    case "login":
      return <LoginScreen />;
    case "qr-scan":
      return <QRScanScreen />;
    case "round":
    case "hint":
      return <RoundScreen />;
    case "winner":
      return <WinnerScreen />;
    case "eliminated":
      return <EliminatedScreen />;
    default:
      return <LoginScreen />;
  }
};

const Index = () => {
  // Anti-Cheat: Global event listeners preventing text copying, Google scan invocation, context menu
  useEffect(() => {
    const handleContextMenu = (e: MouseEvent) => {
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) {
        return;
      }
      e.preventDefault();
    };

    const handleSelectStart = (e: Event) => {
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) {
        return;
      }
      e.preventDefault();
    };

    const handleCopyCut = (e: ClipboardEvent) => {
      const target = e.target as HTMLElement | null;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) {
        return;
      }
      e.preventDefault();
    };

    const handleKeyDown = (e: KeyboardEvent) => {
      if (
        e.key === "F12" ||
        (e.ctrlKey && e.shiftKey && ["I", "i", "J", "j", "C", "c"].includes(e.key)) ||
        (e.ctrlKey && ["u", "U", "s", "S"].includes(e.key))
      ) {
        e.preventDefault();
      }
    };

    document.addEventListener("contextmenu", handleContextMenu);
    document.addEventListener("selectstart", handleSelectStart);
    document.addEventListener("copy", handleCopyCut);
    document.addEventListener("cut", handleCopyCut);
    window.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("contextmenu", handleContextMenu);
      document.removeEventListener("selectstart", handleSelectStart);
      document.removeEventListener("copy", handleCopyCut);
      document.removeEventListener("cut", handleCopyCut);
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, []);

  return (
    <GameProvider>
      <div className="min-h-screen bg-background">
        <FullscreenGuard />
        <GlobalOverlay />
        <GameRouter />
      </div>
    </GameProvider>
  );
};

export default Index;

