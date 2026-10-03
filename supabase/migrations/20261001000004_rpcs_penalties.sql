CREATE OR REPLACE FUNCTION report_timeout(p_session UUID, p_idempotency_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_part participants%ROWTYPE;
BEGIN
    SELECT * INTO v_part FROM participants WHERE session_token = p_session FOR UPDATE;
    IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Invalid session'); END IF;

    IF v_part.stage != 'round' THEN RETURN jsonb_build_object('success', false, 'error', 'Not in round stage'); END IF;

    IF v_part.processed_keys @> to_jsonb(p_idempotency_key) THEN
        RETURN jsonb_build_object('success', true, 'duplicate', true);
    END IF;

    -- Treat as a submit_answer with an invalid index (-1)
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
