-- ==========================================================
-- TREASURE HUNT COMPLETE DATABASE SETUP & SEED SCRIPT
-- Run this entire script in Supabase Dashboard -> SQL Editor
-- ==========================================================

-- 1. Enable pgcrypto extension for password hashing
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Drop existing tables if re-initializing
DROP TABLE IF EXISTS participants CASCADE;
DROP TABLE IF EXISTS hints CASCADE;
DROP TABLE IF EXISTS qr_codes CASCADE;
DROP TABLE IF EXISTS questions CASCADE;
DROP TABLE IF EXISTS game_state CASCADE;
DROP TABLE IF EXISTS game_config CASCADE;

-- 3. Create Tables
CREATE TABLE game_config (
    id INT PRIMARY KEY DEFAULT 1,
    entry_password_hash TEXT NOT NULL,
    admin_password_hash TEXT NOT NULL
);

CREATE TABLE game_state (
    id INT PRIMARY KEY DEFAULT 1,
    is_paused BOOLEAN DEFAULT false,
    broadcast_message TEXT
);

CREATE TABLE questions (
    id SERIAL PRIMARY KEY,
    round INT NOT NULL,
    pool_name TEXT NOT NULL,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_index INT NOT NULL,
    points INT NOT NULL,
    image TEXT
);

CREATE TABLE qr_codes (
    round INT PRIMARY KEY,
    code_hash TEXT NOT NULL
);

CREATE TABLE hints (
    round INT PRIMARY KEY,
    hint_text TEXT NOT NULL
);

CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    score INTEGER DEFAULT 0,
    completed BOOLEAN DEFAULT false,
    completion_time INTEGER,
    session_token UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    lives INTEGER DEFAULT 4,
    current_round INTEGER DEFAULT 1,
    stage TEXT DEFAULT 'login',
    q_index INTEGER DEFAULT 0,
    question_served_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ DEFAULT now(),
    processed_keys JSONB DEFAULT '[]'::jsonb
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE game_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE hints ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

-- Allow anonymous read on game_state for pause/broadcast polling
DROP POLICY IF EXISTS "Allow anon select on game_state" ON game_state;
CREATE POLICY "Allow anon select on game_state" ON game_state FOR SELECT TO anon, authenticated USING (true);

-- Enable Realtime for game_state
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'game_state'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE game_state;
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- ==========================================================
-- 5. RPC Functions
-- ==========================================================

