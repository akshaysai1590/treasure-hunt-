import { Button } from "@/components/ui/button";
import { requestFullscreen } from "@/lib/fullscreen";

interface RoundIntroProps {
    round: number;
    lifelines: number;
    onStart: () => void;
}

const roundData = [
    {
        color: "from-green-500/20 to-green-900/20",
        border: "border-green-500/40",
        badge: "🟢",
        icon: "🧠",
        title: "Round 1 – Logic & Aptitude",
        questions: [
            { label: "Logical Reasoning", points: 10 },
            { label: "Verbal Reasoning", points: 10 },
            { label: "Aptitude", points: 10 },
        ],
        timeLimit: "45 seconds per question",
        format: "Multiple Choice (4 options)",
        negativePoints: "-5 pts",
        totalPoints: 30,
        buttonText: "Start Round 1",
    },
    {
        color: "from-yellow-500/20 to-yellow-900/20",
        border: "border-yellow-500/40",
        badge: "🟡",
        icon: "💡",
        title: "Round 2 – Tech Riddles",
        questions: [
            { label: "Tech Riddle", points: 15 },
            { label: "Tech Riddle", points: 15 },
            { label: "Tech Riddle", points: 15 },
        ],
        timeLimit: "90 seconds (1.5 mins) per question",
        format: "Tech-based MCQs",
        negativePoints: "-7 pts",
        totalPoints: 45,
        buttonText: "Start Round 2",
    },
    {
        color: "from-orange-500/20 to-orange-900/20",
        border: "border-orange-500/40",
        badge: "🟠",
        icon: "⚡",
        title: "Round 3 – Rapid Fire",
        questions: [
            { label: "Fill in the Blanks", points: 8 },
            { label: "Match the Following", points: 8 },
            { label: "Keyword Identification", points: 8 },
            { label: "True / False", points: 8 },
            { label: "Output Prediction", points: 8 },
        ],
        timeLimit: "30 seconds per question",
        format: "No backtracking allowed",
        negativePoints: "-4 pts",
        totalPoints: 40,
        buttonText: "Start Rapid Fire",
    },
    {
        color: "from-red-500/20 to-red-900/20",
        border: "border-red-500/40",
        badge: "🔴",
        icon: "🏆",
        title: "Round 4 – Final DSA Challenge",
        questions: [
            { label: "DSA Concept", points: 15 },
            { label: "DSA Concept", points: 20 },
        ],
        timeLimit: "120 seconds (2 mins) per question",
        format: "This round determines your final ranking",
        negativePoints: "-7 to -10 pts",
        totalPoints: 35,
        buttonText: "Start Final Round",
    },
];

const RoundIntroPopup = ({ round, lifelines, onStart }: RoundIntroProps) => {
    const data = roundData[round - 1];
    if (!data) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md px-4">
            <div
                className={`w-full max-w-sm rounded-2xl border ${data.border} bg-gradient-to-b ${data.color} bg-card/95 backdrop-blur-xl p-6 shadow-2xl animate-pop-in`}
            >
                {/* Round badge */}
                <div className="text-center mb-1 text-2xl">{data.icon}</div>

                {/* Title */}
                <h2 className="text-lg font-bold text-center mb-4 neon-text">{data.title}</h2>

                {/* Questions list */}
                <div className="mb-3">
                    <p className="text-xs text-muted-foreground mb-2">
                        • Total Questions: {data.questions.length}
                    </p>
                    <div className="space-y-1.5 pl-2">
                        {data.questions.map((q, i) => (
                            <div key={i} className="flex justify-between items-center text-sm">
                                <span className="text-foreground/90">
                                    {i + 1}️⃣ {q.label}
                                </span>
                                <span className="text-primary font-mono text-xs">{q.points} pts</span>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Time & format */}
                <div className="space-y-1.5 mb-3 text-sm text-foreground/80">
                    <p>• ⏱ Time Limit: <span className="text-foreground">{data.timeLimit}</span></p>
                    <p>• 📋 Format: <span className="text-foreground">{data.format}</span></p>
                    <p>• 🔻 Wrong Answer: <span className="text-red-400 font-bold">{data.negativePoints}</span></p>
                </div>

                {/* Warning */}
                <div className="text-center text-sm font-semibold text-yellow-400 bg-yellow-500/10 rounded-lg py-2 px-3 mb-3">
                    ⚠️ If time expires, one lifeline will be deducted.
                </div>

                {/* Total points */}
                <div className="text-center mb-4">
                    <span className="text-lg font-bold neon-text">🎯 Total Points: {data.totalPoints}</span>
                </div>

                {/* Footer info */}
                <div className="flex justify-between text-xs text-muted-foreground mb-4 px-1">
                    <span>❤️ Lifelines: {lifelines} remaining</span>
                    <span>🏆 Score + Time = Rank</span>
                </div>

                {/* Start button */}
                <Button
                    onClick={() => {
                        requestFullscreen();
                        onStart();
                    }}
                    className="w-full h-11 font-display tracking-wider text-sm"
                >
                    {data.buttonText} 🚀
                </Button>
            </div>
        </div>
    );
};

export default RoundIntroPopup;
