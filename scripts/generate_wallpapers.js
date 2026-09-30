import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const outputDir = path.join(__dirname, '..', 'public', 'wallpapers');
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

const wallpapers = [
    { name: "round-1-wall.svg", color: "#00ff00", text: "GLITCH PROTOCOL INITIATED" },
    { name: "round-2-wall.svg", color: "#0000ff", text: "SYSTEM BREACH DETECTED" },
    { name: "round-3-wall.svg", color: "#ff00ff", text: "CORE ACCESS GRANTED" },
    { name: "round-4-wall.svg", color: "#ff0000", text: "REALITY RESTORED" }
];

wallpapers.forEach(wp => {
    const svgContent = `
<svg width="1080" height="1920" xmlns="http://www.w3.org/2000/svg">
    <rect width="100%" height="100%" fill="#111" />
    <rect x="10%" y="10%" width="80%" height="80%" fill="none" stroke="${wp.color}" stroke-width="10" />
    <text x="50%" y="50%" font-family="monospace" font-size="60" fill="${wp.color}" text-anchor="middle" dominant-baseline="middle">
        ${wp.text}
    </text>
    <text x="50%" y="90%" font-family="monospace" font-size="30" fill="#555" text-anchor="middle">
        Treasure Quest Navigator
    </text>
</svg>`;

    fs.writeFileSync(path.join(outputDir, wp.name), svgContent.trim());
    console.log(`Generated ${wp.name}`);
});
