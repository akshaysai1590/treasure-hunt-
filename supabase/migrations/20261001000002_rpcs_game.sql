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

    -- Time limits
    IF v_part.current_round = 1 THEN v_q_limit := 120;
    ELSIF v_part.current_round = 2 THEN v_q_limit := 150;
    ELSIF v_part.current_round = 3 THEN v_q_limit := 45;
    ELSIF v_part.current_round = 4 THEN v_q_limit := 180;
    END IF;

    -- Determine pool name based on round and q_index
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

    -- Map pool_name back to the generic pool in DB (since some are shared pools)
    DECLARE
        v_real_pool TEXT;
    BEGIN
        v_real_pool := CASE 
            WHEN v_pool_name LIKE 'tech%' THEN 'tech'
            WHEN v_pool_name LIKE 'dsa%' THEN 'dsa'
            ELSE v_pool_name
        END;
        
        SELECT count(*) INTO v_pool_count FROM questions WHERE round = v_part.current_round AND pool_name = v_real_pool;
        
        -- Pseudorandom deterministic selection based on UUID and pool name
        -- UUID is hex, we take a substring and convert to bigint
        v_seed_val := ('x' || substr(replace(v_part.id::text, '-', ''), 1, 14))::bit(56)::bigint;
        
        -- Add index to avoid picking the same question twice from the same pool if possible
        v_picked_offset := (v_seed_val + v_part.q_index) % v_pool_count;
        
        SELECT id, question_text, options, points INTO v_question 
        FROM questions 
        WHERE round = v_part.current_round AND pool_name = v_real_pool
        ORDER BY id 
        OFFSET v_picked_offset LIMIT 1;
    END;

    -- Update served_at if null
    IF v_part.question_served_at IS NULL THEN
        UPDATE participants SET question_served_at = now() WHERE id = v_part.id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'question', jsonb_build_object(
            'id', v_question.id,
            'question', v_question.question_text,
            'options', v_question.options,
            'points', v_question.points
        ),
        'time_limit', v_q_limit
    );
END;
$$;
