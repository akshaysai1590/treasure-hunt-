import { useState, useEffect } from "react";
import { callRpc } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { toast } from "sonner";

interface Participant {
    id: string;
    username: string;
    score: number;
    completed: boolean;
    completion_time: number | null;
}

interface AdminResponse {
    success: boolean;
    error?: string;
    participants?: Participant[];
}

const Admin = () => {
    const [password, setPassword] = useState("");
    const [authenticated, setAuthenticated] = useState(false);
    const [participants, setParticipants] = useState<Participant[]>([]);
    const [loading, setLoading] = useState(false);
    const [broadcastMsg, setBroadcastMsg] = useState("");
    const [isPaused, setIsPaused] = useState(false);

    const checkAuth = async () => {
        if (!password.trim()) {
            toast.error("Please enter a password");
            return;
        }
        try {
            const res = await callRpc<AdminResponse>("admin_login", { p_password: password });
            if (res.success) {
                setAuthenticated(true);
                fetchParticipants();
            } else {
                toast.error(res.error || "Invalid Password");
            }
        } catch {
            toast.error("Authentication failed. Check your network.");
        }
    };

    const fetchParticipants = async () => {
        setLoading(true);
        try {
            const res = await callRpc<AdminResponse>("admin_list_participants", { p_password: password });
            if (res.success) {
                setParticipants(res.participants || []);
            } else {
                toast.error(res.error || "Failed to fetch data");
            }
        } catch {
            toast.error("Error communicating with server.");
        } finally {
            setLoading(false);
        }
    };

    // ============ GAME ACTIONS ============
    const resetGame = async () => {
        if (!confirm("ARE YOU SURE? This will RESET all scores to 0.")) return;
        try {
            const res = await callRpc<AdminResponse>("admin_reset_game", { p_password: password });
            if (res.success) {
                toast.success("Game Reset for Everyone ✅");
                fetchParticipants();
            } else {
                toast.error(res.error || "Reset failed");
            }
        } catch {
            toast.error("Reset failed due to a network error.");
        }
    };

    const adjustScore = async (id: string, _currentScore: number, amount: number) => {
        try {
            const res = await callRpc<AdminResponse>("admin_adjust_score", { p_password: password, p_user_id: id, p_amount: amount });
            if (res.success) {
                toast.success(`Score ${amount > 0 ? '+' : ''}${amount}`);
                fetchParticipants();
            } else {
                toast.error(res.error || "Score update failed");
            }
        } catch {
            toast.error("Network error while updating score.");
        }
    };

    // ============ GOD MODE: PAUSE / BROADCAST ============
    const togglePause = async () => {
        const newStatus = !isPaused;
        try {
            const res = await callRpc<AdminResponse>("admin_pause_game", { p_password: password, p_paused: newStatus });
            if (res.success) {
                setIsPaused(newStatus);
                toast.info(newStatus ? "GAME PAUSED ⏸️" : "GAME RESUMED ▶️");
            } else {
                toast.error(res.error || "Pause toggle failed!");
            }
        } catch {
            toast.error("Failed to update game pause state.");
        }
    };

    const sendBroadcast = async () => {
        if (!broadcastMsg.trim()) {
            toast.error("Please type a message first");
            return;
        }

        const message = `📢 ${broadcastMsg.trim()}`;
        try {
            const res = await callRpc<AdminResponse>("admin_broadcast", { p_password: password, p_message: message });
            
            if (res.success) {
                toast.success("📢 Broadcast Sent!");
                setBroadcastMsg("");

                // Reset message back after 10s
                setTimeout(async () => {
                    try {
                        await callRpc<AdminResponse>("admin_broadcast", { p_password: password, p_message: null });
                    } catch {
                        // ignore background reset error
                    }
                }, 10000);
            } else {
                toast.error(res.error || "Broadcast failed");
            }
        } catch {
            toast.error("Network error while sending broadcast.");
        }
    };

    // ============ UI ============
    if (!authenticated) {
        return (
            <div className="flex flex-col items-center justify-center min-h-screen gap-4">
                <h1 className="text-xl font-bold">Admin Access</h1>
                <Input
                    type="password"
                    value={password}
                    onChange={e => setPassword(e.target.value)}
                    placeholder="Enter Passkey"
                    className="max-w-xs"
                    onKeyDown={e => e.key === "Enter" && checkAuth()}
                />
                <Button onClick={checkAuth}>Login</Button>
            </div>
        );
    }

    return (
        <div className="p-4 md:p-8 min-h-screen bg-background pb-20">
            <div className="flex flex-col gap-6 mb-8">
                <div className="flex justify-between items-center flex-wrap gap-2">
                    <h1 className="text-2xl font-bold neon-text">Game Control Center</h1>
                    <div className="flex gap-2">
                        <Button onClick={fetchParticipants} variant="outline">Refresh</Button>
                        <Button onClick={resetGame} variant="destructive">RESET GAME</Button>
                    </div>
                </div>

                {/* GOD MODE CONTROLS */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 bg-muted/20 p-4 rounded-lg border border-primary/20">
                    <div className="flex gap-2 items-center">
                        <Input
                            value={broadcastMsg}
                            onChange={(e) => setBroadcastMsg(e.target.value)}
                            placeholder="📢 Broadcast Message to All..."
                            onKeyDown={e => e.key === "Enter" && sendBroadcast()}
                        />
                        <Button onClick={sendBroadcast} variant="default">SEND</Button>
                    </div>
                    <div className="flex gap-4 items-center justify-end">
                        <span className="font-mono text-sm">{isPaused ? "STATUS: PAUSED ⏸️" : "STATUS: LIVE 🟢"}</span>
                        <Button
                            onClick={togglePause}
                            variant={isPaused ? "secondary" : "destructive"}
                        >
                            {isPaused ? "RESUME GAME ▶️" : "PAUSE GAME ⏸️"}
                        </Button>
                    </div>
                </div>
            </div>

            {loading ? <p>Loading...</p> : (
                <Table className="border rounded-md bg-card/50">
                    <TableHeader>
                        <TableRow>
                            <TableHead>Username</TableHead>
                            <TableHead>Score</TableHead>
                            <TableHead>Status</TableHead>
                            <TableHead>Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {participants.map((p) => (
                            <TableRow key={p.id}>
                                <TableCell className="font-medium">{p.username}</TableCell>
                                <TableCell>
                                    <div className="flex items-center gap-1">
                                        {p.score}
                                        <div className="flex flex-col">
                                            <button onClick={() => adjustScore(p.id, p.score, 10)} className="text-[10px] bg-green-900 px-1 rounded hover:bg-green-700">▲</button>
                                            <button onClick={() => adjustScore(p.id, p.score, -10)} className="text-[10px] bg-red-900 px-1 rounded hover:bg-red-700">▼</button>
                                        </div>
                                    </div>
                                </TableCell>
                                <TableCell>{p.completed ? "🏆 WINNER" : "PLAYING"}</TableCell>
                                <TableCell>
                                    <Button size="sm" variant="secondary" className="h-7 text-xs" onClick={() => adjustScore(p.id, p.score, 10)}>
                                        +10 🪙
                                    </Button>
                                </TableCell>
                            </TableRow>
                        ))}
                    </TableBody>
                </Table>
            )}
        </div>
    );
};

export default Admin;
