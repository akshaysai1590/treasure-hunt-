import React, { createContext, useContext, useCallback } from "react";

interface SoundContextType {
    playSound: (name: string) => void;
}

const SoundContext = createContext<SoundContextType | null>(null);

export const useSound = () => {
    const ctx = useContext(SoundContext);
    if (!ctx) throw new Error("useSound must be inside SoundProvider");
    return ctx;
};

export const SoundProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const playSound = useCallback((name: string) => {
        // Sound effects are optional — just log for debugging
        console.log("[Sound]", name);
    }, []);

    return (
        <SoundContext.Provider value={{ playSound }}>
            {children}
        </SoundContext.Provider>
    );
};
