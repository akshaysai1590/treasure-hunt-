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

INSERT INTO questions (round, pool_name, question_text, options, correct_index, points) VALUES
-- Round 1: Easy (10 pts)
(1, 'logical', 'A bat and a ball cost $1.10 in total. The bat costs $1.00 more than the ball. How much does the ball cost?', '["$0.10", "$0.05", "$1.00", "$0.50"]', 1, 10),
(1, 'logical', 'Divide 30 by half and add 10. What do you get?', '["25", "70", "40", "15"]', 1, 10),
(1, 'logical', 'T/F: A leap year happens exactly every 4 years without exception.', '["True", "False"]', 1, 10),
(1, 'logical', 'Some months have 31 days, others have 30. How many have 28?', '["1", "12", "0", "6"]', 1, 10),
(1, 'aptitude', 'A farmer has 17 sheep, and all but 9 die. How many are left?', '["17", "8", "9", "0"]', 2, 10),
(1, 'logical', 'How many legs does a spider have?', '["6", "8", "10", "4"]', 1, 10),
(1, 'aptitude', 'T/F: The Great Wall of China is the only man-made object visible from space with the naked eye.', '["True", "False"]', 1, 10),
(1, 'aptitude', 'If you overtake the 2nd person in a race, what position are you in?', '["1st", "2nd", "3rd", "Last"]', 1, 10),
(1, 'verbal', 'What is the antonym of ''Ameliorate''?', '["Worsen", "Improve", "Examine", "Create"]', 0, 10),
(1, 'verbal', 'Which of these words is not a synonym for ''happy''?', '["Joyful", "Elated", "Melancholy", "Cheerful"]', 2, 10),

-- Round 2: Medium (20 pts)
(2, 'tech', 'What is the primary function of a DNS?', '["Host websites", "Translate domain names to IP addresses", "Encrypt data", "Route packets physically"]', 1, 20),
(2, 'tech', 'T/F: The IP address 256.0.0.1 is valid in IPv4.', '["True", "False"]', 1, 20),
(2, 'logical', 'What is 20% of 30% of 100?', '["6", "5", "60", "0.6"]', 0, 20),
(2, 'verbal', 'What is the antonym of ''Ephemeral''?', '["Temporary", "Permanent", "Ethereal", "Fleeting"]', 1, 20),
(2, 'logical', 'A train is moving at 60 mph. How far does it travel in 45 minutes?', '["30 miles", "60 miles", "45 miles", "50 miles"]', 2, 20),
(2, 'tech', 'T/F: A MAC address changes every time you connect to a new WiFi network.', '["True", "False"]', 1, 20),
(2, 'verbal', 'Which word is spelled correctly?', '["Accomodate", "Accommodate", "Acomodate", "Acommodate"]', 1, 20),
(2, 'logical', 'If 3 cats catch 3 mice in 3 minutes, how many cats catch 100 mice in 100 minutes?', '["100", "3", "300", "33"]', 1, 20),
(2, 'tech', 'What does the ''S'' in HTTPS stand for?', '["Standard", "System", "Secure", "Socket"]', 2, 20),
(2, 'logical', 'What is the next prime number after 7?', '["9", "11", "13", "8"]', 1, 20),
(2, 'tech', 'Which of these is NOT a Linux distribution?', '["Ubuntu", "FreeBSD", "Fedora", "Debian"]', 1, 20),
(2, 'verbal', 'T/F: ''Gullible'' is in the dictionary.', '["True", "False"]', 0, 20),
(2, 'logical', 'If a triangle has a 90 degree angle, what is the sum of the other two angles?', '["90", "180", "45", "100"]', 0, 20),
(2, 'tech', 'T/F: RAM is a type of non-volatile memory.', '["True", "False"]', 1, 20),
(2, 'logical', 'If x + y = 10 and x - y = 4, what is the value of x * y?', '["24", "16", "21", "25"]', 2, 20),

-- Round 3: Hard (30 pts)
(3, 'fill', 'The _____ test evaluates a machine''s ability to exhibit intelligent behavior equivalent to a human.', '["Turing", "Einstein", "Asimov", "Babbage"]', 0, 30),
(3, 'output', 'What does `bool("False")` evaluate to in Python?', '["True", "False", "None", "Error"]', 0, 30),
(3, 'tf', 'T/F: In JavaScript, `typeof null` returns "object".', '["True", "False"]', 0, 30),
(3, 'keyword', 'Which keyword is used to declare a function in Rust?', '["func", "def", "fn", "function"]', 2, 30),
(3, 'tf', 'T/F: Floating point arithmetic is perfectly accurate in most programming languages.', '["True", "False"]', 1, 30),
(3, 'output', 'In JavaScript, what does `0.1 + 0.2 === 0.3` evaluate to?', '["True", "False", "Undefined", "SyntaxError"]', 1, 30),
(3, 'keyword', 'Which HTTP status code means "I''m a teapot"?', '["404", "500", "418", "403"]', 2, 30),
(3, 'fill', 'The concept where a function calls itself is known as _____.', '["Iteration", "Recursion", "Delegation", "Inheritance"]', 1, 30),
(3, 'tf', 'T/F: The primary colors of additive light are Red, Yellow, and Blue.', '["True", "False"]', 1, 30),
(3, 'match', 'Which sort algorithm has an average time complexity of O(n log n) but worst-case of O(n^2)?', '["Merge Sort", "Quicksort", "Heap Sort", "Bubble Sort"]', 1, 30),
(3, 'output', 'What is `[] == ![]` in JavaScript?', '["True", "False", "Error", "Undefined"]', 0, 30),
(3, 'tf', 'T/F: An anagram of "Eleven plus two" is "Twelve plus one".', '["True", "False"]', 0, 30),
(3, 'fill', 'In a Git repository, the `____` command applies the changes from one specific commit onto another branch.', '["merge", "rebase", "cherry-pick", "fetch"]', 2, 30),
(3, 'match', 'If all Bloops are Razzies and all Razzies are Lazzies, are all Bloops definitely Lazzies?', '["Yes", "No", "Maybe", "Impossible to tell"]', 0, 30),
(3, 'tf', 'T/F: A byte has always been exactly 8 bits on all computer systems historically.', '["True", "False"]', 1, 30),
(3, 'keyword', 'Which programming language is heavily associated with the concept of "monads"?', '["Java", "C++", "Haskell", "Python"]', 2, 30),
(3, 'output', 'In Python, what is the output of `print(type(lambda: None))`?', '["<class ''lambda''>", "<class ''function''>", "<class ''NoneType''>", "Error"]', 1, 30),
(3, 'match', 'Which design pattern ensures a class has only one instance?', '["Factory", "Observer", "Singleton", "Decorator"]', 2, 30),
(3, 'fill', 'SQL injection can often be prevented by using _____ statements.', '["Prepared", "Compiled", "Dynamic", "Static"]', 0, 30),
(3, 'output', 'What does `print(2 ** 3 ** 2)` evaluate to in Python?', '["64", "512", "72", "256"]', 1, 30),

