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
    roll_number TEXT,
    team_code TEXT,
    password_hash TEXT,
    score INTEGER DEFAULT 0,
    completed BOOLEAN DEFAULT false,
    completion_time INTEGER,
    session_token UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    lives INTEGER DEFAULT 4,
    current_round INTEGER DEFAULT 1,
    stage TEXT DEFAULT 'qr-scan',
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
    v_participant participants%ROWTYPE;
    v_clean_username TEXT;
    v_clean_pass TEXT;
BEGIN
    v_clean_username := btrim(p_username);
    v_clean_pass := btrim(p_entry_password);

    IF v_clean_username = '' OR v_clean_pass = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Please enter ID and Password');
    END IF;

    -- Match by roll_number OR team_code OR username (case-insensitive)
    SELECT * INTO v_participant FROM participants 
    WHERE lower(roll_number) = lower(v_clean_username)
       OR lower(team_code) = lower(v_clean_username)
       OR lower(username) = lower(v_clean_username);

    IF NOT FOUND THEN
        -- Fallback: check if legacy game password matches for ad-hoc users
        DECLARE
            v_config game_config%ROWTYPE;
        BEGIN
            SELECT * INTO v_config FROM game_config WHERE id = 1;
            IF v_config.entry_password_hash = crypt(v_clean_pass, v_config.entry_password_hash) THEN
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
            END IF;
        END;

        RETURN jsonb_build_object('success', false, 'error', 'Invalid ID. Enter your Roll No or Team ID (e.g. T01)');
    END IF;

    -- Validate Password PIN
    IF v_participant.password_hash IS NOT NULL THEN
        IF v_participant.password_hash != crypt(v_clean_pass, v_participant.password_hash) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Incorrect Password / PIN');
        END IF;
    END IF;

    -- Update started_at on first login
    IF v_participant.started_at IS NULL THEN
        UPDATE participants SET started_at = now() WHERE id = v_participant.id;
    END IF;

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
        IF v_part.current_round = 1 THEN v_q_limit := 45;
        ELSIF v_part.current_round = 2 THEN v_q_limit := 90;
        ELSIF v_part.current_round = 3 THEN v_q_limit := 30;
        ELSIF v_part.current_round = 4 THEN v_q_limit := 120;
        ELSE v_q_limit := 60;
        END IF;

        IF v_part.question_served_at IS NOT NULL THEN
            v_elapsed := EXTRACT(EPOCH FROM (now() - v_part.question_served_at))::INT;
            v_rem_time := GREATEST(v_q_limit - v_elapsed, 0);
        ELSE
            v_rem_time := v_q_limit;
        END IF;
    END IF;

    IF v_part.stage = 'hint' THEN
        SELECT * INTO v_hint FROM hints WHERE round = v_part.current_round;
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
        UPDATE participants SET stage = 'round', q_index = 0, question_served_at = NULL WHERE id = v_part.id;
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
    v_q_limit INT;
    v_round_count INT;
    v_picked_offset INT;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;
    IF v_part.stage != 'round' THEN RETURN jsonb_build_object('success', false, 'error', 'Not in round stage'); END IF;

    -- Time limits: R1=45s, R2=90s, R3=30s, R4=120s
    IF v_part.current_round = 1 THEN v_q_limit := 45;
    ELSIF v_part.current_round = 2 THEN v_q_limit := 90;
    ELSIF v_part.current_round = 3 THEN v_q_limit := 30;
    ELSIF v_part.current_round = 4 THEN v_q_limit := 120;
    ELSE v_q_limit := 60;
    END IF;

    -- Count questions in current round
    SELECT count(*) INTO v_round_count FROM questions WHERE round = v_part.current_round;
    IF v_round_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No questions available for round ' || v_part.current_round);
    END IF;

    -- Serve questions in order of index for this round
    v_picked_offset := (v_part.q_index % v_round_count);

    SELECT id, question_text, options, points, image INTO v_question
    FROM questions
    WHERE round = v_part.current_round
    ORDER BY id
    OFFSET v_picked_offset LIMIT 1;

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
    v_round_count INT;
    v_picked_offset INT;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;
    IF v_part.stage != 'round' THEN RETURN jsonb_build_object('success', false, 'error', 'Not in round stage'); END IF;

    IF v_part.processed_keys @> to_jsonb(p_idempotency_key) THEN
        RETURN jsonb_build_object('success', true, 'duplicate', true);
    END IF;

    -- Per-round question counts & time limits:
    -- Round 1: 3 questions, 45s each
    -- Round 2: 3 questions, 90s each
    -- Round 3: 5 questions, 30s each
    -- Round 4: 2 questions, 120s each
    IF v_part.current_round = 1 THEN v_q_limit := 45; v_max_q := 3;
    ELSIF v_part.current_round = 2 THEN v_q_limit := 90; v_max_q := 3;
    ELSIF v_part.current_round = 3 THEN v_q_limit := 30; v_max_q := 5;
    ELSIF v_part.current_round = 4 THEN v_q_limit := 120; v_max_q := 2;
    ELSE v_q_limit := 60; v_max_q := 3;
    END IF;

    SELECT count(*) INTO v_round_count FROM questions WHERE round = v_part.current_round;
    IF v_round_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No questions available for round ' || v_part.current_round);
    END IF;

    -- Fetch current question matching q_index
    v_picked_offset := (v_part.q_index % v_round_count);

    SELECT * INTO v_question
    FROM questions
    WHERE round = v_part.current_round
    ORDER BY id
    OFFSET v_picked_offset LIMIT 1;

    -- Time validation (10s network grace)
    IF v_part.question_served_at IS NOT NULL THEN
        v_elapsed := EXTRACT(EPOCH FROM (now() - v_part.question_served_at))::INT;
    ELSE
        v_elapsed := 0;
    END IF;

    IF v_elapsed > (v_q_limit + 10) OR p_selected_index = -1 THEN
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

    -- Check round completion
    IF v_new_stage != 'eliminated' AND v_new_q_index >= v_max_q THEN
        v_round_complete := true;
        v_part.score := v_part.score + 10; -- Round completion bonus
        IF v_part.current_round >= 4 THEN
            v_finished := true;
            v_new_stage := 'winner';
            v_part.completed := true;
            v_part.completion_time := EXTRACT(EPOCH FROM (now() - v_part.started_at))::INT;
            v_part.score := v_part.score + (v_part.lives * 5); -- Lifeline bonus
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

    -- Return full set of both new and legacy field names for 100% frontend compatibility
    RETURN jsonb_build_object(
        'success', true,
        'correct', v_is_correct,
        'score', v_part.score,
        'lifelines', v_part.lives,
        'lives', v_part.lives,
        'round_complete', v_round_complete,
        'finished', v_finished,
        'winner', v_finished,
        'stage', v_new_stage,
        'next_stage', v_new_stage,
        'game_over', (v_new_stage = 'eliminated'),
        'points_awarded', CASE WHEN v_is_correct THEN v_pts ELSE -v_penalty END
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
        'lives', v_part.lives,
        'stage', v_part.stage,
        'next_stage', v_part.stage
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
        question_served_at = NULL,
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
        ) ORDER BY score DESC, completion_time ASC NULLS LAST
    ), '[]'::jsonb)
    INTO v_leaderboard
    FROM participants
    WHERE stage != 'eliminated';

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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) AND p_password != 'admin' AND p_password != 'z0EZ3WbUVkPunBxnffseakGZ' THEN
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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) AND p_password != 'admin' AND p_password != 'z0EZ3WbUVkPunBxnffseakGZ' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'username', username,
            'score', score,
            'completed', completed,
            'completion_time', completion_time
        ) ORDER BY score DESC, CASE WHEN completed THEN 0 ELSE 1 END, completion_time ASC NULLS LAST
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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) AND p_password != 'admin' AND p_password != 'z0EZ3WbUVkPunBxnffseakGZ' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    UPDATE participants SET score = score + p_amount WHERE id = p_user_id;
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION admin_toggle_pause(p_password TEXT, p_pause BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_config game_config%ROWTYPE;
BEGIN
    SELECT * INTO v_config FROM game_config WHERE id = 1;
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) AND p_password != 'admin' AND p_password != 'z0EZ3WbUVkPunBxnffseakGZ' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    UPDATE game_state SET is_paused = p_pause WHERE id = 1;
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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) AND p_password != 'admin' AND p_password != 'z0EZ3WbUVkPunBxnffseakGZ' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    UPDATE game_state SET broadcast_message = NULLIF(btrim(p_message), '') WHERE id = 1;
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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) AND p_password != 'admin' AND p_password != 'z0EZ3WbUVkPunBxnffseakGZ' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid admin password');
    END IF;

    -- Reset all participant states
    UPDATE participants 
    SET score = 0,
        completed = false,
        completion_time = NULL,
        lives = 4,
        current_round = 1,
        stage = 'qr-scan',
        q_index = 0,
        question_served_at = NULL,
        started_at = now(),
        processed_keys = '[]'::jsonb
    WHERE true;

    UPDATE game_state SET is_paused = false, broadcast_message = NULL WHERE id = 1;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ==========================================================
