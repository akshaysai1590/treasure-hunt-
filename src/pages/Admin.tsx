import { useState } from "react";
import { callRpc } from "@/lib/api";
import { formatTime } from "@/data/leaderboard";
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
                const list = res.participants || [];
                // Sort by highest score, tie-broken by fastest completion time
                const sorted = [...list].sort((a, b) => {
                    if (b.score !== a.score) return b.score - a.score;
                    if (a.completed && !b.completed) return -1;
                    if (!a.completed && b.completed) return 1;
                    const timeA = a.completion_time ?? 999999;
                    const timeB = b.completion_time ?? 999999;
                    return timeA - timeB;
                });
                setParticipants(sorted);
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
                toast.info(`Game is now ${newStatus ? "PAUSED" : "LIVE"}`);
            } else {
                toast.error(res.error || "Could not toggle pause");
            }
        } catch {
            toast.error("Failed to toggle pause");
        }
    };

    const sendBroadcast = async () => {
        if (!broadcastMsg.trim()) return;
        try {
            const res = await callRpc<AdminResponse>("admin_broadcast", { p_password: password, p_message: broadcastMsg.trim() });
            if (res.success) {
                toast.success("Broadcast sent to all devices! 📢");
                setBroadcastMsg("");
                // Auto-clear message in 10 seconds locally to reflect the game reset
                setTimeout(async () => {
                    await callRpc<AdminResponse>("admin_broadcast", { p_password: password, p_message: "" });
                }, 10000);
            } else {
                toast.error(res.error || "Could not broadcast");
            }
        } catch {
            toast.error("Broadcast failed.");
        }
    };

    // ============ UI ============
    if (!authenticated) {
        return (
            <div className="flex flex-col items-center justify-center min-h-screen gap-4 p-4">
                <h1 className="text-2xl font-bold font-display neon-text">Admin Access</h1>
                <Input
                    type="password"
                    value={password}
                    onChange={e => setPassword(e.target.value)}
                    placeholder="Enter Admin Passkey"
                    className="max-w-xs text-center"
                    onKeyDown={e => e.key === "Enter" && checkAuth()}
                />
                <Button onClick={checkAuth} className="w-full max-w-xs font-display tracking-wider">Login</Button>
            </div>
        );
    }

    return (
        <div className="p-4 md:p-8 min-h-screen bg-background pb-20">
            <div className="flex flex-col gap-6 mb-8">
                <div className="flex justify-between items-center flex-wrap gap-2">
                    <div>
                        <h1 className="text-2xl font-bold font-display neon-text">Game Control Center</h1>
                        <p className="text-xs text-muted-foreground mt-1">
                            🏆 Scoreboard sorted by Highest Score, tie-broken by Fastest Time.
                        </p>
                    </div>
                    <div className="flex gap-2">
                        <Button onClick={fetchParticipants} variant="outline" size="sm">Refresh</Button>
                        <Button onClick={resetGame} variant="destructive" size="sm">RESET GAME</Button>
                    </div>
                </div>

                {/* GOD MODE CONTROLS */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 bg-muted/20 p-4 rounded-lg border border-primary/20">
                    <div className="flex gap-2 items-center">
                        <Input
                            value={broadcastMsg}
                            onChange={(e) => setBroadcastMsg(e.target.value)}
                            placeholder="📢 Broadcast Announcement to All Devices..."
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

            {loading ? <p className="text-center text-muted-foreground py-8">Loading scoreboard...</p> : (
                <div className="border rounded-md bg-card/50 overflow-x-auto">
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead className="w-16 text-center">Rank</TableHead>
                                <TableHead>Team / Contestant</TableHead>
                                <TableHead className="text-center">Score</TableHead>
                                <TableHead className="text-center">Time Taken</TableHead>
                                <TableHead className="text-center">Status</TableHead>
                                <TableHead className="text-right">Score Adjust</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {participants.map((p, index) => {
                                const rank = index + 1;
                                const medal = rank === 1 ? "🥇" : rank === 2 ? "🥈" : rank === 3 ? "🥉" : `#${rank}`;
                                return (
                                    <TableRow key={p.id} className={rank <= 3 ? "bg-primary/5" : ""}>
                                        <TableCell className="text-center font-bold text-sm">
                                            {medal}
                                        </TableCell>
                                        <TableCell className="font-medium text-sm">
                                            {p.username}
                                        </TableCell>
                                        <TableCell className="text-center">
                                            <span className="font-mono font-bold text-primary text-base">
                                                {p.score} pts
                                            </span>
                                        </TableCell>
                                        <TableCell className="text-center font-mono text-xs text-muted-foreground">
                                            {p.completed && p.completion_time ? (
                                                <span className="text-green-400 font-semibold">
                                                    ⏱ {formatTime(p.completion_time)}
                                                </span>
                                            ) : (
                                                <span>⏳ In Progress</span>
                                            )}
                                        </TableCell>
                                        <TableCell className="text-center">
                                            <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                                                p.completed 
                                                    ? "bg-green-500/20 text-green-400 border border-green-500/30" 
                                                    : "bg-blue-500/20 text-blue-400 border border-blue-500/30"
                                            }`}>
                                                {p.completed ? "🏆 WINNER" : "PLAYING"}
                                            </span>
                                        </TableCell>
                                        <TableCell className="text-right">
                                            <div className="flex items-center justify-end gap-1">
                                                <Button 
                                                    size="sm" 
                                                    variant="outline" 
                                                    className="h-7 text-xs text-green-400 border-green-500/30 hover:bg-green-500/10" 
                                                    onClick={() => adjustScore(p.id, p.score, 10)}
                                                >
                                                    +10
                                                </Button>
                                                <Button 
                                                    size="sm" 
                                                    variant="outline" 
                                                    className="h-7 text-xs text-red-400 border-red-500/30 hover:bg-red-500/10" 
                                                    onClick={() => adjustScore(p.id, p.score, -10)}
                                                >
                                                    -10
                                                </Button>
                                            </div>
                                        </TableCell>
                                    </TableRow>
                                );
                            })}
                        </TableBody>
                    </Table>
                </div>
            )}
        </div>
    );
};

export default Admin;
