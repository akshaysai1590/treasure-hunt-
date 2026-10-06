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
    v_seed_val BIGINT;
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

    -- Select from ANY available question for this round!
    SELECT count(*) INTO v_round_count FROM questions WHERE round = v_part.current_round;
    IF v_round_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No questions available for round ' || v_part.current_round);
    END IF;

    -- Deterministic selection based on participant UUID and q_index
    v_seed_val := ('x' || substr(replace(v_part.id::text, '-', ''), 1, 14))::bit(56)::bigint;
    v_picked_offset := abs(v_seed_val + v_part.q_index * 7) % v_round_count;

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
    v_seed_val BIGINT;
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

    v_seed_val := ('x' || substr(replace(v_part.id::text, '-', ''), 1, 14))::bit(56)::bigint;
    v_picked_offset := abs(v_seed_val + v_part.q_index * 7) % v_round_count;

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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
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
    IF v_config.admin_password_hash != crypt(p_password, v_config.admin_password_hash) THEN
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

-- 1. Game Config (Passwords: 'player' and 'admin')
INSERT INTO game_config (id, entry_password_hash, admin_password_hash)
VALUES (
    1, 
    crypt('player', gen_salt('bf')), 
    crypt('admin', gen_salt('bf'))
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

-- 5. Seed 70 Questions
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
