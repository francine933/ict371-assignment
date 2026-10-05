-- ==========================================================
-- Scenario 3: ICT Equipment Borrowing
-- ==========================================================

-- STEP 1: Create tables with at least three equipment
DROP TABLE IF EXISTS equipment_loans CASCADE;
DROP TABLE IF EXISTS equipment CASCADE;

CREATE TABLE equipment (
    equipment_id SERIAL PRIMARY KEY,
    equipment_name VARCHAR(100) NOT NULL,
    available_quantity INT NOT NULL CHECK (available_quantity >= 0)
);

CREATE TABLE equipment_loans (
    loan_id SERIAL PRIMARY KEY,
    borrower_name VARCHAR(100) NOT NULL,
    equipment_id INT REFERENCES equipment(equipment_id),
    quantity INT NOT NULL,
    status VARCHAR(20) DEFAULT 'BORROWED'
);

INSERT INTO equipment (equipment_name, available_quantity) VALUES
('Projector', 10),
('Laptop', 2),
('HDMI Cable', 0);

SELECT * FROM equipment;

-- STEP 2: IF ELSIF ELSE for OUT OF STOCK / LOW / IN STOCK
DO $$
DECLARE
    v_qty INT;
    v_name VARCHAR;
BEGIN
    SELECT available_quantity, equipment_name INTO v_qty, v_name FROM equipment WHERE equipment_id = 3;
    IF v_qty = 0 THEN
        RAISE NOTICE 'Equipment "%" is OUT OF STOCK', v_name;
    ELSIF v_qty <= 2 THEN
        RAISE NOTICE 'Equipment "%" is LOW - only % left', v_name, v_qty;
    ELSE
        RAISE NOTICE 'Equipment "%" is IN STOCK - % available', v_name, v_qty;
    END IF;
END $$;

-- STEP 3: WHILE for 3 overdue, FOR for 3 inventory checks
DO $$
DECLARE
    c INT := 1;
BEGIN
    RAISE NOTICE '--- Overdue Equipment Reminders (WHILE) ---';
    WHILE c <= 3 LOOP
        RAISE NOTICE 'Overdue Equipment Reminder %', c;
        c := c + 1;
    END LOOP;
    RAISE NOTICE '--- Inventory Checks (FOR) ---';
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Inventory Check Number: %', i;
    END LOOP;
END $$;

-- STEP 4: borrow_equipment procedure
CREATE OR REPLACE PROCEDURE borrow_equipment(
    p_borrower VARCHAR,
    p_equip_id INT,
    p_qty INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_avail INT;
BEGIN
    SELECT available_quantity INTO v_avail FROM equipment WHERE equipment_id = p_equip_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Equipment ID % not found', p_equip_id;
        RETURN;
    END IF;
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity % for borrowing. Must be > 0', p_qty;
    END IF;
    IF v_avail >= p_qty THEN
        UPDATE equipment SET available_quantity = available_quantity - p_qty WHERE equipment_id = p_equip_id;
        INSERT INTO equipment_loans(borrower_name, equipment_id, quantity, status)
        VALUES(p_borrower, p_equip_id, p_qty, 'BORROWED');
        RAISE NOTICE 'SUCCESS: % borrowed % of equipment %', p_borrower, p_qty, p_equip_id;
    ELSE
        RAISE NOTICE 'FAILED: Equipment % only has % left, requested %', p_equip_id, v_avail, p_qty;
    END IF;
END;
$$;

-- STEP 5: Two valid, one exceeding
CALL borrow_equipment('John Mulenga', 1, 2); -- Valid: 10 -> 8
CALL borrow_equipment('Grace Tembo', 2, 1); -- Valid: 2 -> 1
CALL borrow_equipment('Peter Daka', 2, 5); -- FAIL exceeds

SELECT * FROM equipment;
SELECT * FROM equipment_loans;

-- STEP 6: return_equipment - second call must NOT return again
CREATE OR REPLACE PROCEDURE return_equipment(p_loan_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_equip INT;
    v_qty INT;
    v_stat VARCHAR;
BEGIN
    SELECT equipment_id, quantity, status INTO v_equip, v_qty, v_stat
    FROM equipment_loans WHERE loan_id = p_loan_id;
    IF NOT FOUND THEN
        RAISE NOTICE 'Loan % not found', p_loan_id;
        RETURN;
    END IF;
    IF v_stat = 'RETURNED' THEN
        RAISE NOTICE 'Loan % already RETURNED, no quantity added again', p_loan_id;
    ELSE
        UPDATE equipment SET available_quantity = available_quantity + v_qty WHERE equipment_id = v_equip;
        UPDATE equipment_loans SET status = 'RETURNED' WHERE loan_id = p_loan_id;
        RAISE NOTICE 'Loan % RETURNED, % restored', p_loan_id, v_qty;
    END IF;
END;
$$;

CALL return_equipment(1); -- Returns
CALL return_equipment(1); -- Must NOT return again

-- STEP 7: Explicit cursor for low equipment
DO $$
DECLARE
    cur CURSOR FOR SELECT equipment_id, equipment_name, available_quantity FROM equipment WHERE available_quantity <= 2;
    r RECORD;
BEGIN
    RAISE NOTICE '--- Low Equipment (Explicit Cursor) ---';
    OPEN cur;
    LOOP
        FETCH cur INTO r;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Equipment % "%" is low: % left', r.equipment_id, r.equipment_name, r.available_quantity;
    END LOOP;
    CLOSE cur;
END $$;

-- STEP 8: Try zero quantity with EXCEPTION
DO $$
BEGIN
    CALL borrow_equipment('Test User', 1, 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION HANDLED: %', SQLERRM;
END $$;

-- STEP 9: Final
SELECT * FROM equipment ORDER BY equipment_id;
SELECT * FROM equipment_loans ORDER BY loan_id;