-- Round 4: Brain Teasers (50 pts)
(4, 'brainteaser', 'What disappears as soon as you say its name?', '["A ghost", "Silence", "A shadow", "A secret"]', 1, 50),
(4, 'brainteaser', 'T/F: It is legal for a man in California to marry his widow''s sister.', '["True", "False"]', 1, 50),
(4, 'brainteaser', 'A woman shoots her husband, holds him under water, and hangs him. Later they go to dinner. How?', '["She is a doctor", "It was a play", "She is a photographer", "He is a zombie"]', 2, 50),
(4, 'brainteaser', 'What has words, but never speaks?', '["A parrot", "A book", "A radio", "A mime"]', 1, 50),
(4, 'brainteaser', 'What belongs to you, but other people use it more than you do?', '["Your money", "Your house", "Your name", "Your car"]', 2, 50),
(4, 'brainteaser', 'David''s parents have three sons: Snap, Crackle, and what''s the name of the third son?', '["Pop", "David", "John", "Crunch"]', 1, 50),
(4, 'brainteaser', 'T/F: You can drop a raw egg onto a concrete floor without cracking it.', '["True", "False"]', 0, 50),
(4, 'brainteaser', 'Forward I am heavy, but backward I am not. What am I?', '["A truck", "The word ''ton''", "A mirror", "Gravity"]', 1, 50),
(4, 'brainteaser', 'If an electric train is moving north at 100mph and a wind is blowing west at 10mph, which way does the smoke blow?', '["North", "West", "South-West", "There is no smoke"]', 3, 50),
(4, 'brainteaser', 'What has one eye, but can''t see?', '["A bat", "A hurricane", "A needle", "Both B and C"]', 3, 50),
(4, 'brainteaser', 'You draw a line. Without touching it, how do you make the line longer?', '["Blow on it", "Draw a shorter line next to it", "Erase it", "Fold the paper"]', 1, 50),
(4, 'brainteaser', 'What room do ghosts avoid?', '["The living room", "The bedroom", "The basement", "The attic"]', 0, 50),
(4, 'brainteaser', 'T/F: A man who shaves 20 times a day still has a full beard.', '["True", "False"]', 0, 50),
(4, 'brainteaser', 'The more of this there is, the less you see. What is it?', '["Light", "Fog", "Darkness", "Water"]', 2, 50),
(4, 'brainteaser', 'I follow you all the time and copy your every move, but you can''t touch me. What am I?', '["A stalker", "A reflection", "Your shadow", "An echo"]', 2, 50),
(4, 'brainteaser', 'What gets wetter as it dries?', '["A sponge", "A towel", "A cloud", "A mop"]', 1, 50),
(4, 'brainteaser', 'T/F: If there are 3 apples and you take away 2, you have 1 apple.', '["True", "False"]', 1, 50),
(4, 'brainteaser', 'I am an odd number. Take away a letter and I become even. What number am I?', '["Seven", "Nine", "Eleven", "One"]', 0, 50),
(4, 'brainteaser', 'Which is heavier: a ton of bricks or a ton of feathers?', '["Bricks", "Feathers", "They weigh the same", "Depends on gravity"]', 2, 50),
(4, 'brainteaser', 'If a rooster lays an egg on the exact peak of a barn roof, which side will the egg roll down?', '["Left", "Right", "Neither, roosters don''t lay eggs", "It will balance"]', 2, 50),
(4, 'brainteaser', 'What month of the year has 28 days?', '["February", "None", "Leap year months", "All of them"]', 3, 50),
(4, 'brainteaser', 'What has a head and a tail but no body?', '["A snake", "A coin", "A comet", "A worm"]', 1, 50),
(4, 'brainteaser', 'T/F: In a footrace, if you pass the person in second place, you are now in first place.', '["True", "False"]', 1, 50),
(4, 'brainteaser', 'Two fathers and two sons go fishing. They catch exactly 3 fish, and each gets 1. How?', '["One fish was pregnant", "They caught a whale", "Grandfather, father, and son", "Someone stole a fish"]', 2, 50),
(4, 'brainteaser', 'A doctor gives you 3 pills and tells you to take one every half hour. How long will the pills last?', '["1.5 hours", "1 hour", "2 hours", "30 minutes"]', 1, 50);
