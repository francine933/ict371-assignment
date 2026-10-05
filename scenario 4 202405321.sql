-- ==========================================================
-- Scenario 4: Student Project Supervision
-- ==========================================================

-- STEP 1: Create tables with at least three lecturers
DROP TABLE IF EXISTS student_projects CASCADE;
DROP TABLE IF EXISTS lecturers CASCADE;

CREATE TABLE lecturers (
    lecturer_id SERIAL PRIMARY KEY,
    lecturer_name VARCHAR(100) NOT NULL,
    available_slots INT NOT NULL CHECK (available_slots >= 0)
);

CREATE TABLE student_projects (
    project_id SERIAL PRIMARY KEY,
    student_name VARCHAR(100) NOT NULL,
    lecturer_id INT REFERENCES lecturers(lecturer_id),
    project_title VARCHAR(150) NOT NULL,
    status VARCHAR(20) DEFAULT 'ASSIGNED'
);

INSERT INTO lecturers (lecturer_name, available_slots) VALUES
('Dr. Mwanza', 3),
('Dr. Chanda', 1),
('Dr. Lungu', 0);

SELECT * FROM lecturers;

-- STEP 2: IF ELSIF ELSE for UNAVAILABLE / ALMOST FULL / AVAILABLE
DO $$
DECLARE
    v_slots INT;
    v_name VARCHAR;
BEGIN
    SELECT available_slots, lecturer_name INTO v_slots, v_name FROM lecturers WHERE lecturer_id = 3;
    IF v_slots = 0 THEN
        RAISE NOTICE 'Lecturer "%" is UNAVAILABLE - no slots', v_name;
    ELSIF v_slots <= 1 THEN
        RAISE NOTICE 'Lecturer "%" is ALMOST FULL - only % slot left', v_name, v_slots;
    ELSE
        RAISE NOTICE 'Lecturer "%" is AVAILABLE - % slots left', v_name, v_slots;
    END IF;
END $$;

-- STEP 3: WHILE for 3 deadline reminders, FOR for 3 review meetings
DO $$
DECLARE
    c INT := 1;
BEGIN
    RAISE NOTICE '--- Project Deadline Reminders (WHILE) ---';
    WHILE c <= 3 LOOP
        RAISE NOTICE 'Project Deadline Reminder %', c;
        c := c + 1;
    END LOOP;
    RAISE NOTICE '--- Review Meetings (FOR) ---';
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Review Meeting Number: %', i;
    END LOOP;
END $$;

-- STEP 4: assign_project procedure
CREATE OR REPLACE PROCEDURE assign_project(
    p_student VARCHAR,
    p_lecturer_id INT,
    p_title VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    v_slots INT;
BEGIN
    SELECT available_slots INTO v_slots FROM lecturers WHERE lecturer_id = p_lecturer_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Lecturer ID % not found', p_lecturer_id;
        RETURN;
    END IF;
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        RAISE EXCEPTION 'Invalid project title: cannot be empty';
    END IF;
    IF v_slots > 0 THEN
        UPDATE lecturers SET available_slots = available_slots - 1 WHERE lecturer_id = p_lecturer_id;
        INSERT INTO student_projects(student_name, lecturer_id, project_title, status)
        VALUES(p_student, p_lecturer_id, p_title, 'ASSIGNED');
        RAISE NOTICE 'SUCCESS: Project "%" assigned to % under lecturer %', p_title, p_student, p_lecturer_id;
    ELSE
        RAISE NOTICE 'FAILED: Lecturer % has no available slots', p_lecturer_id;
    END IF;
END;
$$;

-- STEP 5: Two valid assignments, one exceeding
CALL assign_project('Mary Phiri', 1, 'Library Management System'); -- Valid: 3 -> 2
CALL assign_project('Joseph Banda', 2, 'Lab Reservation System'); -- Valid: 1 -> 0
CALL assign_project('Alice Zulu', 3, 'Equipment Borrowing System'); -- FAIL - 0 slots

SELECT * FROM lecturers;
SELECT * FROM student_projects;

-- STEP 6: cancel_project - second call must NOT release slot again
CREATE OR REPLACE PROCEDURE cancel_project(p_project_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_lect INT;
    v_stat VARCHAR;
BEGIN
    SELECT lecturer_id, status INTO v_lect, v_stat FROM student_projects WHERE project_id = p_project_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Project ID % not found', p_project_id;
        RETURN;
    END IF;
    IF v_stat = 'CANCELLED' THEN
        RAISE NOTICE 'Project % already CANCELLED, slot not released again', p_project_id;
    ELSE
        UPDATE lecturers SET available_slots = available_slots + 1 WHERE lecturer_id = v_lect;
        UPDATE student_projects SET status = 'CANCELLED' WHERE project_id = p_project_id;
        RAISE NOTICE 'Project % CANCELLED, slot restored to lecturer %', p_project_id, v_lect;
    END IF;
END;
$$;

CALL cancel_project(1); -- Cancels
CALL cancel_project(1); -- Must NOT release again

-- STEP 7: Explicit cursor for lecturers with few slots
DO $$
DECLARE
    cur CURSOR FOR SELECT lecturer_id, lecturer_name, available_slots FROM lecturers WHERE available_slots <= 1;
    r RECORD;
BEGIN
    RAISE NOTICE '--- Lecturers with few slots (Cursor) ---';
    OPEN cur;
    LOOP
        FETCH cur INTO r;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Lecturer % "%" has % slots left', r.lecturer_id, r.lecturer_name, r.available_slots;
    END LOOP;
    CLOSE cur;
END $$;

-- STEP 8: Try empty project title with EXCEPTION
DO $$
BEGIN
    CALL assign_project('Test Student', 1, '');
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION HANDLED: %', SQLERRM;
END $$;

-- STEP 9: Final
SELECT * FROM lecturers ORDER BY lecturer_id;
SELECT * FROM student_projects ORDER BY project_id;