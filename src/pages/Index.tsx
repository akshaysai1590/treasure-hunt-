import { GameProvider, useGame } from "@/context/GameContext";
import LoginScreen from "@/components/screens/LoginScreen";
import QRScanScreen from "@/components/screens/QRScanScreen";
import RoundScreen from "@/components/screens/RoundScreen";
import WinnerScreen from "@/components/screens/WinnerScreen";
import EliminatedScreen from "@/components/screens/EliminatedScreen";
import GlobalOverlay from "@/components/GlobalOverlay";
import { Loader2 } from "lucide-react";

const GameRouter = () => {
  const { gameState, isRehydrating } = useGame();

  if (isRehydrating) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen gap-4">
        <Loader2 className="w-10 h-10 text-primary animate-spin" />
        <p className="text-primary font-mono text-sm tracking-widest animate-pulse">RESTORING SESSION...</p>
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
  return (
    <GameProvider>
      <div className="min-h-screen bg-background">
        <GlobalOverlay />
        <GameRouter />
      </div>
    </GameProvider>
  );
};

export default Index;
