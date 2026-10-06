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

    -- Check if username exists (case insensitive)
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
    v_question questions%ROWTYPE;
    v_hint hints%ROWTYPE;
    v_elapsed INT;
    v_rem_time INT;
    v_q_limit INT;
    v_q_count INT;
    v_total_points INT;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;

    -- Fetch current question if in round
    IF v_part.stage = 'round' THEN
        -- Deterministic question selection logic based on participant ID and q_index
        -- Simplified for this context: we'll use a hashing technique on ID to pick the question from the pool
        -- But wait, get_question will be responsible for fetching the question. We just rehydrate it here.
        
        -- time limit based on round
        IF v_part.current_round = 1 THEN v_q_limit := 45;
        ELSIF v_part.current_round = 2 THEN v_q_limit := 90;
        ELSIF v_part.current_round = 3 THEN v_q_limit := 30;
        ELSIF v_part.current_round = 4 THEN v_q_limit := 120;
        END IF;

        IF v_part.question_served_at IS NOT NULL THEN
            v_elapsed := EXTRACT(EPOCH FROM (now() - v_part.question_served_at))::INT;
            v_rem_time := GREATEST(v_q_limit - v_elapsed, 0);
        ELSE
            v_rem_time := v_q_limit;
        END IF;
    END IF;

    -- Fetch hint if in hint stage
    IF v_part.stage = 'hint' THEN
        SELECT * INTO v_hint FROM hints WHERE round = v_part.current_round;
    END IF;
    
    -- We'll recalculate the score if needed, but the score in table is the source of truth.

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
