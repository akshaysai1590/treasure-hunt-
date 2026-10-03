import { useRef, useState } from "react";
import { useGame } from "@/context/GameContext";
import { useSound } from "@/context/SoundContext";
import { ScanLine, Loader2 } from "lucide-react";
import GameHeader from "@/components/GameHeader";
import { Scanner } from "@yudiel/react-qr-scanner";
import { toast } from "sonner";
import { callRpc } from "@/lib/api";

interface VerifyQrResponse {
  success: boolean;
  error?: string;
  stage?: string;
}

const QRScanScreen = () => {
  const { currentRound, setGameState } = useGame();
  const { playSound } = useSound();
  const [isVerifying, setIsVerifying] = useState(false);
  const isScanningRef = useRef(false);

  const handleScan = async (result: string) => {
    if (!result || isScanningRef.current) return;
    isScanningRef.current = true;
    setIsVerifying(true);
    playSound("scan");

    try {
      const token = localStorage.getItem("session_token");
      const res = await callRpc<VerifyQrResponse>("verify_qr", { p_session: token, p_code: result.trim() });
      if (res.success) {
        playSound("correct");
        toast.success("Access Granted! Proceeding to next round.");
        setGameState("round");
      } else {
        playSound("wrong");
        toast.error(res.error || "Access Denied! Invalid QR Code.");
        // Cooldown before allowing next scan attempt
        setTimeout(() => {
          isScanningRef.current = false;
          setIsVerifying(false);
        }, 1500);
      }
    } catch {
      playSound("wrong");
      toast.error("Error verifying QR Code. Please try again.");
      setTimeout(() => {
        isScanningRef.current = false;
        setIsVerifying(false);
      }, 1500);
    }
  };




  return (
    <div className="flex flex-col min-h-screen">
      <GameHeader />
      <div className="flex flex-col items-center justify-center flex-1 px-6 gap-6">
        <div className="relative w-64 h-64 rounded-2xl overflow-hidden border-2 border-dashed border-primary/40 flex items-center justify-center animate-pop-in bg-black/20">
          <Scanner
            onScan={(result) => {
              if (result && result.length > 0) {
                handleScan(result[0].rawValue);
              }
            }}
            components={{ finder: false }}
            styles={{ container: { width: "100%", height: "100%" } }}
          />
          <ScanLine className="absolute w-full h-1/2 text-primary animate-pulse-neon pointer-events-none z-10 opacity-50" />
          {isVerifying && (
            <div className="absolute inset-0 bg-background/80 backdrop-blur-sm flex flex-col items-center justify-center gap-2 z-20">
              <Loader2 className="w-8 h-8 text-primary animate-spin" />
              <span className="text-xs font-mono text-primary animate-pulse">VERIFYING CODE...</span>
            </div>
          )}
        </div>

        <p className="text-xs text-muted-foreground text-center max-w-xs">
          Use your phone&apos;s camera/flash controls if you need extra light.
        </p>

        <div className="text-center">
          <h2 className="font-display text-lg neon-text mb-2">Scan QR Code</h2>
          <p className="text-muted-foreground text-sm max-w-xs">
            Find the QR code at the location and scan it to start Round {currentRound}
          </p>
        </div>

      </div>
    </div>
  );
};

export default QRScanScreen;
