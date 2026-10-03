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
