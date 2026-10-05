-- ==========================================================
-- MULUNGUSHI UNIVERSITY - ICT371
-- Scenario 1: University Library Book Loans
-- ==========================================================

-- STEP 1: Create tables and add at least three books
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    book_title VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20) NOT NULL,
    book_id INT REFERENCES books(book_id),
    quantity INT NOT NULL,
    loan_status VARCHAR(20) NOT NULL DEFAULT 'BORROWED'
);

INSERT INTO books (book_title, available_copies) VALUES
('Database Systems', 5),
('Operating Systems', 2),
('Computer Networks', 0);

SELECT * FROM books;

-- STEP 2: Use IF ELSIF ELSE to report whether one book is unavailable, low or sufficiently stocked
DO $$
DECLARE
    v_copies INT;
    v_title VARCHAR(100);
BEGIN
    SELECT available_copies, book_title INTO v_copies, v_title FROM books WHERE book_id = 2;
    
    IF v_copies = 0 THEN
        RAISE NOTICE 'Book "%" is UNAVAILABLE - 0 copies', v_title;
    ELSIF v_copies <= 2 THEN
        RAISE NOTICE 'Book "%" is LOW on copies - only % left', v_title, v_copies;
    ELSE
        RAISE NOTICE 'Book "%" is SUFFICIENTLY STOCKED - % copies', v_title, v_copies;
    END IF;
END $$;

-- STEP 3: WHILE for 3 overdue reminders, FOR for 3 shelf numbers
DO $$
DECLARE
    counter INT := 1;
BEGIN
    RAISE NOTICE '--- Overdue Reminders (WHILE Loop) ---';
    WHILE counter <= 3 LOOP
        RAISE NOTICE 'Overdue Reminder Number: %', counter;
        counter := counter + 1;
    END LOOP;

    RAISE NOTICE '--- Library Shelf Numbers (Numeric FOR Loop) ---';
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Library Shelf Number: %', i;
    END LOOP;
END $$;

-- STEP 4: Create borrow_book procedure
CREATE OR REPLACE PROCEDURE borrow_book(
    p_student_number VARCHAR,
    p_book_id INT,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    SELECT available_copies INTO v_available FROM books WHERE book_id = p_book_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Book ID % not found', p_book_id;
        RETURN;
    END IF;

    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: %. Quantity must be greater than 0', p_quantity;
    END IF;

    IF v_available >= p_quantity THEN
        UPDATE books SET available_copies = available_copies - p_quantity WHERE book_id = p_book_id;
        INSERT INTO book_loans (student_number, book_id, quantity, loan_status)
        VALUES (p_student_number, p_book_id, p_quantity, 'BORROWED');
        RAISE NOTICE 'SUCCESS: Student % borrowed % copy/copies of book %', p_student_number, p_quantity, p_book_id;
    ELSE
        RAISE NOTICE 'FAILED: Not enough copies for book %. Available: %, Requested: %', p_book_id, v_available, p_quantity;
    END IF;
END;
$$;

-- STEP 5: Call for two valid loans and one exceeding, query both tables
CALL borrow_book('20210001', 1, 2); -- Valid: 5 -> 3
CALL borrow_book('20210002', 2, 1); -- Valid: 2 -> 1
CALL borrow_book('20210003', 2, 5); -- Exceeds capacity, will FAIL

SELECT * FROM books;
SELECT * FROM book_loans;

-- STEP 6: Create return_book procedure, call it twice for same loan
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INT;
    v_quantity INT;
    v_status VARCHAR;
BEGIN
    SELECT book_id, quantity, loan_status INTO v_book_id, v_quantity, v_status
    FROM book_loans WHERE loan_id = p_loan_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Loan ID % not found', p_loan_id;
        RETURN;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan ID % is already RETURNED. No copies restored again.', p_loan_id;
    ELSE
        UPDATE books SET available_copies = available_copies + v_quantity WHERE book_id = v_book_id;
        UPDATE book_loans SET loan_status = 'RETURNED' WHERE loan_id = p_loan_id;
        RAISE NOTICE 'Loan ID % marked as RETURNED. % copies restored', p_loan_id, v_quantity;
    END IF;
END;
$$;

CALL return_book(1); -- First call restores
CALL return_book(1); -- Second call must NOT restore again

-- STEP 7: Explicit cursor to display books with few copies remaining
DO $$
DECLARE
    cur_low_stock CURSOR FOR 
        SELECT book_id, book_title, available_copies FROM books WHERE available_copies <= 2;
    rec RECORD;
BEGIN
    RAISE NOTICE '--- Books with few copies remaining (Explicit Cursor) ---';
    OPEN cur_low_stock;
    LOOP
        FETCH cur_low_stock INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Book ID %: "%" has only % copies left', rec.book_id, rec.book_title, rec.available_copies;
    END LOOP;
    CLOSE cur_low_stock;
END $$;

-- STEP 8: Try to borrow zero copies and handle with EXCEPTION block
DO $$
BEGIN
    CALL borrow_book('20210004', 1, 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION HANDLED: %', SQLERRM;
END $$;

-- STEP 9: Query both to show final quantities and loan statuses
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;