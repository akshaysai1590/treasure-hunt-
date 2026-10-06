-- ==========================================================
-- TREASURE HUNT: CONTESTANT CREDENTIALS SEEDING
-- Run this in Supabase Dashboard -> SQL Editor
-- ==========================================================

-- 1. Ensure columns exist on participants table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'participants' AND column_name = 'roll_number') THEN
        ALTER TABLE participants ADD COLUMN roll_number TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'participants' AND column_name = 'team_code') THEN
        ALTER TABLE participants ADD COLUMN team_code TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'participants' AND column_name = 'password_hash') THEN
        ALTER TABLE participants ADD COLUMN password_hash TEXT;
    END IF;
END $$;

-- 2. Clear previous participant data
TRUNCATE TABLE participants RESTART IDENTITY CASCADE;

-- 3. Pre-seed all 64 Registered Teams
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

-- 4. Update register_participant to authenticate registered contestants
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