-- 6. Initial Seed Data
-- ==========================================================

-- 1. Game Config (Passwords: 'player' and 'admin'/'z0EZ3WbUVkPunBxnffseakGZ')
INSERT INTO game_config (id, entry_password_hash, admin_password_hash)
VALUES (
    1, 
    crypt('player', gen_salt('bf')), 
    crypt('z0EZ3WbUVkPunBxnffseakGZ', gen_salt('bf'))
)
ON CONFLICT (id) DO UPDATE 
SET entry_password_hash = EXCLUDED.entry_password_hash,
    admin_password_hash = EXCLUDED.admin_password_hash;

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
ON CONFLICT (round) DO UPDATE SET hint_text = EXCLUDED.hint_text;

-- 4. QR Codes (Passwords: 'r1', 'r2', 'r3', 'r4')
INSERT INTO qr_codes (round, code_hash) VALUES
(1, crypt('r1', gen_salt('bf'))),
(2, crypt('r2', gen_salt('bf'))),
(3, crypt('r3', gen_salt('bf'))),
(4, crypt('r4', gen_salt('bf')))
ON CONFLICT (round) DO UPDATE SET code_hash = EXCLUDED.code_hash;

-- 5. Seed Final 13 Contest Questions
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

-- 6. Pre-seed All 64 Registered Teams
TRUNCATE TABLE participants RESTART IDENTITY CASCADE;

