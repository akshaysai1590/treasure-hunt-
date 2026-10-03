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

    -- Check idempotency
    IF v_part.processed_keys @> to_jsonb(p_idempotency_key) THEN
        RETURN jsonb_build_object('success', true, 'duplicate', true);
    END IF;

    -- Time limits
    IF v_part.current_round = 1 THEN v_q_limit := 15; v_max_q := 5;
    ELSIF v_part.current_round = 2 THEN v_q_limit := 30; v_max_q := 5;
    ELSIF v_part.current_round = 3 THEN v_q_limit := 45; v_max_q := 5;
    ELSIF v_part.current_round = 4 THEN v_q_limit := 90; v_max_q := 5;
    END IF;

    -- Fetch the correct question by reversing the deterministic selection
    -- Wait, we can't easily reverse the selection in SQL without rewriting get_question. 
    -- Better: submit_answer receives the question ID! But the prompt says submit_answer(p_session UUID, p_selected_index INT, p_idempotency_key TEXT).
    -- So we just recreate the deterministic selection here exactly as in get_question.
    
    DECLARE
        v_round_count INT;
        v_seed_val BIGINT;
        v_picked_offset INT;
    BEGIN
        SELECT count(*) INTO v_round_count FROM questions WHERE round = v_part.current_round;
        v_seed_val := ('x' || substr(replace(v_part.id::text, '-', ''), 1, 14))::bit(56)::bigint;
        v_picked_offset := (v_seed_val + v_part.q_index * 7) % v_round_count;

        SELECT * INTO v_question
        FROM questions
        WHERE round = v_part.current_round
        ORDER BY id
        OFFSET v_picked_offset LIMIT 1;
    END;

    -- Time validation (10s grace)
    v_elapsed := EXTRACT(EPOCH FROM (now() - v_part.question_served_at))::INT;
    IF v_elapsed > (v_q_limit + 10) THEN
        v_is_correct := false;
        v_pts := 0;
    ELSE
        v_is_correct := (p_selected_index = v_question.correct_index);
        v_pts := v_question.points;
    END IF;

    -- Scoring
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

    -- Check round progression
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

    -- Update DB
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