-- Auth RPCs
CREATE OR REPLACE FUNCTION register_participant(p_username TEXT, p_entry_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config game_config%ROWTYPE;
    v_participant participants%ROWTYPE;
    v_clean_username TEXT;
BEGIN
    SELECT * INTO v_config FROM game_config WHERE id = 1;
    IF v_config.entry_password_hash != crypt(p_entry_password, v_config.entry_password_hash) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid game password');
    END IF;

    v_clean_username := btrim(p_username);
    IF v_clean_username = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Username cannot be empty');
    END IF;

    IF EXISTS (SELECT 1 FROM participants WHERE lower(username) = lower(v_clean_username)) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Username already taken');
    END IF;

    INSERT INTO participants (username, stage)
    VALUES (v_clean_username, 'qr-scan')
    RETURNING * INTO v_participant;

    RETURN jsonb_build_object(
        'success', true,
        'session_token', v_participant.session_token,
        'state', jsonb_build_object(
            'username', v_participant.username,
            'stage', v_participant.stage
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION get_state(p_session UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_part participants%ROWTYPE;
    v_hint hints%ROWTYPE;
    v_elapsed INT;
    v_rem_time INT;
    v_q_limit INT;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;

    IF v_part.stage = 'round' THEN
        IF v_part.current_round = 1 THEN v_q_limit := 120;
        ELSIF v_part.current_round = 2 THEN v_q_limit := 150;
        ELSIF v_part.current_round = 3 THEN v_q_limit := 45;
        ELSIF v_part.current_round = 4 THEN v_q_limit := 180;
        END IF;

        IF v_part.question_served_at IS NOT NULL THEN
            v_elapsed := EXTRACT(EPOCH FROM (now() - v_part.question_served_at))::INT;
            v_rem_time := GREATEST(v_q_limit - v_elapsed, 0);
        ELSE
            v_rem_time := v_q_limit;
        END IF;
    END IF;

    IF v_part.stage = 'hint' THEN
        SELECT * INTO v_hint FROM hints WHERE round = v_part.current_round - 1;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'participant', jsonb_build_object(
            'username', v_part.username,
            'current_round', v_part.current_round,
            'lifelines', v_part.lives,
            'gameState', v_part.stage,
            'score', v_part.score,
            'q_index', v_part.q_index,
            'completion_time', v_part.completion_time
        ),
        'remaining_time', v_rem_time,
        'hint', v_hint.hint_text
    );
END;
$$;

-- Game RPCs
CREATE OR REPLACE FUNCTION verify_qr(p_session UUID, p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_part participants%ROWTYPE;
    v_qr qr_codes%ROWTYPE;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;

    IF v_part.stage != 'qr-scan' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not expecting a QR code now');
    END IF;

    SELECT * INTO v_qr FROM qr_codes WHERE round = v_part.current_round;
    IF v_qr.code_hash = crypt(p_code, v_qr.code_hash) THEN
        UPDATE participants SET stage = 'round', q_index = 0 WHERE id = v_part.id;
        RETURN jsonb_build_object('success', true);
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid QR code');
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION get_question(p_session UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_part participants%ROWTYPE;
    v_question RECORD;
    v_pool_name TEXT;
    v_q_limit INT;
    v_seed_val BIGINT;
    v_pool_count INT;
    v_picked_offset INT;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;
    IF v_part.stage != 'round' THEN RETURN jsonb_build_object('success', false, 'error', 'Not in round stage'); END IF;

    IF v_part.current_round = 1 THEN v_q_limit := 120;
    ELSIF v_part.current_round = 2 THEN v_q_limit := 150;
    ELSIF v_part.current_round = 3 THEN v_q_limit := 45;
    ELSIF v_part.current_round = 4 THEN v_q_limit := 180;
    END IF;

    IF v_part.current_round = 1 THEN
        IF v_part.q_index = 0 THEN v_pool_name := 'logical';
        ELSIF v_part.q_index = 1 THEN v_pool_name := 'verbal';
        ELSIF v_part.q_index = 2 THEN v_pool_name := 'aptitude';
        END IF;
    ELSIF v_part.current_round = 2 THEN
        v_pool_name := 'tech' || (v_part.q_index + 1)::TEXT;
    ELSIF v_part.current_round = 3 THEN
        IF v_part.q_index = 0 THEN v_pool_name := 'fill';
        ELSIF v_part.q_index = 1 THEN v_pool_name := 'match';
        ELSIF v_part.q_index = 2 THEN v_pool_name := 'keyword';
        ELSIF v_part.q_index = 3 THEN v_pool_name := 'tf';
        ELSIF v_part.q_index = 4 THEN v_pool_name := 'output';
        END IF;
    ELSIF v_part.current_round = 4 THEN
        v_pool_name := 'dsa' || (v_part.q_index + 1)::TEXT;
    END IF;

    DECLARE
        v_real_pool TEXT;
    BEGIN
        v_real_pool := CASE 
            WHEN v_pool_name LIKE 'tech%' THEN 'tech'
            WHEN v_pool_name LIKE 'dsa%' THEN 'dsa'
            ELSE v_pool_name
        END;
        
        SELECT count(*) INTO v_pool_count FROM questions WHERE round = v_part.current_round AND pool_name = v_real_pool;
        IF v_pool_count = 0 THEN
            RETURN jsonb_build_object('success', false, 'error', 'No questions available for this round');
        END IF;

        v_seed_val := ('x' || substr(replace(v_part.id::text, '-', ''), 1, 14))::bit(56)::bigint;
        v_picked_offset := (v_seed_val + v_part.q_index) % v_pool_count;
        
        SELECT id, question_text, options, points, image INTO v_question 
        FROM questions 
        WHERE round = v_part.current_round AND pool_name = v_real_pool
        ORDER BY id 
        OFFSET v_picked_offset LIMIT 1;
    END;

    IF v_part.question_served_at IS NULL THEN
        UPDATE participants SET question_served_at = now() WHERE id = v_part.id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'question', jsonb_build_object(
            'id', v_question.id,
            'question', v_question.question_text,
            'options', v_question.options,
            'points', v_question.points,
            'image', v_question.image
        ),
        'time_limit', v_q_limit
    );
END;
$$;

-- Scoring RPCs
CREATE OR REPLACE FUNCTION submit_answer(p_session UUID, p_selected_index INT, p_idempotency_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_part participants%ROWTYPE;
    v_question questions%ROWTYPE;
    v_q_limit INT;
    v_elapsed INT;
    v_is_correct BOOLEAN;
    v_pts INT;
    v_new_stage TEXT;
    v_new_q_index INT;
    v_round_complete BOOLEAN := false;
    v_finished BOOLEAN := false;
    v_max_q INT;
    v_penalty INT;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;
    IF v_part.stage != 'round' THEN RETURN jsonb_build_object('success', false, 'error', 'Not in round stage'); END IF;

    IF v_part.processed_keys @> to_jsonb(p_idempotency_key) THEN
        RETURN jsonb_build_object('success', true, 'duplicate', true);
    END IF;

    IF v_part.current_round = 1 THEN v_q_limit := 120; v_max_q := 3;
    ELSIF v_part.current_round = 2 THEN v_q_limit := 150; v_max_q := 3;
    ELSIF v_part.current_round = 3 THEN v_q_limit := 45; v_max_q := 5;
    ELSIF v_part.current_round = 4 THEN v_q_limit := 180; v_max_q := 2;
    END IF;

    DECLARE
        v_pool_name TEXT;
        v_real_pool TEXT;
        v_pool_count INT;
        v_seed_val BIGINT;
        v_picked_offset INT;
    BEGIN
        IF v_part.current_round = 1 THEN
            IF v_part.q_index = 0 THEN v_pool_name := 'logical';
            ELSIF v_part.q_index = 1 THEN v_pool_name := 'verbal';
            ELSIF v_part.q_index = 2 THEN v_pool_name := 'aptitude';
            END IF;
        ELSIF v_part.current_round = 2 THEN
            v_pool_name := 'tech' || (v_part.q_index + 1)::TEXT;
        ELSIF v_part.current_round = 3 THEN
            IF v_part.q_index = 0 THEN v_pool_name := 'fill';
            ELSIF v_part.q_index = 1 THEN v_pool_name := 'match';
            ELSIF v_part.q_index = 2 THEN v_pool_name := 'keyword';
            ELSIF v_part.q_index = 3 THEN v_pool_name := 'tf';
            ELSIF v_part.q_index = 4 THEN v_pool_name := 'output';
            END IF;
        ELSIF v_part.current_round = 4 THEN
            v_pool_name := 'dsa' || (v_part.q_index + 1)::TEXT;
        END IF;

        v_real_pool := CASE 
            WHEN v_pool_name LIKE 'tech%' THEN 'tech'
            WHEN v_pool_name LIKE 'dsa%' THEN 'dsa'
            ELSE v_pool_name
        END;

        SELECT count(*) INTO v_pool_count FROM questions WHERE round = v_part.current_round AND pool_name = v_real_pool;
        v_seed_val := ('x' || substr(replace(v_part.id::text, '-', ''), 1, 14))::bit(56)::bigint;
        v_picked_offset := (v_seed_val + v_part.q_index) % v_pool_count;

        SELECT * INTO v_question 
        FROM questions 
        WHERE round = v_part.current_round AND pool_name = v_real_pool
        ORDER BY id 
        OFFSET v_picked_offset LIMIT 1;
    END;

    v_elapsed := EXTRACT(EPOCH FROM (now() - v_part.question_served_at))::INT;
    IF v_elapsed > (v_q_limit + 10) THEN
        v_is_correct := false;
        v_pts := 0;
    ELSE
        v_is_correct := (p_selected_index = v_question.correct_index);
        v_pts := v_question.points;
    END IF;

    v_new_stage := v_part.stage;
    v_new_q_index := v_part.q_index;
    
    IF v_is_correct THEN
        v_part.score := v_part.score + v_pts;
        v_new_q_index := v_part.q_index + 1;
    ELSE
        v_penalty := v_pts / 2;
        v_part.score := v_part.score - v_penalty;
        v_part.lives := v_part.lives - 1;
        IF v_part.lives <= 0 THEN
            v_new_stage := 'eliminated';
        ELSE
            v_new_q_index := v_part.q_index + 1;
        END IF;
    END IF;

    IF v_new_stage != 'eliminated' AND v_new_q_index >= v_max_q THEN
        v_round_complete := true;
        v_part.score := v_part.score + 10;
        IF v_part.current_round >= 4 THEN
            v_finished := true;
            v_new_stage := 'winner';
            v_part.completed := true;
            v_part.completion_time := EXTRACT(EPOCH FROM (now() - v_part.started_at))::INT;
            v_part.score := v_part.score + (v_part.lives * 5);
        ELSE
            v_new_stage := 'hint';
        END IF;
    END IF;

    UPDATE participants 
    SET score = v_part.score,
        lives = v_part.lives,
        stage = v_new_stage,
        q_index = v_new_q_index,
        question_served_at = NULL,
        completed = v_part.completed,
        completion_time = v_part.completion_time,
        processed_keys = processed_keys || to_jsonb(p_idempotency_key)
    WHERE id = v_part.id;

    RETURN jsonb_build_object(
        'success', true,
        'correct', v_is_correct,
        'score', v_part.score,
        'lifelines', v_part.lives,
        'round_complete', v_round_complete,
        'finished', v_finished,
        'stage', v_new_stage
    );
END;
$$;

-- Penalties and Utilities
CREATE OR REPLACE FUNCTION report_timeout(p_session UUID, p_idempotency_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN submit_answer(p_session, -1, p_idempotency_key);
END;
$$;

CREATE OR REPLACE FUNCTION lose_lifeline(p_session UUID, p_reason TEXT, p_idempotency_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_part participants%ROWTYPE;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;

    IF v_part.processed_keys @> to_jsonb(p_idempotency_key) THEN
        RETURN jsonb_build_object('success', true, 'duplicate', true);
    END IF;

    v_part.lives := v_part.lives - 1;
    IF v_part.lives <= 0 THEN
        v_part.stage := 'eliminated';
    END IF;

    UPDATE participants 
    SET lives = v_part.lives,
        stage = v_part.stage,
        processed_keys = processed_keys || to_jsonb(p_idempotency_key)
    WHERE id = v_part.id;

    RETURN jsonb_build_object(
        'success', true,
        'lifelines', v_part.lives,
        'stage', v_part.stage
    );
END;
$$;

CREATE OR REPLACE FUNCTION next_round(p_session UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_part participants%ROWTYPE;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;

    IF v_part.stage != 'hint' THEN RETURN jsonb_build_object('success', false, 'error', 'Not in hint stage'); END IF;

    UPDATE participants 
    SET current_round = current_round + 1,
        q_index = 0,
        stage = 'qr-scan'
    WHERE id = v_part.id;

    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION get_leaderboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_leaderboard JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'username', username,
            'score', score,
            'completion_time', completion_time
        ) ORDER BY score DESC, completion_time ASC
    ), '[]'::jsonb)
    INTO v_leaderboard
    FROM participants
    WHERE completed = true;

    RETURN jsonb_build_object('success', true, 'leaderboard', v_leaderboard);
END;
$$;

-- Admin RPCs
CREATE OR REPLACE FUNCTION admin_login(p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config game_config%ROWTYPE;
BEGIN
    SELECT * INTO v_config FROM game_config WHERE id = 1;
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION admin_list_participants(p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config game_config%ROWTYPE;
    v_participants JSONB;
BEGIN
    SELECT * INTO v_config FROM game_config WHERE id = 1;
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'username', username,
            'score', score,
            'completed', completed,
            'completion_time', completion_time
        ) ORDER BY score DESC
    ), '[]'::jsonb)
    INTO v_participants
    FROM participants;

    RETURN jsonb_build_object('success', true, 'participants', v_participants);
END;
$$;

CREATE OR REPLACE FUNCTION admin_adjust_score(p_password TEXT, p_user_id UUID, p_amount INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config game_config%ROWTYPE;
BEGIN
    SELECT * INTO v_config FROM game_config WHERE id = 1;
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    UPDATE participants SET score = score + p_amount WHERE id = p_user_id;
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION admin_reset_game(p_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config game_config%ROWTYPE;
BEGIN
    SELECT * INTO v_config FROM game_config WHERE id = 1;
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    -- Reset game state (unpause, clear broadcast)
    UPDATE game_state SET is_paused = false, broadcast_message = NULL WHERE id = 1;

    -- Delete all participants with explicit WHERE clause to satisfy safe-update mode
    DELETE FROM participants WHERE id IS NOT NULL;
        
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION admin_pause_game(p_password TEXT, p_paused BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config game_config%ROWTYPE;
BEGIN
    SELECT * INTO v_config FROM game_config WHERE id = 1;
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    UPDATE game_state SET is_paused = p_paused WHERE id = 1;
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION admin_broadcast(p_password TEXT, p_message TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config game_config%ROWTYPE;
BEGIN
    SELECT * INTO v_config FROM game_config WHERE id = 1;
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    UPDATE game_state SET broadcast_message = p_message WHERE id = 1;
    RETURN jsonb_build_object('success', true);
END;
$$;

-- ==========================================================
-- 6. Seed Data
-- ==========================================================

-- 1. Game Config (Passwords: 'player' and 'admin')
INSERT INTO game_config (id, entry_password_hash, admin_password_hash)
VALUES (
    1, 
    crypt('player', gen_salt('bf')), 
    crypt('admin', gen_salt('bf'))
)
ON CONFLICT (id) DO UPDATE 
SET entry_password_hash = crypt('player', gen_salt('bf')),
    admin_password_hash = crypt('admin', gen_salt('bf'));

-- 2. Game State
INSERT INTO game_state (id, is_paused, broadcast_message)
VALUES (1, false, NULL)
ON CONFLICT (id) DO UPDATE 
SET is_paused = false, broadcast_message = NULL;

-- 3. Hints
INSERT INTO hints (round, hint_text) VALUES
(1, 'Hint for Round 2: Search near the big oak tree.'),
(2, 'Hint for Round 3: Check the library entrance.'),
(3, 'Hint for Round 4: Find the computer lab.'),
(4, 'Final Hint: The treasure is in the cafeteria.')
ON CONFLICT (round) DO UPDATE SET hint_text = EXCLUDED.hint_text;

-- 4. QR Codes (Default keys: 'r1', 'r2', 'r3', 'r4')
INSERT INTO qr_codes (round, code_hash) VALUES
(1, crypt('r1', gen_salt('bf'))),
(2, crypt('r2', gen_salt('bf'))),
(3, crypt('r3', gen_salt('bf'))),
(4, crypt('r4', gen_salt('bf')))
ON CONFLICT (round) DO UPDATE SET code_hash = EXCLUDED.code_hash;

-- 5. Questions
TRUNCATE TABLE questions RESTART IDENTITY CASCADE;

INSERT INTO questions (round, pool_name, question_text, options, correct_index, points) VALUES
-- Round 1 (Logic, Verbal, Aptitude)
(1, 'logical', 'Number Series: 2, 4, 8, 16, ___', '["24", "30", "32", "64"]', 2, 10),
(1, 'verbal', 'Antonym of "Fast"', '["Quick", "Slow", "Rapid", "Speedy"]', 1, 10),
(1, 'aptitude', '10 + 10 * 0 = ?', '["0", "10", "20", "100"]', 1, 10),

-- Round 2 (Tech Riddles)
(2, 'tech', 'I have keys but no locks. What am I?', '["Keyboard", "Map", "Piano", "Door"]', 0, 15),
(2, 'tech', 'I am the brain of the computer.', '["RAM", "CPU", "Monitor", "Mouse"]', 1, 15),
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
