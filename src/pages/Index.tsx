import { GameProvider, useGame } from "@/context/GameContext";
import LoginScreen from "@/components/screens/LoginScreen";
import QRScanScreen from "@/components/screens/QRScanScreen";
import RoundScreen from "@/components/screens/RoundScreen";
import WinnerScreen from "@/components/screens/WinnerScreen";
import EliminatedScreen from "@/components/screens/EliminatedScreen";
import GlobalOverlay from "@/components/GlobalOverlay";

const GameRouter = () => {
  const { gameState } = useGame();

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
