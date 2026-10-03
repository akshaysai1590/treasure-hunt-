-- Seed Data for Treasure Hunt

-- 1. Game Config (Passwords: 'player' and 'admin')
INSERT INTO game_config (id, entry_password_hash, admin_password_hash)
VALUES (
    1, 
    crypt('player', gen_salt('bf')), 
    crypt('admin', gen_salt('bf'))
)
ON CONFLICT (id) DO NOTHING;

-- 2. Game State
INSERT INTO game_state (id, is_paused, broadcast_message)
VALUES (1, false, NULL)
ON CONFLICT (id) DO NOTHING;

-- 3. Hints
INSERT INTO hints (round, hint_text) VALUES
(1, 'Hint for Round 2: Search near the big oak tree.'),
(2, 'Hint for Round 3: Check the library entrance.'),
(3, 'Hint for Round 4: Find the computer lab.'),
(4, 'Final Hint: The treasure is in the cafeteria.')
ON CONFLICT (round) DO NOTHING;

-- 4. QR Codes (Passwords: 'r1', 'r2', 'r3', 'r4')
INSERT INTO qr_codes (round, code_hash) VALUES
(1, crypt('r1', gen_salt('bf'))),
(2, crypt('r2', gen_salt('bf'))),
(3, crypt('r3', gen_salt('bf'))),
(4, crypt('r4', gen_salt('bf')))
ON CONFLICT (round) DO NOTHING;

-- 5. Questions
-- Placeholders covering all pools required by the game logic
TRUNCATE TABLE questions RESTART IDENTITY CASCADE;

INSERT INTO questions (round, pool_name, question_text, options, correct_index, points) VALUES
-- Round 1 (Logic, Verbal, Aptitude)
(1, 'logical', 'Number Series: 2, 4, 8, 16, ___', '["24", "30", "32", "64"]', 2, 10),
(1, 'verbal', 'Antonym of "Fast"', '["Quick", "Slow", "Rapid", "Speedy"]', 1, 10),
(1, 'aptitude', '10 + 10 * 0 = ?', '["0", "10", "20", "100"]', 1, 10),

-- Round 2 (Tech Riddles)
(2, 'tech', 'I have keys but no locks. What am I?', '["Keyboard", "Map", "Piano", "Door"]', 0, 15),
(2, 'tech', 'I am a brain of the computer.', '["RAM", "CPU", "Monitor", "Mouse"]', 1, 15),
(2, 'tech', 'I store data permanently.', '["RAM", "Cache", "Hard Drive", "CPU"]', 2, 15),

-- Round 3 (Fill, Match, Keyword, TF, Output)
(3, 'fill', 'HTML stands for HyperText ___ Language.', '["Markup", "Machine", "Maker", "Mix"]', 0, 8),
(3, 'match', 'CSS -> ?', '["Structure", "Style", "Script", "Server"]', 1, 8),
(3, 'keyword', '"def" belongs to:', '["Java", "Python", "C++", "Ruby"]', 1, 8),
(3, 'tf', 'Java is compiled.', '["True", "False"]', 0, 8),
(3, 'output', 'print(2+2)', '["22", "4", "Error", "None"]', 1, 8),

-- Round 4 (DSA)
(4, 'dsa', 'Which data structure uses LIFO?', '["Queue", "Stack", "Tree", "Graph"]', 1, 15),
(4, 'dsa', 'Which traversal visits left, root, right?', '["Preorder", "Inorder", "Postorder", "Level"]', 1, 20);
