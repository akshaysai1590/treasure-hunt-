-- Seed Data for Treasure Hunt

-- 1. Game Config (Passwords: 'player' and 'admin')
INSERT INTO game_config (id, entry_password_hash, admin_password_hash)
VALUES (
    1, 
    crypt('player', gen_salt('bf')), 
    crypt('z0EZ3WbUVkPunBxnffseakGZ', gen_salt('bf'))
)
ON CONFLICT (id) DO NOTHING;

-- 2. Game State
INSERT INTO game_state (id, is_paused, broadcast_message)
VALUES (1, false, NULL)
ON CONFLICT (id) DO NOTHING;

-- 3. Hints
INSERT INTO hints (round, hint_text) VALUES
(1, 'I''m the Jacket holding a badge 11001101 in decimal. Inside me, find the machine that stops humans from thermal throttling.'),
(2, 'Heyy I''m "h", but computer coded. That''s me. You are welcome, find the flat surface in me that holds every laptop.'),
(3, '"I''m the only Windows you don''t need to install, and I never crash." HTTP says 404 means Not Found. But my junior 304: Found'),
(4, 'I''m covered by a flat surface, which has No server, no login, no push notifications. Still I hold Information every single needs. I''m at the pattie of the burger you are in.')
ON CONFLICT (round) DO NOTHING;

-- 4. QR Codes (Passwords: 'r1', 'r2', 'r3', 'r4')
INSERT INTO qr_codes (round, code_hash) VALUES
(1, crypt('r1', gen_salt('bf'))),
(2, crypt('r2', gen_salt('bf'))),
(3, crypt('r3', gen_salt('bf'))),
(4, crypt('r4', gen_salt('bf')))
ON CONFLICT (round) DO NOTHING;

-- 5. Questions
TRUNCATE TABLE questions RESTART IDENTITY CASCADE;

INSERT INTO questions (id, round, pool_name, question_text, options, correct_index, points) VALUES
-- Round 1: Logic & Aptitude (10 pts each)
(1, 1, 'logical', 'Number Series: 2, 4, 8, 16, ___', '["24", "30", "32", "64"]'::jsonb, 2, 10),
(2, 1, 'aptitude', 'A farmer has 17 sheep. All but 9 run away. How many are left?', '["8", "9", "17", "0"]'::jsonb, 1, 10),
(3, 1, 'aptitude', 'What comes once in a minute, twice in a moment, but never in a thousand years', '["T", "M", "N", "E"]'::jsonb, 1, 10),

-- Round 2: Tech Riddles (15 pts each)
(4, 2, 'tech', 'I have keys but no locks, space but no room, and you can enter but cannot go inside. What am I?', '["Keyboard", "Map", "Piano", "Door"]'::jsonb, 0, 15),
(5, 2, 'tech', 'print(print("QR")) What is the second line of output? ', '["None", "Compilation error", "QR", "print(QR)"]'::jsonb, 0, 15),
(6, 2, 'tech', 'I store data permanently.', '["RAM", "Cache", "Hard Drive", "CPU"]'::jsonb, 2, 15),

-- Round 3: Rapid Fire (8 pts each)
(7, 3, 'fill', 'The protocol used to securely access websites is _____.', '["HTTP", "HTTPS", "TCP", "UDP"]'::jsonb, 1, 8),
(8, 3, 'match', 'CSS -> ?', '["Structure", "Style", "Script", "Server"]'::jsonb, 1, 8),
(9, 3, 'keyword', '"native" belongs to:', '["Java", "Python", "C++", "Ruby"]'::jsonb, 0, 8),
(10, 3, 'tf', 'Java is a compiled language because the Java compiler translates source code directly into native machine code executable by the operating system.', '["True", "False"]'::jsonb, 1, 8),
(11, 3, 'output', 'x = [1, 2, 3] 

print(x[-1])', '["3", "-1", "index out of bound ", "None"]'::jsonb, 0, 8),

-- Round 4: Final DSA Challenge (15 & 20 pts)
(12, 4, 'dsa', 'Which data structure uses LIFO?', '["Queue", "Stack", "Tree", "Graph"]'::jsonb, 1, 15),
(13, 4, 'dsa', 'i carry data  and i know where the next one is . I am neither the beginning nor the end , but i can be connected to both , What am I ?', '["Pointer", "Node", "Index", "Queue"]'::jsonb, 1, 20);