INSERT INTO participants (username, roll_number, team_code, password_hash, lives, stage, current_round, score)
VALUES
('P Sowmya sri (25EU05R0077)', '25EU05R0077', 'T01', crypt('1001', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Kolloju Samala (25EU05R0044)', '25EU05R0044', 'T02', crypt('1002', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('G.Harika (25EU05R0030)', '25EU05R0030', 'T03', crypt('1003', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('GONGURA SAI BHARGAV (25EU05R0031)', '25EU05R0031', 'T04', crypt('1004', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Mekala Akshitha (25EU05R0141)', '25EU05R0141', 'T05', crypt('1005', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('M Deepika (25EU05R0146)', '25EU05R0146', 'T06', crypt('1006', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('A Reethu (25EU05R0093)', '25EU05R0093', 'T07', crypt('1007', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('B Ankitha (25EU05R0101)', '25EU05R0101', 'T08', crypt('1008', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Bhashwini (25EU05R0158)', '25EU05R0158', 'T09', crypt('1009', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Preksha Ghanathe (25EU05R0117)', '25EU05R0117', 'T10', crypt('1010', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Modem Jaswitha (25EU05R0142)', '25EU05R0142', 'T11', crypt('1011', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Saichandra Donthula (25EU05R0111)', '25EU05R0111', 'T12', crypt('1012', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('M.HASHWANTH (25EU05R0144)', '25EU05R0144', 'T13', crypt('1013', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Vedant Malwar (25EU05R0179)', '25EU05R0179', 'T14', crypt('1014', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Joanna Frankincense (25EU05R0123)', '25EU05R0123', 'T15', crypt('1015', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('S. Rohit Venkata Krishna Reddy (25EU05R0170)', '25EU05R0170', 'T16', crypt('1016', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Mamidi shiva sai (25EU05R0136)', '25EU05R0136', 'T17', crypt('1017', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Ruchitha (25EU05R0258)', '25EU05R0258', 'T18', crypt('1018', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('P.vasantha (25EU05R0247)', '25EU05R0247', 'T19', crypt('1019', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Pujari Akshitha (25EU05R0251)', '25EU05R0251', 'T20', crypt('1020', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('KOLLI MEGHANA (25EU05R0230)', '25EU05R0230', 'T21', crypt('1021', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Medidha sahithi (25EU05R0240)', '25EU05R0240', 'T22', crypt('1022', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Chinthala Neha (25EU05R0201)', '25EU05R0201', 'T23', crypt('1023', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Priyavarshini (25EU05R0184)', '25EU05R0184', 'T24', crypt('1024', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('G.Lokesh Reddy (25EU05R0213)', '25EU05R0213', 'T25', crypt('1025', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Jangala Tejasri (25EU05R0221)', '25EU05R0221', 'T26', crypt('1026', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('M Prasanth (25EU05R0238)', '25EU05R0238', 'T27', crypt('1027', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Bhanu prasad (25EU05R0190)', '25EU05R0190', 'T28', crypt('1028', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('G Sai Venkat Reddy (25EU05R0214)', '25EU05R0214', 'T29', crypt('1029', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Edukulla.Laasya Priya (25EU05T0001)', '25EU05T0001', 'T30', crypt('1030', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('V. Jahnavi Naga Priya (25EU05R0359)', '25EU05R0359', 'T31', crypt('1031', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Rasamadugu Sahasra (25EU05R0343)', '25EU05R0343', 'T32', crypt('1032', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Nimmala navadeep (25EU05R0334)', '25EU05R0334', 'T33', crypt('1033', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('M. Pranavi (25EU05R0320)', '25EU05R0320', 'T34', crypt('1034', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Naveen Mallikanti (25EU05R0325)', '25EU05R0325', 'T35', crypt('1035', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('K. Baby Sri (25EU05R0314)', '25EU05R0314', 'T36', crypt('1036', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('G. Vignesh (25EU05R0299)', '25EU05R0299', 'T37', crypt('1037', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Sunkireddy vijayreddy (25EU05R0356)', '25EU05R0356', 'T38', crypt('1038', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Mandava pooja (25EU05R0326)', '25EU05R0326', 'T39', crypt('1039', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Karthik ram (25EU05R0316)', '25EU05R0316', 'T40', crypt('1040', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Mere Karthik (25EU05R0329)', '25EU05R0329', 'T41', crypt('1041', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('M.shivamanikanta (25EU05R0404)', '25EU05R0404', 'T42', crypt('1042', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('THALLA VARSHITH (25EU05R0440)', '25EU05R0440', 'T43', crypt('1043', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('P.Haritha (25EU05R0419)', '25EU05R0419', 'T44', crypt('1044', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Risheel Rufus Reddimasi (25EU05R0433)', '25EU05R0433', 'T45', crypt('1045', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('M BHARATH BHUSHAN (25EU05R0401)', '25EU05R0401', 'T46', crypt('1046', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('B.Hanshika (25EU05R0370)', '25EU05R0370', 'T47', crypt('1047', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Chittimalla vijay kumar (25EU05R0378)', '25EU05R0378', 'T48', crypt('1048', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('P. Dileep kumar (25EU05R0421)', '25EU05R0421', 'T49', crypt('1049', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('G Jasmitha (25EU05R0388)', '25EU05R0388', 'T50', crypt('1050', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Y. Bhanu Prakash (25EU05R0450)', '25EU05R0450', 'T51', crypt('1051', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Y.VISHAL VARDHAN (24J41A05FF)', '24J41A05FF', 'T52', crypt('1052', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Vallapu Dhoni (25EU05R0530)', '25EU05R0530', 'T53', crypt('1053', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('D N V S KRISHNA KOUSHIK (25EU05R0466)', '25EU05R0466', 'T54', crypt('1054', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Makke Prudhvi Nagh (25EU06R0501)', '25EU06R0501', 'T55', crypt('1055', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('D.risik (25EU05R0561)', '25EU05R0561', 'T56', crypt('1056', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('PALURU VAMSI KRISHNA SAI (25EU05R0606)', '25EU05R0606', 'T57', crypt('1057', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Harsha Vardhan (25EU05R0572)', '25EU05R0572', 'T58', crypt('1058', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Nagelli Yanish Raj (25EU05R0598)', '25EU05R0598', 'T59', crypt('1059', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Rithwek Reddy (25EU05R0549)', '25EU05R0549', 'T60', crypt('1060', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('SAI DIKSHITH (25EU05R0570)', '25EU05R0570', 'T61', crypt('1061', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('Prashant reddy (25EU05R0660)', '25EU05R0660', 'T62', crypt('1062', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('PANGA SAMUEL (24J41A05X2)', '24J41A05X2', 'T63', crypt('1063', gen_salt('bf')), 4, 'qr-scan', 1, 0),
('P.likhith sai (24J41A05EF)', '24J41A05EF', 'T64', crypt('1064', gen_salt('bf')), 4, 'qr-scan', 1, 0);
