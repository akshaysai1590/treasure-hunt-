-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Table: game_config
CREATE TABLE game_config (
    id INT PRIMARY KEY DEFAULT 1,
    entry_password_hash TEXT NOT NULL,
    admin_password_hash TEXT NOT NULL
);

-- Table: game_state
CREATE TABLE game_state (
    id INT PRIMARY KEY DEFAULT 1,
    is_paused BOOLEAN DEFAULT false,
    broadcast_message TEXT
);

-- Enable realtime for game_state
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime;
  ALTER PUBLICATION supabase_realtime ADD TABLE game_state;
COMMIT;

-- Table: questions
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

-- Table: qr_codes
CREATE TABLE qr_codes (
    round INT PRIMARY KEY,
    code_hash TEXT NOT NULL
);

-- Table: hints
CREATE TABLE hints (
    round INT PRIMARY KEY,
    hint_text TEXT NOT NULL
);

-- Table: participants
CREATE TABLE participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    score INTEGER DEFAULT 0,
    completed BOOLEAN DEFAULT false,
    completion_time INTEGER,
    session_token UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    lives INTEGER DEFAULT 4,
    current_round INTEGER DEFAULT 1,
    stage TEXT DEFAULT 'login', -- login, qr-scan, round, hint, winner, eliminated
    q_index INTEGER DEFAULT 0,
    question_served_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ DEFAULT now(),
    processed_keys JSONB DEFAULT '[]'::jsonb
);

-- RLS Policies
ALTER TABLE game_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE hints ENABLE ROW LEVEL SECURITY;
ALTER TABLE participants ENABLE ROW LEVEL SECURITY;

-- Only anon SELECT on game_state
CREATE POLICY "Allow anon select on game_state" ON game_state FOR SELECT TO anon, authenticated USING (true);
