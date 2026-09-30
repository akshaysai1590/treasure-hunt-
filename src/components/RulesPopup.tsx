import { useState } from "react";
import { Button } from "@/components/ui/button";

interface RulesPopupProps {
    onComplete: () => void;
}

const slides = [
    {
        color: "from-green-500/20 to-green-900/20",
        border: "border-green-500/40",
        badge: "🟢",
        title: "🏆 Welcome to the Treasure Hunt!",
        items: [
            "The game consists of 4 rounds.",
            "Each round is unlocked only by scanning the correct QR code at the given location.",
            "Rounds must be completed in sequence.",
            "Your progress is tracked automatically.",
        ],
        warning: "⚠️ Skipping rounds is not allowed.",
        buttonText: "Next →",
    },
    {
        color: "from-yellow-500/20 to-yellow-900/20",
        border: "border-yellow-500/40",
        badge: "🟡",
        title: "⏱ Time & Scoring Rules",
        items: [
            "Each question has a fixed time limit.",
            "If time expires, one lifeline will be deducted.",
            "Correct answers increase your score.",
        ],
        extra: [
            "Final ranking is based on:",
            "1️⃣ Total Score",
            "2️⃣ Completion Time (for tie-breaker)",
        ],
        warning: "❤️ Manage your lifelines carefully!",
        buttonText: "Next →",
    },
    {
        color: "from-red-500/20 to-red-900/20",
        border: "border-red-500/40",
        badge: "🔴",
        title: "⚖️ Fair Play Guidelines",
        items: [
            "Only one device per team is allowed.",
            "Do not refresh or attempt to bypass rounds.",
            "Switching tabs, minimizing the app, or attempting to cheat will result in lifeline deduction.",
            "Any repeated unfair practice may lead to disqualification.",
        ],
        warning: null,
        buttonText: "Start Game 🚀",
        hasCheckbox: true,
    },
];

const RulesPopup = ({ onComplete }: RulesPopupProps) => {
    const [step, setStep] = useState(0);
    const [agreed, setAgreed] = useState(false);

    const current = slides[step];
    const isLast = step === slides.length - 1;

    const handleNext = () => {
        if (isLast) {
            onComplete();
        } else {
            setStep((s) => s + 1);
        }
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md px-4">
            <div
                className={`w-full max-w-sm rounded-2xl border ${current.border} bg-gradient-to-b ${current.color} bg-card/95 backdrop-blur-xl p-6 shadow-2xl animate-pop-in`}
                key={step}
            >
                {/* Step indicator */}
                <div className="flex justify-center gap-2 mb-4">
                    {slides.map((_, i) => (
                        <div
                            key={i}
                            className={`h-1.5 rounded-full transition-all duration-300 ${i === step ? "w-8 bg-primary" : i < step ? "w-4 bg-primary/50" : "w-4 bg-muted"
                                }`}
                        />
                    ))}
                </div>

                {/* Title */}
                <h2 className="text-xl font-bold text-center mb-4 neon-text">{current.title}</h2>

                {/* Rules list */}
                <ul className="space-y-2.5 mb-4">
                    {current.items.map((item, i) => (
                        <li key={i} className="flex items-start gap-2 text-sm text-foreground/90">
                            <span className="text-primary mt-0.5 shrink-0">•</span>
                            <span>{item}</span>
                        </li>
                    ))}
                </ul>

                {/* Extra info (for scoring slide) */}
                {"extra" in current && current.extra && (
                    <div className="mb-4 pl-2 space-y-1">
                        {current.extra.map((line, i) => (
                            <p key={i} className={`text-sm ${i === 0 ? "text-foreground/80" : "text-foreground/70 pl-2"}`}>
                                {line}
                            </p>
                        ))}
                    </div>
                )}

                {/* Warning / highlight */}
                {current.warning && (
                    <div className="text-center text-sm font-semibold text-yellow-400 bg-yellow-500/10 rounded-lg py-2 px-3 mb-4">
                        {current.warning}
                    </div>
                )}

                {/* Checkbox for fair play */}
                {"hasCheckbox" in current && current.hasCheckbox && (
                    <label className="flex items-center gap-2 cursor-pointer mb-4 text-sm text-foreground/80 hover:text-foreground transition-colors">
                        <input
                            type="checkbox"
                            checked={agreed}
                            onChange={(e) => setAgreed(e.target.checked)}
                            className="w-4 h-4 accent-primary rounded"
                        />
                        <span>☑️ I agree to follow all rules.</span>
                    </label>
                )}

                {/* Button */}
                <Button
                    onClick={handleNext}
                    disabled={isLast && !agreed}
                    className="w-full h-11 font-display tracking-wider text-sm"
                >
                    {current.buttonText}
                </Button>
            </div>
        </div>
    );
};

export default RulesPopup;
