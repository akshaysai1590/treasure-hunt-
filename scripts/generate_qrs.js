import QRCode from 'qrcode';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ⚠️ CHANGE THESE before the event! These must match the passwords in src/data/questions.ts
const passwords = {
    1: "round_1_change_me",
    2: "round_2_change_me",
    3: "round_3_change_me",
    4: "round_4_change_me"
};

const outputDir = path.join(__dirname, '..', 'public', 'qrcodes');

if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

Object.entries(passwords).forEach(([round, password]) => {
    const filename = path.join(outputDir, `round-${round}.png`);
    QRCode.toFile(filename, password, {
        color: {
            dark: '#000000',  // Blue dots
            light: '#0000' // Transparent background
        }
    }, function (err) {
        if (err) throw err;
        console.log(`Generated QR for Round ${round}: ${password}`);
    });
});
