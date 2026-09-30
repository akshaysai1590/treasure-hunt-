import { useGame } from "@/context/GameContext";
import { useEffect, useState } from "react";
import { toast } from "sonner";

const GlobalOverlay = () => {
    const { isPaused, broadcastMessage } = useGame();

    const [lastMessage, setLastMessage] = useState<string | null>(null);

    useEffect(() => {
        if (broadcastMessage && broadcastMessage !== lastMessage) {
            const content = broadcastMessage.replace("📢 ", "");
            toast(content, {
                duration: 8000,
                style: {
                    background: "#0d0d0d",
                    border: "2px solid #00f0ff",
                    color: "#00f0ff",
                    fontSize: "1.2rem",
                    boxShadow: "0 0 20px #00f0ff",
                },
                position: "top-center"
            });
            setLastMessage(broadcastMessage);
        }
        if (!broadcastMessage && lastMessage) {
            setLastMessage(null);
        }
    }, [broadcastMessage, lastMessage]);

    return (
        <>
            {/* Broadcast Banner */}
            {broadcastMessage && (
                <div style={{
                    position: "fixed",
                    top: 0,
                    left: 0,
                    right: 0,
                    zIndex: 9999,
                    background: "linear-gradient(135deg, #0d0d0d 0%, #001a1a 100%)",
                    border: "2px solid #00f0ff",
                    color: "#00f0ff",
                    padding: "16px",
                    textAlign: "center",
                    fontSize: "1.3rem",
                    fontWeight: "bold",
                    boxShadow: "0 0 30px #00f0ff",
                    animation: "pulse 2s infinite",
                }}>
                    {broadcastMessage}
                </div>
            )}

            {/* Pause Overlay */}
            {isPaused && (
                <div className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-black/90 backdrop-blur-sm animate-in fade-in">
                    <div className="text-center space-y-4 p-8 border border-red-500/50 bg-red-950/20 rounded-xl neon-border border-red-500 max-w-md mx-4">
                        <h1 className="text-4xl font-display font-bold text-red-500 animate-pulse">
                            GAME PAUSED
                        </h1>
                        <p className="text-muted-foreground text-lg">
                            Stand by for instructions from Admin.
                        </p>
                        <div className="h-1 w-full bg-red-900/50 overflow-hidden rounded-full mt-4">
                            <div className="h-full bg-red-500 animate-[pulse_2s_infinite] w-full origin-left"></div>
                        </div>
                    </div>
                </div>
            )}
        </>
    );
};

export default GlobalOverlay;
