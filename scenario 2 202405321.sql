-- ==========================================================
-- Scenario 2: Computer Laboratory Reservations
-- ==========================================================

-- STEP 1: Create tables with at least three lab sessions
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    lecturer_name VARCHAR(100) NOT NULL,
    session_id INT REFERENCES lab_sessions(session_id),
    number_of_workstations INT NOT NULL,
    status VARCHAR(20) DEFAULT 'RESERVED'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('Monday Lab - ICT101', 30),
('Tuesday Lab - ICT201', 5),
('Wednesday Lab - ICT301', 0);

SELECT * FROM lab_sessions;

-- STEP 2: IF ELSIF ELSE for FULL / NEARLY FULL / HAS ENOUGH
DO $$
DECLARE
    v_avail INT;
    v_name VARCHAR;
BEGIN
    SELECT available_workstations, session_name INTO v_avail, v_name FROM lab_sessions WHERE session_id = 2;
    IF v_avail = 0 THEN
        RAISE NOTICE 'Session "%" is FULL - no workstations', v_name;
    ELSIF v_avail <= 5 THEN
        RAISE NOTICE 'Session "%" is NEARLY FULL - only % left', v_name, v_avail;
    ELSE
        RAISE NOTICE 'Session "%" HAS ENOUGH workstations - % available', v_name, v_avail;
    END IF;
END $$;

-- STEP 3: WHILE for 3 reminders, FOR for 3 checks
DO $$
DECLARE
    c INT := 1;
BEGIN
    RAISE NOTICE '--- Session Preparation (WHILE) ---';
    WHILE c <= 3 LOOP
        RAISE NOTICE 'Session Preparation Reminder Day %', c;
        c := c + 1;
    END LOOP;
    RAISE NOTICE '--- Workstation Checks (FOR) ---';
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Workstation Check Number: %', i;
    END LOOP;
END $$;

-- STEP 4: reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_lecturer VARCHAR,
    p_session_id INT,
    p_num INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_avail INT;
BEGIN
    SELECT available_workstations INTO v_avail FROM lab_sessions WHERE session_id = p_session_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Session ID % not found', p_session_id;
        RETURN;
    END IF;
    IF p_num <= 0 THEN
        RAISE EXCEPTION 'Invalid number of workstations: %. Must be > 0', p_num;
    END IF;
    IF v_avail >= p_num THEN
        UPDATE lab_sessions SET available_workstations = available_workstations - p_num WHERE session_id = p_session_id;
        INSERT INTO reservations(lecturer_name, session_id, number_of_workstations, status)
        VALUES(p_lecturer, p_session_id, p_num, 'RESERVED');
        RAISE NOTICE 'SUCCESS: Reserved % workstations for % in session %', p_num, p_lecturer, p_session_id;
    ELSE
        RAISE NOTICE 'FAILED: Session % has only % workstations, requested %', p_session_id, v_avail, p_num;
    END IF;
END;
$$;

-- STEP 5: Two valid, one exceeding
CALL reserve_workstations('Dr. Banda', 1, 10); -- Valid: 30 -> 20
CALL reserve_workstations('Mr. Phiri', 2, 3); -- Valid: 5 -> 2
CALL reserve_workstations('Mrs. Zulu', 2, 10); -- Exceeds: FAIL

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- STEP 6: cancel_reservation - second call must not release again
CREATE OR REPLACE PROCEDURE cancel_reservation(p_res_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_sess INT;
    v_num INT;
    v_stat VARCHAR;
BEGIN
    SELECT session_id, number_of_workstations, status INTO v_sess, v_num, v_stat
    FROM reservations WHERE reservation_id = p_res_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Reservation % not found', p_res_id;
        RETURN;
    END IF;
    IF v_stat = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % already CANCELLED, not releasing again', p_res_id;
    ELSE
        UPDATE lab_sessions SET available_workstations = available_workstations + v_num WHERE session_id = v_sess;
        UPDATE reservations SET status = 'CANCELLED' WHERE reservation_id = p_res_id;
        RAISE NOTICE 'Reservation % CANCELLED, % workstations released', p_res_id, v_num;
    END IF;
END;
$$;

CALL cancel_reservation(1); -- First cancel - releases
CALL cancel_reservation(1); -- Second cancel - must NOT release again

-- STEP 7: Explicit cursor for few workstations
DO $$
DECLARE
    cur CURSOR FOR SELECT session_id, session_name, available_workstations FROM lab_sessions WHERE available_workstations <= 5;
    r RECORD;
BEGIN
    RAISE NOTICE '--- Sessions with few workstations (Cursor) ---';
    OPEN cur;
    LOOP
        FETCH cur INTO r;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Session % "%" low: % workstations left', r.session_id, r.session_name, r.available_workstations;
    END LOOP;
    CLOSE cur;
END $$;

-- STEP 8: Try to reserve zero workstations with EXCEPTION
DO $$
BEGIN
    CALL reserve_workstations('Test Lecturer', 1, 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION HANDLED: %', SQLERRM;
END $$;

-- STEP 9: Final query
SELECT * FROM lab_sessions ORDER BY session_id;
SELECT * FROM reservations ORDER BY reservation_id;