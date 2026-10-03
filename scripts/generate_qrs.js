import QRCode from 'qrcode';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const outputDir = path.join(__dirname, '..', 'private-qrcodes');

if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

const passwordsFile = path.join(outputDir, 'passwords.json');
let passwords = {
    1: "r1",
    2: "r2",
    3: "r3",
    4: "r4"
};

if (fs.existsSync(passwordsFile)) {
    passwords = JSON.parse(fs.readFileSync(passwordsFile, 'utf8'));
} else {
    fs.writeFileSync(passwordsFile, JSON.stringify(passwords, null, 2));
    console.log(`Created default passwords.json in ${outputDir}. Edit this file and run again.`);
}

Object.entries(passwords).forEach(([round, password]) => {
    const filename = path.join(outputDir, `round-${round}.png`);
    QRCode.toFile(filename, password, {
        color: {
            dark: '#000000',
            light: '#0000'
        }
    }, function (err) {
        if (err) throw err;
        console.log(`Generated QR for Round ${round} securely in private-qrcodes folder.`);
    });
});
